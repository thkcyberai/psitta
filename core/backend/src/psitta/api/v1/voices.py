"""
Voice endpoints — catalog browsing, preview, custom profiles, consent.
"""

from __future__ import annotations

import uuid
from typing import Any

import structlog
from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import Response

from psitta.dependencies import CurrentUserId, DbSession, Providers
from psitta.providers.interfaces.contracts import VoiceFilter
from psitta.schemas.api import (
    ApiListResponse,
    ApiResponse,
    ConsentSubmitRequest,
    CustomVoiceCreateRequest,
    CustomVoiceResponse,
    PaginationMeta,
    VoiceResponse,
)

logger = structlog.get_logger()
router = APIRouter()


@router.get("", response_model=ApiListResponse[VoiceResponse])
async def list_voices(
    providers: Providers,
    language: str | None = Query(None),
    gender: str | None = Query(None),
    style: str | None = Query(None),
    provider: str | None = Query(None),
    is_premium: bool | None = Query(None),
) -> dict[str, Any]:
    """List available voices with filtering."""
    filters = VoiceFilter(
        language=language,
        gender=gender,
        style=style,
        provider=provider,
        is_premium=is_premium,
    )
    voices = await providers.voice_catalog.list_voices(filters)

    return {
        "data": [
            VoiceResponse(
                id=v.id,
                name=v.name,
                language=v.language,
                gender=v.gender,
                style=v.style,
                provider=v.provider,
                preview_url=f"/api/v1/voices/{v.id}/preview",
                is_premium=v.is_premium,
                quality_score=v.quality_score,
                description=v.description,
            )
            for v in voices
        ],
        "meta": PaginationMeta(total=len(voices)),
    }


@router.get("/{voice_id}/preview")
async def preview_voice(
    voice_id: str,
    providers: Providers,
) -> Response:
    """Get a 10-second preview audio sample for a voice."""
    audio_data = await providers.voice_catalog.get_preview_audio(voice_id)
    return Response(
        content=audio_data,
        media_type="audio/mpeg",
        headers={"Cache-Control": "public, max-age=86400"},
    )


@router.post(
    "/custom",
    response_model=ApiResponse[CustomVoiceResponse],
    status_code=status.HTTP_201_CREATED,
)
async def create_custom_voice(
    body: CustomVoiceCreateRequest,
    db: DbSession,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Create a new custom voice profile."""
    from psitta.models.domain import VoiceProfile

    profile = VoiceProfile(
        user_id=user_id,
        name=body.name,
        language=body.language,
        status="draft",
    )
    db.add(profile)
    await db.flush()

    logger.info("voice_profile_created", profile_id=str(profile.id), user_id=user_id)
    return {"data": CustomVoiceResponse.model_validate(profile)}


@router.post(
    "/custom/{profile_id}/recordings",
    status_code=status.HTTP_201_CREATED,
)
async def upload_recording(
    profile_id: uuid.UUID,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
    audio: UploadFile = File(...),
    transcript: str | None = Form(None),
) -> dict[str, str]:
    """Upload a voice recording to a custom profile."""
    from psitta.models.domain import VoiceRecording

    content = await audio.read()

    # Validate minimum duration (30 seconds ~ 480KB for WAV at 16kHz)
    if len(content) < 100_000:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Recording too short. Minimum 30 seconds required.",
        )

    # Store in S3
    key = f"voices/{profile_id}/recordings/{uuid.uuid4()}.wav"
    await providers.storage.upload(key, content, content_type="audio/wav")

    recording = VoiceRecording(
        profile_id=profile_id,
        recording_key=key,
        transcript=transcript,
        duration_ms=0,  # TODO: calculate from audio metadata
    )
    db.add(recording)

    return {"status": "uploaded", "recording_id": str(recording.id)}


@router.post(
    "/custom/{profile_id}/consent",
    status_code=status.HTTP_201_CREATED,
)
async def submit_consent(
    profile_id: uuid.UUID,
    body: ConsentSubmitRequest,
    db: DbSession,
    user_id: CurrentUserId,
) -> dict[str, str]:
    """Submit a consent receipt for a custom voice profile."""
    from psitta.models.domain import ConsentReceipt

    receipt = ConsentReceipt(
        profile_id=profile_id,
        consenter_email=body.consenter_email,
        consent_type=body.consent_type,
        consent_text=body.consent_text,
    )
    db.add(receipt)

    logger.info(
        "consent_submitted",
        profile_id=str(profile_id),
        consent_type=body.consent_type,
    )
    return {"status": "recorded", "receipt_id": str(receipt.id)}
