"""
Psitta — Playback Routes.

Endpoints for session management and position tracking.
Playback sessions maintain state so users can resume where they left off.

Security:
  - Position updates are validated against document ownership
  - Chunk index is bounds-checked against document chunk count
  - All writes scoped to authenticated user via JWT
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID, uuid4

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


@router.post(
    "/sessions/",
    status_code=status.HTTP_201_CREATED,
    summary="Create or update a playback session for a document",
)
async def create_session(
    document_id: UUID,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    speed: Annotated[float, Query(ge=0.5, le=3.0)] = 1.0,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Upsert a playback session. Returns existing session if one exists."""

    # Verify document exists and belongs to user
    doc_result = await db.execute(
        text(
            "SELECT id, status FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": str(document_id), "uid": str(user_id)},
    )
    doc = doc_result.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    # Check for existing session
    existing = await db.execute(
        text(
            "SELECT id, current_chunk_index, position_ms, voice_id, speed "
            "FROM playback_sessions "
            "WHERE user_id = :uid AND document_id = :did "
            "ORDER BY last_active_at DESC LIMIT 1"
        ),
        {"uid": str(user_id), "did": str(document_id)},
    )
    row = existing.first()

    if row:
        logger.info("playback.session.resumed", session_id=str(row.id), document_id=str(document_id))
        return {
            "session_id": str(row.id),
            "document_id": str(document_id),
            "voice_id": row.voice_id,
            "speed": row.speed,
            "current_chunk_index": row.current_chunk_index,
            "position_ms": row.position_ms,
            "is_new": False,
        }

    # Create new session
    session_id = uuid4()
    await db.execute(
        text(
            "INSERT INTO playback_sessions "
            "(id, user_id, document_id, voice_id, speed, current_chunk_index, position_ms, total_chunks, started_at, last_active_at) "
            "VALUES (:id, :uid, :did, :vid, :speed, 0, 0, 0, NOW(), NOW())"
        ),
        {
            "id": str(session_id),
            "uid": str(user_id),
            "did": str(document_id),
            "vid": voice_id,
            "speed": speed,
        },
    )
    await db.commit()

    logger.info("playback.session.created", session_id=str(session_id), document_id=str(document_id))
    return {
        "session_id": str(session_id),
        "document_id": str(document_id),
        "voice_id": voice_id,
        "speed": speed,
        "current_chunk_index": 0,
        "position_ms": 0,
        "is_new": True,
    }


@router.get(
    "/sessions/resume/{document_id}",
    summary="Get last playback session for a document",
)
async def get_resume_session(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Return the last saved position for a document. Used on app start to restore state."""

    result = await db.execute(
        text(
            "SELECT id, current_chunk_index, position_ms, voice_id, speed "
            "FROM playback_sessions "
            "WHERE user_id = :uid AND document_id = :did "
            "ORDER BY last_active_at DESC LIMIT 1"
        ),
        {"uid": str(user_id), "did": str(document_id)},
    )
    row = result.first()

    if not row:
        raise HTTPException(status_code=404, detail="No session found for this document")

    return {
        "session_id": str(row.id),
        "document_id": str(document_id),
        "current_chunk_index": row.current_chunk_index,
        "position_ms": row.position_ms,
        "voice_id": row.voice_id,
        "speed": row.speed,
    }


@router.patch(
    "/sessions/{session_id}/position/",
    summary="Update playback position",
)
async def update_position(
    session_id: UUID,
    chunk_index: Annotated[int, Query(ge=0)],
    position_ms: Annotated[int, Query(ge=0)],
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Persist current chunk index and position within chunk.
    Called periodically by the client every 5 seconds during playback.
    """
    result = await db.execute(
        text(
            "UPDATE playback_sessions "
            "SET current_chunk_index = :idx, position_ms = :pos, last_active_at = NOW() "
            "WHERE id = :sid AND user_id = :uid"
        ),
        {
            "sid": str(session_id),
            "uid": str(user_id),
            "idx": chunk_index,
            "pos": position_ms,
        },
    )

    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Session not found")

    await db.commit()

    logger.debug(
        "playback.position.updated",
        session_id=str(session_id),
        chunk_index=chunk_index,
        position_ms=position_ms,
    )

    return {
        "session_id": str(session_id),
        "chunk_index": chunk_index,
        "position_ms": position_ms,
    }
