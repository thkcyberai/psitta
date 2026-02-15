"""Psitta - Voice Catalog Routes."""

from __future__ import annotations

from typing import Annotated

import structlog
from fastapi import APIRouter, Query

logger = structlog.get_logger(__name__)

router = APIRouter()

VOICE_CATALOG = [
    {"id": "en-US-AriaNeural", "display_name": "Aria", "language": "en-US", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-US-GuyNeural", "display_name": "Guy", "language": "en-US", "gender": "male", "tier": "free", "sample_url": None},
    {"id": "en-US-JennyNeural", "display_name": "Jenny", "language": "en-US", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-US-DavisNeural", "display_name": "Davis", "language": "en-US", "gender": "male", "tier": "free", "sample_url": None},
    {"id": "en-US-AmberNeural", "display_name": "Amber", "language": "en-US", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-US-AnaNeural", "display_name": "Ana", "language": "en-US", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-US-BrandonNeural", "display_name": "Brandon", "language": "en-US", "gender": "male", "tier": "free", "sample_url": None},
    {"id": "en-US-ChristopherNeural", "display_name": "Christopher", "language": "en-US", "gender": "male", "tier": "free", "sample_url": None},
    {"id": "en-GB-SoniaNeural", "display_name": "Sonia", "language": "en-GB", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-GB-RyanNeural", "display_name": "Ryan", "language": "en-GB", "gender": "male", "tier": "free", "sample_url": None},
    {"id": "es-ES-ElviraNeural", "display_name": "Elvira", "language": "es-ES", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "es-MX-DaliaNeural", "display_name": "Dalia", "language": "es-MX", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "fr-FR-DeniseNeural", "display_name": "Denise", "language": "fr-FR", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "de-DE-KatjaNeural", "display_name": "Katja", "language": "de-DE", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "ja-JP-NanamiNeural", "display_name": "Nanami", "language": "ja-JP", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "zh-CN-XiaoxiaoNeural", "display_name": "Xiaoxiao", "language": "zh-CN", "gender": "female", "tier": "free", "sample_url": None},
    {"id": "en-US-JennyMultilingualNeural", "display_name": "Jenny (Multilingual)", "language": "en-US", "gender": "female", "tier": "premium", "sample_url": None},
    {"id": "en-US-RogerNeural", "display_name": "Roger", "language": "en-US", "gender": "male", "tier": "premium", "sample_url": None},
    {"id": "en-US-SteffanNeural", "display_name": "Steffan", "language": "en-US", "gender": "male", "tier": "premium", "sample_url": None},
    {"id": "en-US-AriaMultilingualNeural", "display_name": "Aria (Multilingual)", "language": "en-US", "gender": "female", "tier": "premium", "sample_url": None},
]


@router.get("/", summary="List available voices")
async def list_voices(
    language: Annotated[str | None, Query(pattern=r"^[a-z]{2}(-[A-Z]{2})?$")] = None,
    tier: Annotated[str | None, Query(pattern=r"^(free|premium)$")] = None,
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
    return {"preferred_voice_id": "en-US-AriaNeural", "default_speed": 1.0}


@router.put("/profiles/me", summary="Update user voice profile")
async def update_voice_profile(
    preferred_voice_id: str | None = None,
    default_speed: Annotated[float | None, Query(ge=0.5, le=3.0)] = None,
) -> dict:
    return {"preferred_voice_id": preferred_voice_id, "default_speed": default_speed, "status": "updated"}
