"""
Playback endpoints — start session, stream audio, caption sync, update position.
"""

from __future__ import annotations

import uuid
from typing import Any

import structlog
from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from psitta.dependencies import CurrentUserId, DbSession, Providers
from psitta.schemas.api import (
    ApiResponse,
    PlaybackSessionResponse,
    PlaybackStartRequest,
    PlaybackUpdateRequest,
)
from psitta.services.playback_service import PlaybackService

logger = structlog.get_logger()
router = APIRouter()


@router.post(
    "/{document_id}/play",
    response_model=ApiResponse[PlaybackSessionResponse],
    status_code=status.HTTP_201_CREATED,
)
async def start_playback(
    document_id: uuid.UUID,
    body: PlaybackStartRequest,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Start a new playback session for a document."""
    service = PlaybackService(db=db, providers=providers)
    session = await service.start_session(
        user_id=user_id,
        document_id=document_id,
        voice_id=body.voice_id,
        speed=body.speed,
        start_chunk=body.start_chunk,
    )

    return {
        "data": PlaybackSessionResponse(
            session_id=session.id,
            stream_url=f"/api/v1/playback/{session.id}/stream",
            captions_url=f"/api/v1/playback/{session.id}/captions",
            total_chunks=session.total_chunks,
            estimated_duration_ms=session.estimated_duration_ms,
        )
    }


@router.get("/{session_id}/stream")
async def stream_audio(
    session_id: uuid.UUID,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
) -> StreamingResponse:
    """Stream audio for an active playback session."""
    service = PlaybackService(db=db, providers=providers)
    audio_stream = service.stream_audio(session_id=session_id, user_id=user_id)

    return StreamingResponse(
        audio_stream,
        media_type="audio/mpeg",
        headers={
            "Transfer-Encoding": "chunked",
            "Cache-Control": "no-cache",
        },
    )


@router.get("/{session_id}/captions")
async def stream_captions(
    session_id: uuid.UUID,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
) -> StreamingResponse:
    """Stream caption events (SSE) for an active playback session."""
    service = PlaybackService(db=db, providers=providers)
    caption_stream = service.stream_captions(session_id=session_id, user_id=user_id)

    return StreamingResponse(
        caption_stream,
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


@router.patch("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def update_playback(
    session_id: uuid.UUID,
    body: PlaybackUpdateRequest,
    db: DbSession,
    user_id: CurrentUserId,
) -> None:
    """Update playback position, speed, or voice."""
    service = PlaybackService(db=db, providers=None)  # type: ignore[arg-type]
    await service.update_session(
        session_id=session_id,
        user_id=user_id,
        position_ms=body.position_ms,
        speed=body.speed,
        voice_id=body.voice_id,
    )
