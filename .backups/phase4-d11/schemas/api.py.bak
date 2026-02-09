"""
API schemas — Pydantic models for request/response validation.

Strict validation, explicit types, no optional fields without good reason.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ConfigDict, EmailStr, Field, HttpUrl


T = TypeVar("T")


# ── Generic Envelope ─────────────────────────────────────────────────


class PaginationMeta(BaseModel):
    cursor: str | None = None
    has_more: bool = False
    total: int | None = None


class ApiResponse(BaseModel, Generic[T]):
    data: T
    meta: PaginationMeta | None = None


class ApiListResponse(BaseModel, Generic[T]):
    data: list[T]
    meta: PaginationMeta


class ProblemDetail(BaseModel):
    """RFC 7807 Problem Details."""

    type: str
    title: str
    status: int
    detail: str
    instance: str | None = None
    errors: list[dict[str, str]] | None = None


# ── Document Schemas ─────────────────────────────────────────────────


class DocumentUploadRequest(BaseModel):
    """Metadata sent alongside file upload (multipart form)."""

    title: str | None = None
    voice_id: str | None = None
    auto_play: bool = True


class DocumentURLRequest(BaseModel):
    """Request to ingest a document from a URL."""

    url: HttpUrl
    title: str | None = None
    voice_id: str | None = None
    auto_play: bool = True


class DocumentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    source_type: str
    status: str
    file_size_bytes: int
    page_count: int | None = None
    error_message: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)
    expires_at: datetime
    created_at: datetime
    updated_at: datetime


class DocumentListParams(BaseModel):
    status: str | None = None
    source_type: str | None = None
    cursor: str | None = None
    limit: int = Field(default=20, ge=1, le=100)
    sort: str = "-created_at"


class ChunkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    sequence_num: int
    content_type: str
    text_content: str
    tone_tag: str
    word_timestamps: list[dict[str, Any]] | None = None
    page_number: int | None = None


# ── Playback Schemas ─────────────────────────────────────────────────


class PlaybackStartRequest(BaseModel):
    voice_id: str
    speed: float = Field(default=1.0, ge=0.5, le=3.0)
    start_chunk: int = Field(default=0, ge=0)


class PlaybackSessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    session_id: uuid.UUID
    stream_url: str
    captions_url: str
    total_chunks: int
    estimated_duration_ms: int


class PlaybackUpdateRequest(BaseModel):
    position_ms: int | None = Field(default=None, ge=0)
    speed: float | None = Field(default=None, ge=0.5, le=3.0)
    voice_id: str | None = None


# ── Voice Schemas ────────────────────────────────────────────────────


class VoiceResponse(BaseModel):
    id: str
    name: str
    language: str
    gender: str
    style: str
    provider: str
    preview_url: str
    is_premium: bool
    quality_score: float
    description: str = ""


class VoiceListParams(BaseModel):
    language: str | None = None
    gender: str | None = None
    style: str | None = None
    provider: str | None = None
    is_premium: bool | None = None


class CustomVoiceCreateRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    language: str = Field(default="en-US", min_length=2, max_length=10)


class CustomVoiceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    status: str
    language: str
    created_at: datetime


class ConsentSubmitRequest(BaseModel):
    consent_type: str = Field(..., pattern="^(self|other)$")
    consenter_email: EmailStr
    consent_text: str = Field(..., min_length=10, max_length=5000)


# ── User Schemas ─────────────────────────────────────────────────────


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    display_name: str
    preferences: dict[str, Any] = Field(default_factory=dict)
    tier: str
    created_at: datetime


class UserUpdateRequest(BaseModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=255)
    preferences: dict[str, Any] | None = None


# ── Processing Status (SSE) ─────────────────────────────────────────


class ProcessingProgressEvent(BaseModel):
    stage: str
    progress: float = Field(ge=0.0, le=1.0)
    message: str


class ProcessingCompleteEvent(BaseModel):
    status: str
    page_count: int
    chunk_count: int
    duration_estimate_ms: int
