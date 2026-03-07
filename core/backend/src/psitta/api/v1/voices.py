"""Psitta - Voice Catalog Routes."""
from __future__ import annotations
from typing import Annotated
import structlog
from fastapi import APIRouter, Query
from psitta.providers.voice_catalog_static import VOICE_CATALOG

logger = structlog.get_logger(__name__)
router = APIRouter()

@router.get("/", summary="List available voices")
async def list_voices(
    language: Annotated[str | None, Query(pattern=r"^[a-z]{2}(-[A-Z]{2})?$")] = None,
    tier: Annotated[str | None, Query(pattern=r"^(free|premium|standard)$")] = None,
) -> dict:
    voices = VOICE_CATALOG
    if language:
        voices = [v for v in voices if v["language"] == language]
    if tier:
        voices = [v for v in voices if v["tier"] == tier]
    return {"voices": voices, "total": len(voices)}

@router.get("/{voice_id}", summary="Get voice details")
async def get_voice(voice_id: str) -> dict:
    for v in VOICE_CATALOG:
        if v["id"] == voice_id:
            return v
    return {"detail": "Voice not found"}

@router.get("/{voice_id}/preview", summary="Get preview audio")
async def preview_voice(voice_id: str) -> dict:
    return {"voice_id": voice_id, "preview_url": None, "expires_in_seconds": 900}

@router.get("/profiles/me", summary="Get user voice profile")
async def get_voice_profile() -> dict:
    return {"preferred_voice_id": "21m00Tcm4TlvDq8ikWAM", "default_speed": 1.0}

@router.put("/profiles/me", summary="Update user voice profile")
async def update_voice_profile(
    preferred_voice_id: str | None = None,
    default_speed: Annotated[float | None, Query(ge=0.5, le=3.0)] = None,
) -> dict:
    return {"preferred_voice_id": preferred_voice_id, "default_speed": default_speed, "status": "updated"}
