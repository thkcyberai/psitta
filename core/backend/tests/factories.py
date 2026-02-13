"""
Psitta — Test Data Factories.

Generates realistic test data using domain models. Each factory
returns a domain object with sensible defaults that can be
overridden via keyword arguments.

Usage:
    from tests.factories import DocumentFactory, AudioSegmentFactory

    doc = DocumentFactory.create(title="My Report", page_count=25)
    audio = AudioSegmentFactory.create(document_id=doc.id)
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from psitta.models.domain import (
    AudioSegment,
    Document,
    DocumentChunk,
    DocumentStatus,
    ChunkType,
    PlaybackSession,
    ToneCategory,
    VoiceProfile,
)


class DocumentFactory:
    """Factory for Document domain objects."""

    @staticmethod
    def create(**overrides) -> Document:
        defaults = dict(
            id=str(uuid4()),
            user_id=f"user_{uuid4().hex[:12]}",
            title="Test Document — Understanding Neural Networks",
            source_type="pdf",
            status=DocumentStatus.UPLOADED,
            page_count=15,
            file_size_bytes=750_000,
            storage_key=f"uploads/{uuid4()}.pdf",
            metadata={},
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        )
        defaults.update(overrides)
        return Document(**defaults)


class ChunkFactory:
    """Factory for DocumentChunk domain objects."""

    @staticmethod
    def create(**overrides) -> DocumentChunk:
        defaults = dict(
            id=str(uuid4()),
            document_id=str(uuid4()),
            sequence_index=0,
            chunk_type=ChunkType.TEXT,
            text_content=(
                "Neural networks are computing systems inspired by "
                "biological neural networks. They learn to perform "
                "tasks by considering examples without being programmed "
                "with task-specific rules."
            ),
            tone=ToneCategory.NEUTRAL,
            page_number=1,
            character_count=200,
            metadata={},
        )
        defaults.update(overrides)
        return DocumentChunk(**defaults)


class AudioSegmentFactory:
    """Factory for AudioSegment domain objects."""

    @staticmethod
    def create(**overrides) -> AudioSegment:
        defaults = dict(
            id=str(uuid4()),
            document_id=str(uuid4()),
            chunk_id=str(uuid4()),
            voice_id="en-US-AriaNeural",
            speed=1.0,
            storage_key=f"audio/{uuid4()}.mp3",
            duration_ms=5200,
            file_size_bytes=41_600,
        )
        defaults.update(overrides)
        return AudioSegment(**defaults)


class PlaybackSessionFactory:
    """Factory for PlaybackSession domain objects."""

    @staticmethod
    def create(**overrides) -> PlaybackSession:
        defaults = dict(
            id=str(uuid4()),
            user_id=f"user_{uuid4().hex[:12]}",
            document_id=str(uuid4()),
            voice_id="en-US-AriaNeural",
            speed=1.0,
            current_chunk_index=0,
            position_ms=0,
            total_chunks=10,
        )
        defaults.update(overrides)
        return PlaybackSession(**defaults)


class VoiceProfileFactory:
    """Factory for VoiceProfile domain objects."""

    @staticmethod
    def create(**overrides) -> VoiceProfile:
        defaults = dict(
            id="en-US-AriaNeural",
            display_name="Aria",
            language="en-US",
            gender="female",
            provider="azure",
            tier="free",
            styles=["chat", "narration-professional"],
            description="Warm, versatile female voice.",
        )
        defaults.update(overrides)
        return VoiceProfile(**defaults)
