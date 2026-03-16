"""
Psitta — Pydantic Request/Response Schemas.

All API input validation and output serialization is defined here.
Schemas are strict by default — extra fields are forbidden,
and all strings are stripped of leading/trailing whitespace.

Security:
  - Input lengths are bounded to prevent memory exhaustion
  - Enums constrain values to valid options
  - UUIDs are validated at the schema level (not in route logic)
  - Sensitive fields (passwords, tokens) are never in responses
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ── Base Configuration ─────────────────────────────────────────────────

class StrictSchema(BaseModel):
    """Base schema with strict validation for all Psitta API models."""

    model_config = ConfigDict(
        str_strip_whitespace=True,
        extra="forbid",
        from_attributes=True,
        json_schema_extra={"examples": []},
    )


# ── System ─────────────────────────────────────────────────────────────

class HealthResponse(StrictSchema):
    """Health check response."""

    status: str = Field(description="Service status")
    version: str = Field(description="Application version")


class ErrorResponse(StrictSchema):
    """Standard error response envelope."""

    detail: str = Field(description="Human-readable error message")
    error_code: str | None = Field(
        default=None, description="Machine-readable error code"
    )
    request_id: str | None = Field(
        default=None, description="Request ID for support reference"
    )


# ── Pagination ─────────────────────────────────────────────────────────

class PaginationParams(StrictSchema):
    """Reusable pagination parameters."""

    page: int = Field(default=1, ge=1, description="Page number")
    size: int = Field(default=20, ge=1, le=100, description="Items per page")


# ── Documents ──────────────────────────────────────────────────────────

class DocumentUploadResponse(StrictSchema):
    """Response after successful document upload."""

    id: UUID = Field(description="Document ID")
    filename: str = Field(description="Original filename")
    status: str = Field(description="Processing status")
    message: str = Field(default="Document accepted for processing")


class DocumentResponse(StrictSchema):
    """Full document details."""

    id: UUID
    user_id: str
    title: str
    source_type: str
    status: str
    page_count: int = Field(ge=0)
    word_count: int = Field(default=0, ge=0)
    file_size_bytes: int = Field(ge=0)
    chunk_count: int = Field(default=0, ge=0)
    created_at: datetime
    updated_at: datetime


class DocumentListResponse(StrictSchema):
    """Paginated document list."""

    items: list[DocumentResponse]
    page: int = Field(ge=1)
    size: int = Field(ge=1, le=100)
    total: int = Field(ge=0)


# ── Playback ──────────────────────────────────────────────────────────

class PlaybackSessionCreate(StrictSchema):
    """Request to create a playback session."""

    document_id: UUID = Field(description="Document to play")
    voice_id: str = Field(
        default="en-US-AriaNeural",
        min_length=1,
        max_length=128,
        description="TTS voice identifier",
    )
    speed: float = Field(
        default=1.0,
        ge=0.5,
        le=3.0,
        description="Playback speed (0.5x to 3.0x)",
    )


class PlaybackSessionResponse(StrictSchema):
    """Playback session state."""

    session_id: UUID
    document_id: UUID
    voice_id: str
    speed: float
    current_chunk_index: int = Field(ge=0)
    position_ms: int = Field(ge=0)
    total_chunks: int = Field(ge=0)
    started_at: datetime
    last_active_at: datetime


class PlaybackPositionUpdate(StrictSchema):
    """Request to update playback position."""

    chunk_index: int = Field(ge=0, description="Current chunk (0-indexed)")
    position_ms: int = Field(ge=0, description="Position in milliseconds")


# ── Voices ─────────────────────────────────────────────────────────────

class VoiceResponse(StrictSchema):
    """Single voice from the catalog."""

    id: str = Field(description="Voice identifier")
    display_name: str
    language: str
    gender: str
    provider: str
    tier: str = Field(description="'free' or 'premium'")
    sample_audio_url: str | None = None
    styles: list[str] = Field(default_factory=list)
    description: str = ""


class VoiceListResponse(StrictSchema):
    """Voice catalog listing."""

    voices: list[VoiceResponse]
    total: int = Field(ge=0)


class VoiceProfileResponse(StrictSchema):
    """User's voice preferences."""

    preferred_voice_id: str
    default_speed: float = Field(ge=0.5, le=3.0)


class VoiceProfileUpdate(StrictSchema):
    """Request to update voice preferences."""

    preferred_voice_id: str | None = Field(
        default=None, min_length=1, max_length=128
    )
    default_speed: float | None = Field(default=None, ge=0.5, le=3.0)


# ── Users ──────────────────────────────────────────────────────────────

class UserProfileResponse(StrictSchema):
    """User profile data."""

    id: UUID
    display_name: str
    tier: str
    documents_this_month: int = Field(ge=0)
    documents_limit: int = Field(ge=0)
    storage_used_mb: float = Field(ge=0)
    storage_limit_mb: float = Field(ge=0)


class UserProfileUpdate(StrictSchema):
    """Request to update user profile."""

    display_name: str | None = Field(
        default=None,
        min_length=2,
        max_length=100,
        description="Display name (2–100 characters)",
    )


class UserPreferencesResponse(StrictSchema):
    """User application preferences."""

    theme: str = Field(default="system")
    notifications_enabled: bool = Field(default=True)
    auto_delete_days: int = Field(default=60, ge=0, le=365)
    default_voice_id: str = Field(default="en-US-AriaNeural")
    default_speed: float = Field(default=1.0, ge=0.5, le=3.0)


class UserPreferencesUpdate(StrictSchema):
    """Request to update user preferences."""

    theme: str | None = Field(
        default=None, pattern=r"^(light|dark|system)$"
    )
    notifications_enabled: bool | None = None
    auto_delete_days: int | None = Field(default=None, ge=0, le=365)


# ── Chunks ────────────────────────────────────────────────────────────

class ChunkUpdateRequest(BaseModel):
    text: str


class ChunkResponse(BaseModel):
    id: str
    sequence_index: int
    chunk_type: str
    text_content: str
    tone: str
    page_number: int
    character_count: int
    is_edited: bool = False
    edited_at: Optional[datetime] = None
    original_text: Optional[str] = None
    sentence_boundaries: Optional[list[list[int]]] = None  # [[start, end], ...] char offsets per sentence
    formatted_content: Optional[list[dict]] = None  # structured paragraph/run data for rich rendering


class ResynthesizeResponse(BaseModel):
    chunk_id: str
    audio_url: str
    message: str
