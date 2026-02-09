"""
Playback service — audio streaming, caption sync, session management.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from typing import AsyncIterator

import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.models.domain import AudioSegment, Document, DocumentChunk, PlaybackSession
from psitta.providers.interfaces.contracts import ProviderRegistry, TTSOptions

logger = structlog.get_logger()


@dataclass
class SessionInfo:
    id: uuid.UUID
    total_chunks: int
    estimated_duration_ms: int


class PlaybackService:
    """Orchestrates audio playback, streaming, and caption synchronization."""

    def __init__(self, db: AsyncSession, providers: ProviderRegistry | None) -> None:
        self._db = db
        self._providers = providers

    async def start_session(
        self,
        user_id: str,
        document_id: uuid.UUID,
        voice_id: str,
        speed: float = 1.0,
        start_chunk: int = 0,
    ) -> SessionInfo:
        """Create a new playback session."""
        # Verify document exists and is ready
        result = await self._db.execute(
            select(Document).where(
                Document.id == document_id,
                Document.user_id == user_id,
                Document.status == "ready",
            )
        )
        document = result.scalar_one_or_none()
        if document is None:
            raise ValueError(f"Document {document_id} not found or not ready")

        # Count chunks
        chunk_count_result = await self._db.execute(
            select(DocumentChunk)
            .where(DocumentChunk.document_id == document_id)
        )
        chunks = chunk_count_result.scalars().all()
        total_chunks = len(list(chunks))

        # Create session
        session = PlaybackSession(
            user_id=user_id,
            document_id=document_id,
            voice_id=voice_id,
            speed=speed,
            current_chunk=start_chunk,
        )
        self._db.add(session)
        await self._db.flush()

        # Rough estimate: ~150 words/min at 1x speed, ~5 chars/word
        total_chars = sum(len(c.text_content) for c in chunks)
        words = total_chars / 5
        duration_ms = int((words / 150) * 60 * 1000 / speed)

        return SessionInfo(
            id=session.id,
            total_chunks=total_chunks,
            estimated_duration_ms=duration_ms,
        )

    async def stream_audio(
        self, session_id: uuid.UUID, user_id: str
    ) -> AsyncIterator[bytes]:
        """Stream audio chunks for progressive playback."""
        session = await self._get_session(session_id, user_id)
        if self._providers is None:
            raise RuntimeError("Providers not available")

        # Fetch chunks in order
        result = await self._db.execute(
            select(DocumentChunk)
            .where(DocumentChunk.document_id == session.document_id)
            .where(DocumentChunk.sequence_num >= session.current_chunk)
            .order_by(DocumentChunk.sequence_num)
        )
        chunks = result.scalars().all()

        for chunk in chunks:
            # Check audio cache
            cached = await self._db.execute(
                select(AudioSegment).where(
                    AudioSegment.chunk_id == chunk.id,
                    AudioSegment.voice_id == session.voice_id,
                    AudioSegment.speed == session.speed,
                )
            )
            audio_segment = cached.scalar_one_or_none()

            if audio_segment:
                # Serve from cache
                audio_data = await self._providers.storage.download(audio_segment.audio_key)
                yield audio_data
            else:
                # Synthesize on the fly
                options = TTSOptions(speed=session.speed)
                async for audio_chunk in self._providers.tts.synthesize(
                    text=chunk.text_content,
                    voice_id=session.voice_id,
                    options=options,
                ):
                    yield audio_chunk.data

    async def stream_captions(
        self, session_id: uuid.UUID, user_id: str
    ) -> AsyncIterator[str]:
        """Stream caption events as SSE."""
        session = await self._get_session(session_id, user_id)

        result = await self._db.execute(
            select(DocumentChunk)
            .where(DocumentChunk.document_id == session.document_id)
            .order_by(DocumentChunk.sequence_num)
        )
        chunks = result.scalars().all()

        cumulative_ms = 0
        for chunk in chunks:
            event_data = {
                "chunk_seq": chunk.sequence_num,
                "text": chunk.text_content,
                "start_ms": cumulative_ms,
                "words": chunk.word_timestamps or [],
            }
            yield f"event: caption\ndata: {json.dumps(event_data)}\n\n"
            # Rough duration estimate
            cumulative_ms += len(chunk.text_content) * 50  # ~50ms per char at 1x

    async def update_session(
        self,
        session_id: uuid.UUID,
        user_id: str,
        position_ms: int | None = None,
        speed: float | None = None,
        voice_id: str | None = None,
    ) -> None:
        """Update a playback session's state."""
        session = await self._get_session(session_id, user_id)
        if position_ms is not None:
            session.position_ms = position_ms
        if speed is not None:
            session.speed = speed
        if voice_id is not None:
            session.voice_id = voice_id

    async def _get_session(
        self, session_id: uuid.UUID, user_id: str
    ) -> PlaybackSession:
        """Fetch a session ensuring it belongs to the user."""
        result = await self._db.execute(
            select(PlaybackSession).where(
                PlaybackSession.id == session_id,
                PlaybackSession.user_id == user_id,
                PlaybackSession.is_active == True,  # noqa: E712
            )
        )
        session = result.scalar_one_or_none()
        if session is None:
            raise ValueError(f"Playback session {session_id} not found")
        return session
