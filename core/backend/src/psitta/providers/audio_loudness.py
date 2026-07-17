"""Loudness normalization for synthesized TTS audio.

ElevenLabs Voice-Library voices are mastered at inconsistent — and often low —
loudness, so a Brazilian-Portuguese or French premium voice can play markedly
quieter than the built-in en-US voices or the Azure neural voices. ElevenLabs
exposes no volume/loudness parameter, so the fix is to normalize the rendered
audio ourselves to a single EBU R128 target. Applied at the cache-write
chokepoint, every voice — any provider, any language — ends up at the same
perceived volume.

Normalization is gain/dynamics only (no time-stretch), so character-level SWH
alignment timings stay valid (a re-encode adds only a few ms of encoder delay,
far below word-highlight granularity).

The call is FAIL-SAFE: any error (ffmpeg missing, timeout, non-zero exit, empty
output) returns the original bytes unchanged, so normalization can never break
playback.
"""
from __future__ import annotations

import asyncio

import structlog

logger = structlog.get_logger(__name__)

# EBU R128 target. -16 LUFS is a standard spoken-word/streaming loudness and
# matches the natural level of the Azure neural voices already in the catalog,
# so bringing the quiet ElevenLabs voices up to it makes the set consistent.
_TARGET_I = -16.0
_TARGET_TP = -1.5
_TARGET_LRA = 11.0
_TIMEOUT_S = 30.0

# Force a single output sample rate for EVERY cached clip. ElevenLabs renders at
# 44.1 kHz (mp3_44100_128) while Edge renders at 24 kHz; when a per-sentence
# playlist concatenates clips of different sample rates, just_audio must
# reconfigure the decoder mid-stream and the transitioning clip stalls or is
# skipped (the "reads 4 sentences then jumps" bug). Resampling here — the single
# cache-write chokepoint every provider passes through — guarantees homogeneous
# 44.1 kHz clips so the playlist concatenates seamlessly regardless of which
# provider served each sentence. Resample is gain/rate only (no time-stretch),
# so character-level SWH alignment timings stay valid.
_TARGET_SR = 44100


async def normalize_mp3(data: bytes, *, bitrate: str = "128k") -> bytes:
    """Return ``data`` loudness-normalized to the R128 target.

    Input and output are MP3 bytes. Returns ``data`` unchanged on any failure.
    """
    if not data:
        return data

    cmd = [
        "ffmpeg", "-hide_banner", "-loglevel", "error",
        "-i", "pipe:0",
        "-af", f"loudnorm=I={_TARGET_I}:TP={_TARGET_TP}:LRA={_TARGET_LRA}",
        "-ar", str(_TARGET_SR),
        "-c:a", "libmp3lame", "-b:a", bitrate,
        "-f", "mp3", "pipe:1",
    ]

    try:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
    except FileNotFoundError:
        logger.warning("audio_loudness.ffmpeg_missing")
        return data
    except Exception as exc:  # defensive: never break the caller
        logger.warning("audio_loudness.spawn_failed", error=str(exc))
        return data

    try:
        out, err = await asyncio.wait_for(
            proc.communicate(input=data), timeout=_TIMEOUT_S
        )
    except (asyncio.TimeoutError, Exception) as exc:
        try:
            proc.kill()
        except ProcessLookupError:
            pass
        logger.warning("audio_loudness.run_failed", error=str(exc))
        return data

    if proc.returncode != 0 or not out:
        logger.warning(
            "audio_loudness.nonzero",
            returncode=proc.returncode,
            stderr=(err[:200].decode("utf-8", "replace") if err else ""),
        )
        return data

    logger.info("audio_loudness.ok", in_size=len(data), out_size=len(out))
    return out
