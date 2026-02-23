"""Psitta - TTS Diagnostics Routes."""

from __future__ import annotations

from fastapi import APIRouter

from psitta.providers.tts_router import TTSRouter

router = APIRouter()

# Simple module-level instance. Good enough for now.
_tts_router = TTSRouter()


@router.get("/health", summary="TTS health and provider selection")
async def tts_health() -> dict:
    health = await _tts_router.health()
    return {
        "provider_selected": health.get("provider_selected"),
        "fallback": health.get("fallback"),
        "providers_status": _tts_router.providers_status,
        "configured": health.get("configured"),
        "health": health.get("health"),
    }
