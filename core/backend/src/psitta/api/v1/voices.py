"""Psitta - Voice Catalog Routes."""

from __future__ import annotations

from typing import Annotated

import structlog
from fastapi import APIRouter, Query

logger = structlog.get_logger(__name__)

router = APIRouter()

VOICE_CATALOG = [
    {"id": "21m00Tcm4TlvDq8ikWAM", "display_name": "Rachel", "language": "en-US", "gender": "female", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "29vD33N1CtxCmqQRPOHJ", "display_name": "Drew", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "EXAVITQu4vr4xnSDxMaL", "display_name": "Bella", "language": "en-US", "gender": "female", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "ErXwobaYiN019PkySvjV", "display_name": "Antoni", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "TxGEqnHWrfWFTfGW9XjX", "display_name": "Josh", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "VR6AewLTigWG4xSOukaG", "display_name": "Arnold", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "pNInz6obpgDQGcFmaJgB", "display_name": "Adam", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "yoZ06aMxZJJ28mfd3POQ", "display_name": "Sam", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "jBpfuIE2acCO8z3wKNLl", "display_name": "Gigi", "language": "en-US", "gender": "female", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "AZnzlk1XvdvUeBnXmlld", "display_name": "Domi", "language": "en-US", "gender": "female", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "MF3mGyEYCl7XYWbV9V6O", "display_name": "Elli", "language": "en-US", "gender": "female", "tier": "free", "provider": "elevenlabs", "sample_url": None},
    {"id": "2EiwWnXFnvU5JabPnv8n", "display_name": "Clyde", "language": "en-US", "gender": "male", "tier": "free", "provider": "elevenlabs", "sample_url": None},
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
    return {"preferred_voice_id": "21m00Tcm4TlvDq8ikWAM", "default_speed": 1.0}


@router.put("/profiles/me", summary="Update user voice profile")
async def update_voice_profile(
    preferred_voice_id: str | None = None,
    default_speed: Annotated[float | None, Query(ge=0.5, le=3.0)] = None,
) -> dict:
    return {"preferred_voice_id": preferred_voice_id, "default_speed": default_speed, "status": "updated"}
