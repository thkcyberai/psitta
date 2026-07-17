"""Regression tests for TTS clip sample-rate normalization.

Production bug (V1.1.2.0): the Player read ~4 sentences, then the highlight
jumped ahead and the voice stalled. Root cause was in the audio pipeline, not
the client: ElevenLabs renders sentence clips at 44.1 kHz while the Edge
fallback renders at 24 kHz, and ``normalize_mp3`` re-encoded bitrate but set no
``-ar``, so cached sentence clips were a MIX of sample rates. A just_audio
``ConcatenatingAudioSource`` must reconfigure the decoder at a sample-rate change
between consecutive clips, so the transitioning clip stalled/was skipped.

The fix forces every clip to 44.1 kHz at the single cache-write chokepoint
(``normalize_mp3``). These tests lock that invariant in so the ``-ar`` flag can
never be dropped again, while preserving the fail-safe contract (any ffmpeg
failure returns the input bytes unchanged so playback never breaks).
"""

from __future__ import annotations

import asyncio

import pytest

from psitta.providers import audio_loudness


class _FakeProc:
    def __init__(self, out: bytes = b"OUT", err: bytes = b"", returncode: int = 0):
        self._out = out
        self._err = err
        self.returncode = returncode

    async def communicate(self, input: bytes | None = None):  # noqa: A002
        return self._out, self._err

    def kill(self) -> None:  # pragma: no cover - only used on the failure path
        pass


@pytest.mark.asyncio
async def test_normalize_mp3_forces_44100_sample_rate(monkeypatch):
    """Every normalized clip must be resampled to 44.1 kHz.

    Guards the exact regression: without ``-ar 44100`` in the ffmpeg command,
    Edge (24 kHz) and ElevenLabs (44.1 kHz) clips concatenate at mismatched
    rates and the per-sentence playlist stalls mid-document.
    """
    captured: dict[str, list[str]] = {}

    async def fake_exec(*cmd, **kwargs):
        captured["cmd"] = [str(c) for c in cmd]
        return _FakeProc(out=b"NORMALIZED")

    monkeypatch.setattr(asyncio, "create_subprocess_exec", fake_exec)

    out = await audio_loudness.normalize_mp3(b"RAWMP3")

    assert out == b"NORMALIZED"
    cmd = captured["cmd"]
    assert "-ar" in cmd, cmd
    assert cmd[cmd.index("-ar") + 1] == "44100", cmd


@pytest.mark.asyncio
async def test_normalize_mp3_failsafe_returns_original_on_error(monkeypatch):
    """Fail-safe contract survives the resample change: an ffmpeg failure
    returns the input bytes unchanged rather than breaking playback."""

    async def fake_exec(*cmd, **kwargs):
        return _FakeProc(out=b"", returncode=1)

    monkeypatch.setattr(asyncio, "create_subprocess_exec", fake_exec)

    original = b"RAWMP3"
    result = await audio_loudness.normalize_mp3(original)
    assert result is original


@pytest.mark.asyncio
async def test_normalize_mp3_empty_input_is_noop():
    """Empty input returns immediately without spawning ffmpeg."""
    assert await audio_loudness.normalize_mp3(b"") == b""
