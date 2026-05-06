"""Tests for TTSRouter catalog-driven dispatch (Item 11.5).

Verifies that voices with provider=azure in voice_catalog_static
bypass the ElevenLabs primary path and route directly to Edge (with
Azure as next-tier fallback). Voices with provider=elevenlabs use the
legacy path unchanged. Unknown voices fall through to the legacy path
for forward-compat.

Bug being fixed: pre-Item-11.5, all 6 Azure-named voices played as
en-US-JennyNeural because the EDGE_VOICES dict (keyed by EL hashes)
returned its hardcoded default for any unrecognized id, including the
6 native Microsoft ids (en-US-AriaNeural, en-US-GuyNeural, etc.).
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock

import pytest

from psitta.providers.tts_edge import EdgeTTSProvider
from psitta.providers.tts_router import TTSRouter, _voice_provider

# Catalog ids — verified verbatim against voice_catalog_static.py.
ARIA_ID = "en-US-AriaNeural"      # provider=azure
ADAM_ID = "pNInz6obpgDQGcFmaJgB"  # provider=elevenlabs
UNKNOWN_ID = "this-id-does-not-exist"


def _make_router(elevenlabs=None, edge=None, azure=None, primary="elevenlabs"):
    """Build a TTSRouter without invoking __init__.

    The real constructor calls get_settings() and tries to instantiate
    each provider from API keys — both undesirable in unit tests.
    Bypassing __init__ via __new__ lets us inject mocks straight into
    the slots the router reads.
    """
    router = TTSRouter.__new__(TTSRouter)
    router._elevenlabs = elevenlabs
    router._azure = azure
    router._edge = edge
    router._stub = MagicMock()
    router._provider_selected = primary
    router._fallback_selected = "edge"
    router._settings = None
    return router


@pytest.fixture(autouse=True)
def _clear_voice_provider_cache():
    """_voice_provider uses lru_cache(maxsize=None). Clear between
    tests so a cached lookup from a prior test can't mask a regression
    in the catalog-read path."""
    _voice_provider.cache_clear()
    yield
    _voice_provider.cache_clear()


# ── _voice_provider helper ─────────────────────────────────────────


def test_voice_provider_returns_correct_label():
    assert _voice_provider(ARIA_ID) == "azure"
    assert _voice_provider(ADAM_ID) == "elevenlabs"
    assert _voice_provider(UNKNOWN_ID) == "unknown"


# ── synthesize() dispatch ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_synthesize_dispatches_azure_voice_to_edge_with_native_id():
    """Aria's catalog id is en-US-AriaNeural; the dispatch must call
    Edge.synthesize(voice_id='en-US-AriaNeural') directly — bypassing
    EL primary, bypassing the EDGE_VOICES dict translation."""
    edge = AsyncMock()
    edge.synthesize = AsyncMock(return_value=b"AUDIO_ARIA")
    elevenlabs = AsyncMock()
    elevenlabs.synthesize = AsyncMock()

    router = _make_router(elevenlabs=elevenlabs, edge=edge)
    audio, provider_name = await router.synthesize(
        text="hello", voice_id=ARIA_ID,
    )

    assert audio == b"AUDIO_ARIA"
    assert provider_name == "edge"
    edge.synthesize.assert_awaited_once()
    # Crucial: the raw catalog id is passed through to Edge unchanged.
    assert edge.synthesize.await_args.kwargs["voice_id"] == ARIA_ID
    # Crucial: ElevenLabs is NEVER called for an azure voice.
    elevenlabs.synthesize.assert_not_called()


@pytest.mark.asyncio
async def test_synthesize_with_alignment_dispatches_azure_voice_to_edge():
    """Same dispatch behavior for the alignment-aware entry point.
    _edge_with_alignment is mocked at the router level so the test
    stays focused on dispatch, not on the WordBoundary expansion."""
    edge = AsyncMock()
    elevenlabs = AsyncMock()

    router = _make_router(elevenlabs=elevenlabs, edge=edge)
    fake_alignment = {"alignment": {"chars": []}}
    router._edge_with_alignment = AsyncMock(
        return_value=(b"AUDIO_ARIA", fake_alignment)
    )

    audio, alignment, provider_name = await router.synthesize_with_alignment(
        text="hello", voice_id=ARIA_ID,
    )

    assert audio == b"AUDIO_ARIA"
    assert alignment is fake_alignment
    assert provider_name == "edge"
    router._edge_with_alignment.assert_awaited_once_with("hello", ARIA_ID)
    # ElevenLabs /with-timestamps is NOT called for an azure voice.
    elevenlabs.synthesize_with_timestamps.assert_not_called()


@pytest.mark.asyncio
async def test_synthesize_falls_back_to_azure_when_edge_fails_for_azure_voice():
    """If Edge raises (e.g., edge-tts library hiccup), Azure is the
    next-tier failover — and it MUST receive the raw catalog id, not
    the elevenlabs_to_azure() default of Jenny."""
    edge = AsyncMock()
    edge.synthesize = AsyncMock(side_effect=RuntimeError("edge down"))
    azure = AsyncMock()
    azure.synthesize = AsyncMock(return_value=b"AUDIO_FROM_AZURE")

    router = _make_router(edge=edge, azure=azure)
    audio, provider_name = await router.synthesize(
        text="hello", voice_id=ARIA_ID,
    )

    assert audio == b"AUDIO_FROM_AZURE"
    assert provider_name == "azure"
    edge.synthesize.assert_awaited_once()
    azure.synthesize.assert_awaited_once()
    # Raw catalog id passed to Azure — NOT translated through
    # elevenlabs_to_azure (which would have returned Jenny).
    assert azure.synthesize.await_args.kwargs["voice_id"] == ARIA_ID


@pytest.mark.asyncio
async def test_synthesize_raises_when_edge_and_azure_both_unavailable_for_azure_voice():
    """Catastrophic case: no provider can serve the azure voice. Must
    raise RuntimeError, NOT silently fall back to Jenny default."""
    router = _make_router(edge=None, azure=None)

    with pytest.raises(RuntimeError, match="azure voice"):
        await router.synthesize(text="hello", voice_id=ARIA_ID)


# ── Legacy path preservation ───────────────────────────────────────


@pytest.mark.asyncio
async def test_synthesize_unchanged_for_elevenlabs_voice():
    """provider=elevenlabs voices must hit the existing primary path,
    not the new dispatch shim."""
    elevenlabs = AsyncMock()
    elevenlabs.synthesize = AsyncMock(return_value=b"AUDIO_ADAM")
    edge = AsyncMock()

    router = _make_router(
        elevenlabs=elevenlabs, edge=edge, primary="elevenlabs"
    )
    audio, provider_name = await router.synthesize(
        text="hello", voice_id=ADAM_ID,
    )

    assert audio == b"AUDIO_ADAM"
    assert provider_name == "elevenlabs"
    elevenlabs.synthesize.assert_awaited_once()
    edge.synthesize.assert_not_called()


@pytest.mark.asyncio
async def test_synthesize_unknown_voice_uses_legacy_el_primary():
    """Forward-compat: a voice id not in the catalog falls through to
    the existing EL-primary path. Behavior preserved for any voice
    added after a deploy when catalog/code are briefly out of sync."""
    elevenlabs = AsyncMock()
    elevenlabs.synthesize = AsyncMock(return_value=b"AUDIO_FALLTHROUGH")
    edge = AsyncMock()

    router = _make_router(
        elevenlabs=elevenlabs, edge=edge, primary="elevenlabs"
    )
    audio, provider_name = await router.synthesize(
        text="hello", voice_id=UNKNOWN_ID,
    )

    assert audio == b"AUDIO_FALLTHROUGH"
    assert provider_name == "elevenlabs"
    elevenlabs.synthesize.assert_awaited_once()


# ── Edge provider _get_voice ───────────────────────────────────────


def test_edge_get_voice_passes_through_native_microsoft_id():
    """tts_edge.py:_get_voice must recognize native Microsoft ids as
    pass-through (Diff 2). Without this, the dispatch in tts_router
    would still resolve every native id to JennyNeural via the
    EDGE_VOICES.get(default=Jenny) safety net."""
    edge = EdgeTTSProvider()
    # Native Microsoft ids (catalog provider=azure) — pass through.
    assert edge._get_voice("en-US-AriaNeural") == "en-US-AriaNeural"
    assert edge._get_voice("en-US-GuyNeural") == "en-US-GuyNeural"
    assert edge._get_voice("en-GB-SoniaNeural") == "en-GB-SoniaNeural"
    # EL hash — translates via EDGE_VOICES dict (legacy behavior).
    assert edge._get_voice("pNInz6obpgDQGcFmaJgB") == "en-US-ChristopherNeural"
    # Garbage — falls through to default safety net.
    assert edge._get_voice("foo-bar-baz") == "en-US-JennyNeural"
