"""Tests for TTSRouter.stream_with_alignment (Writing-Nook streaming path).

Verifies the pure streaming source used by the /audio/stream endpoint:

  * When ElevenLabs is allowed (quota OK) and is the primary provider, the
    router passes the provider's audio chunks through unchanged and tags the
    final alignment event with provider="elevenlabs".
  * When ElevenLabs is NOT allowed (quota exhausted) or is not primary, the
    router uses the alignment-aware Edge/Azure fallback, re-chunks the buffered
    audio into fixed windows, and NEVER calls the ElevenLabs stream — so it can
    never silently bill EL on the fallback path.

The router does no DB work in this method by design (the endpoint owns the
session), so these tests need no database.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from psitta.providers.tts_router import TTSRouter

ADAM_ID = "pNInz6obpgDQGcFmaJgB"  # provider=elevenlabs
ARIA_ID = "en-US-AriaNeural"      # provider=azure


def _make_router(elevenlabs=None, edge=None, azure=None, primary="elevenlabs"):
    """Build a TTSRouter without invoking __init__ (mirrors the dispatch
    test helper) so we can inject mocks into the slots the router reads."""
    router = TTSRouter.__new__(TTSRouter)
    router._elevenlabs = elevenlabs
    router._azure = azure
    router._edge = edge
    router._stub = MagicMock()
    router._provider_selected = primary
    router._fallback_selected = "edge"
    router._settings = None
    return router


def _alignment_block():
    return {
        "characters": ["h", "i"],
        "character_start_times_seconds": [0.0, 0.1],
        "character_end_times_seconds": [0.1, 0.2],
    }


@pytest.mark.asyncio
async def test_stream_uses_elevenlabs_when_allowed_and_primary():
    """allow_elevenlabs=True + primary=elevenlabs → audio passes through
    unchanged and the final alignment event is tagged provider=elevenlabs."""

    block = {"alignment": _alignment_block(), "normalized_alignment": _alignment_block()}

    async def fake_el_stream(text, voice_id, output_format="mp3_44100_128"):
        yield {"type": "audio", "data": b"AAA"}
        yield {"type": "audio", "data": b"BBB"}
        yield {"type": "alignment", "data": block}

    elevenlabs = MagicMock()
    elevenlabs.stream_with_timestamps = fake_el_stream

    router = _make_router(elevenlabs=elevenlabs, primary="elevenlabs")

    events = [
        ev
        async for ev in router.stream_with_alignment(
            "hi", ADAM_ID, allow_elevenlabs=True
        )
    ]

    audio = [e for e in events if e["type"] == "audio"]
    alignment = [e for e in events if e["type"] == "alignment"]

    assert b"".join(e["data"] for e in audio) == b"AAABBB"
    assert len(alignment) == 1
    assert alignment[0]["provider"] == "elevenlabs"
    assert alignment[0]["data"] is block


@pytest.mark.asyncio
async def test_stream_falls_back_and_rechunks_when_el_not_allowed():
    """allow_elevenlabs=False → use the alignment-aware fallback, re-chunk the
    buffered audio into 16 KiB windows, tag the fallback provider, and never
    touch the ElevenLabs stream (no silent EL billing)."""

    elevenlabs = MagicMock()  # its stream must NOT be called
    router = _make_router(elevenlabs=elevenlabs, primary="elevenlabs")

    payload = b"X" * 40000  # 40000 / 16384 -> 3 windows (16384, 16384, 7232)
    fallback_alignment = {"normalized_alignment": _alignment_block()}
    router._fallback_synthesize_with_alignment = AsyncMock(
        return_value=(payload, fallback_alignment, "edge")
    )

    events = [
        ev
        async for ev in router.stream_with_alignment(
            "hi", ARIA_ID, allow_elevenlabs=False
        )
    ]

    audio = [e for e in events if e["type"] == "audio"]
    alignment = [e for e in events if e["type"] == "alignment"]

    # Audio reconstructs exactly and is split into 3 fixed windows.
    assert b"".join(e["data"] for e in audio) == payload
    assert len(audio) == 3
    assert len(alignment) == 1
    assert alignment[0]["provider"] == "edge"
    assert alignment[0]["data"] is fallback_alignment

    router._fallback_synthesize_with_alignment.assert_awaited_once()
    elevenlabs.stream_with_timestamps.assert_not_called()


@pytest.mark.asyncio
async def test_stream_falls_back_when_allowed_but_not_el_primary():
    """allow_elevenlabs=True but the primary provider is not ElevenLabs (e.g. an
    Azure-catalog voice) → still the fallback path, EL stream untouched."""

    elevenlabs = MagicMock()
    router = _make_router(elevenlabs=elevenlabs, primary="azure")
    router._fallback_synthesize_with_alignment = AsyncMock(
        return_value=(b"AUDIO", {"k": 1}, "edge")
    )

    events = [
        ev
        async for ev in router.stream_with_alignment(
            "hi", ARIA_ID, allow_elevenlabs=True
        )
    ]

    audio = b"".join(e["data"] for e in events if e["type"] == "audio")
    assert audio == b"AUDIO"
    elevenlabs.stream_with_timestamps.assert_not_called()
