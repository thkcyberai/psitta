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
from enum import Enum
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
    # Authoritative chunk-offset map persisted by the M13.1b unified
    # editor save path. Shape: [{"chunk_id": str, "start_offset": int,
    # "end_offset": int}, ...]. Null for pre-M13.1b documents that
    # have never been saved through the unified editor — the client
    # then falls back to recomputing from chunkMap (lazy migration).
    chunk_positions: Optional[list[dict]] = None


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
    # Client-authored block/run JSON matching the formatted_content schema
    # produced by _extract_formatted_docx. When present, the handler stores
    # it verbatim; when None, the handler falls back to the server-side
    # _rebuild_formatted_content_for_chunk inheritance path for backward
    # compatibility with text-only callers.
    formatted_content: Optional[list[dict]] = None


class ChunkCreateRequest(BaseModel):
    """Request to insert a new chunk into an existing document.

    Used by the M13.1b unified-editor save path when a structural edit
    produces more chunks than the document currently has. The
    sequence_index is the CLIENT'S desired position; the handler may
    bump existing tail chunks via a temporary offset to avoid colliding
    with the UNIQUE (document_id, sequence_index) constraint. The final
    authoritative order is established by a subsequent
    PATCH /documents/{id} carrying chunk_positions.
    """

    sequence_index: int = Field(ge=0)
    text: str
    formatted_content: Optional[list[dict]] = None
    page_number: Optional[int] = Field(default=1, ge=1)


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


# ── Blueprints ─────────────────────────────────────────────────────────
# Controlled-value enums mirror the TEXT + CHECK lists in migration 021 /
# models.blueprint byte-for-byte. They are `str` enums so they serialize as
# their plain string value and validate ORM rows (plain str columns) by value.


class GenreEnum(str, Enum):
    """The ten blueprint genres (matches ck_blueprints_genre exactly)."""

    NOVEL = "Novel"
    MEMOIR = "Memoir"
    NON_FICTION = "Non-Fiction"
    BIOGRAPHY = "Biography"
    RESEARCH_PAPER = "Research Paper"
    CHILDRENS_PICTURE_BOOK = "Children's Picture Book"
    SCREENPLAY = "Screenplay"
    WORKBOOK_HOW_TO = "Workbook/How-To"
    BUSINESS_BOOK = "Business Book"
    SHORT_STORY_COLLECTION = "Short Story Collection"


class BlueprintStatusEnum(str, Enum):
    """Blueprint lifecycle status (matches ck_blueprints_status exactly)."""

    DRAFT = "Draft"
    COMPLETED = "Completed"
    ARCHIVED = "Archived"


class RoleEnum(str, Enum):
    """Part-document role (matches ck_part_documents_role exactly).

    Defined for the 2C placement API; not used by the 2B read surface.
    """

    MAIN_CONTENT = "Main Content"
    SUPPORTING_CONTENT = "Supporting Content"
    RESEARCH = "Research"
    NOTES = "Notes"
    REFERENCE_MATERIAL = "Reference Material"


class BlueprintSummary(StrictSchema):
    """A blueprint without its parts — the list-view shape."""

    id: UUID
    name: str
    description: str | None = None
    genre: GenreEnum
    status: BlueprintStatusEnum
    is_system: bool
    source_template_id: UUID | None = None


class PartNode(StrictSchema):
    """A blueprint part and its nested children (the parts tree).

    Self-referential; ``model_rebuild()`` below resolves the forward
    reference under Pydantic v2.
    """

    id: UUID
    name: str
    description: str | None = None
    sort_order: float
    children: list[PartNode] = []


PartNode.model_rebuild()


class BlueprintDetail(BlueprintSummary):
    """A blueprint plus its top-level parts as nested ``PartNode`` trees."""

    parts: list[PartNode] = []


class BlueprintCreate(StrictSchema):
    """Request to create a new, empty user-owned blueprint."""

    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    genre: GenreEnum
    status: BlueprintStatusEnum = BlueprintStatusEnum.DRAFT


class BlueprintUpdate(StrictSchema):
    """Partial update of a user blueprint (PATCH; every field optional)."""

    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    genre: GenreEnum | None = None
    status: BlueprintStatusEnum | None = None


class BlueprintCloneRequest(StrictSchema):
    """Optional clone body. An absent/empty body clones with the source name."""

    name: str | None = Field(default=None, min_length=1, max_length=200)


class PartCreate(StrictSchema):
    """Request to add a part to a blueprint (2D).

    ``parent_part_id`` null ⇒ a root part; otherwise the part nests under that
    parent (which must belong to the SAME blueprint — validated in the service
    and backstopped by the composite FK). ``after_part_id`` places the new part
    immediately after that sibling; null ⇒ first under the resolved parent.
    """

    name: str = Field(min_length=1, max_length=200)
    description: str | None = None
    parent_part_id: UUID | None = None
    after_part_id: UUID | None = None


class PartUpdate(StrictSchema):
    """Partial update of a part: field edits AND reorder/nest (2D).

    Presence — not value — drives intent (``model_fields_set`` / exclude_unset):
      - ``parent_part_id`` absent ⇒ parent unchanged; present-and-null ⇒ move to
        root; present-and-uuid ⇒ reparent (cycle- and same-blueprint-checked).
      - ``after_part_id`` present ⇒ reposition within the resolved parent;
        absent-but-parent-changed ⇒ append to the end of the new parent.
    """

    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    parent_part_id: UUID | None = None
    after_part_id: UUID | None = None


class PartDetail(StrictSchema):
    """A single part, flat (the write-path response shape).

    Distinct from ``PartNode`` (the nested read-tree node): this carries
    ``parent_part_id`` and ``blueprint_id`` so a client can place the affected
    part without re-reading the whole tree.
    """

    id: UUID
    blueprint_id: UUID
    parent_part_id: UUID | None = None
    name: str
    description: str | None = None
    sort_order: float


class ProjectBlueprintAdopt(StrictSchema):
    """Request to adopt a blueprint into a project (2E).

    ``is_primary`` is honoured when present; additionally the FIRST blueprint
    adopted into a project becomes primary automatically (the service ORs the
    two). Only owned, non-system blueprints are adoptable (system templates must
    be cloned first).
    """

    blueprint_id: UUID
    is_primary: bool = False


class ProjectBlueprintSetPrimary(StrictSchema):
    """Set or clear which adopted blueprint is the project's primary (2E).

    ``true`` ⇒ make this the primary (the existing primary is cleared in the
    same transaction). ``false`` ⇒ clear this row's primary flag, leaving the
    project with no primary (no auto-promotion).
    """

    is_primary: bool


class AdoptedBlueprint(BlueprintSummary):
    """A blueprint as adopted by a project: its summary plus adoption state."""

    is_primary: bool
    adopted_at: datetime
