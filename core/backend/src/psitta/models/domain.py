"""
Psitta — Domain Models.

Pure Python dataclasses representing the core business entities.
These are NOT ORM models — they are transport objects used between
services, providers, and API layers.

ORM models (SQLAlchemy) live in db/models/ and map to these.

Design:
  - Immutable by default (frozen=True) to prevent accidental mutation
  - UUIDs for all entity IDs (no sequential integers exposed)
  - Timestamps in UTC (timezone-aware)
  - Enums for finite state machines (document status, user tier)
"""

from __future__ import annotations

import enum
from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import UUID, uuid4


# ── Enums ──────────────────────────────────────────────────────────────

class DocumentStatus(str, enum.Enum):
    """Document processing pipeline states.

    State machine:
      uploaded → parsing → chunking → synthesizing → ready
                                                   ↘ failed
      Any state can transition to 'failed' on unrecoverable error.
      'deleted' is a terminal soft-delete state.
    """

    UPLOADED = "uploaded"
    PARSING = "parsing"
    CHUNKING = "chunking"
    SYNTHESIZING = "synthesizing"
    READY = "ready"
    FAILED = "failed"
    DELETED = "deleted"


class UserTier(str, enum.Enum):
    """Subscription tiers governing feature access and limits."""

    FREE = "free"
    PRO = "pro"
    ENTERPRISE = "enterprise"
    ADMIN = "admin"


class ChunkType(str, enum.Enum):
    """Types of content chunks extracted from documents."""

    TEXT = "text"
    HEADING = "heading"
    IMAGE_DESCRIPTION = "image_description"
    TABLE = "table"
    CODE_BLOCK = "code_block"
    FOOTNOTE = "footnote"


class ToneCategory(str, enum.Enum):
    """Prosody tone categories for expressive TTS."""

    NEUTRAL = "neutral"
    FORMAL = "formal"
    CONVERSATIONAL = "conversational"
    EMPHATIC = "emphatic"
    NARRATIVE = "narrative"
    TECHNICAL = "technical"


# ── Domain Entities ────────────────────────────────────────────────────

@dataclass(frozen=True)
class Document:
    """A user-uploaded document being processed for narration."""

    id: UUID = field(default_factory=uuid4)
    user_id: str = ""
    title: str = ""
    source_type: str = "pdf"
    status: DocumentStatus = DocumentStatus.UPLOADED
    page_count: int = 0
    file_size_bytes: int = 0
    storage_key: str = ""
    metadata: dict = field(default_factory=dict)
    created_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc)
    )
    updated_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc)
    )


@dataclass(frozen=True)
class DocumentChunk:
    """A discrete content segment extracted from a document.

    Chunks are the atomic unit of TTS synthesis — each chunk
    produces exactly one audio segment.
    """

    id: UUID = field(default_factory=uuid4)
    document_id: UUID = field(default_factory=uuid4)
    sequence_index: int = 0
    chunk_type: ChunkType = ChunkType.TEXT
    text_content: str = ""
    tone: ToneCategory = ToneCategory.NEUTRAL
    page_number: int = 1
    character_count: int = 0
    metadata: dict = field(default_factory=dict)


@dataclass(frozen=True)
class AudioSegment:
    """A synthesized audio file for a single document chunk."""

    id: UUID = field(default_factory=uuid4)
    document_id: UUID = field(default_factory=uuid4)
    chunk_id: UUID = field(default_factory=uuid4)
    voice_id: str = "en-US-AriaNeural"
    speed: float = 1.0
    storage_key: str = ""
    duration_ms: int = 0
    file_size_bytes: int = 0
    format: str = "mp3"
    created_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc)
    )


@dataclass(frozen=True)
class PlaybackSession:
    """An active listening session tracking playback position."""

    id: UUID = field(default_factory=uuid4)
    user_id: str = ""
    document_id: UUID = field(default_factory=uuid4)
    voice_id: str = "en-US-AriaNeural"
    speed: float = 1.0
    current_chunk_index: int = 0
    position_ms: int = 0
    total_chunks: int = 0
    started_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc)
    )
    last_active_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc)
    )


@dataclass(frozen=True)
class VoiceProfile:
    """A TTS voice available in the catalog."""

    id: str = ""
    display_name: str = ""
    language: str = "en-US"
    gender: str = "female"
    provider: str = "azure"
    tier: str = "free"
    sample_audio_key: str = ""
    styles: list[str] = field(default_factory=list)
    description: str = ""
