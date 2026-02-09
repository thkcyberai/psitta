"""
001 — Initial Schema.

Creates the core tables for Psitta:
  - users
  - documents
  - document_chunks
  - audio_segments
  - playback_sessions
  - voice_profiles
  - audit_log

Revision ID: 001
Revises: None
Create Date: 2025-02-08
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# Revision identifiers
revision: str = "001"
down_revision: str | None = None
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    """Create initial database schema."""

    # ── Enums ──────────────────────────────────────────────────────────
    document_status = postgresql.ENUM(
        "uploaded", "parsing", "chunking", "synthesizing",
        "ready", "failed", "deleted",
        name="document_status",
        create_type=True,
    )

    user_tier = postgresql.ENUM(
        "free", "pro", "enterprise",
        name="user_tier",
        create_type=True,
    )

    chunk_type = postgresql.ENUM(
        "text", "heading", "image_description",
        "table", "code_block", "footnote",
        name="chunk_type",
        create_type=True,
    )

    tone_category = postgresql.ENUM(
        "neutral", "formal", "conversational",
        "emphatic", "narrative", "technical",
        name="tone_category",
        create_type=True,
    )

    # ── Users ──────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("external_id", sa.String(255), unique=True, nullable=False),
        sa.Column("email", sa.String(320), unique=True, nullable=False),
        sa.Column("display_name", sa.String(100), nullable=False, server_default=""),
        sa.Column("tier", user_tier, nullable=False, server_default="free"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_users_external_id", "users", ["external_id"])
    op.create_index("ix_users_email", "users", ["email"])

    # ── Documents ──────────────────────────────────────────────────────
    op.create_table(
        "documents",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("source_type", sa.String(20), nullable=False),
        sa.Column("status", document_status, nullable=False, server_default="uploaded"),
        sa.Column("page_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("file_size_bytes", sa.BigInteger(), nullable=False, server_default="0"),
        sa.Column("storage_key", sa.String(1024), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("metadata_json", postgresql.JSONB(), server_default="{}"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_documents_user_id", "documents", ["user_id"])
    op.create_index("ix_documents_status", "documents", ["status"])
    op.create_index("ix_documents_user_status", "documents", ["user_id", "status"])

    # ── Document Chunks ────────────────────────────────────────────────
    op.create_table(
        "document_chunks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("document_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sequence_index", sa.Integer(), nullable=False),
        sa.Column("chunk_type", chunk_type, nullable=False, server_default="text"),
        sa.Column("text_content", sa.Text(), nullable=False),
        sa.Column("tone", tone_category, nullable=False, server_default="neutral"),
        sa.Column("page_number", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("character_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("metadata_json", postgresql.JSONB(), server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_chunks_document_id", "document_chunks", ["document_id"])
    op.create_index("ix_chunks_document_seq", "document_chunks", ["document_id", "sequence_index"], unique=True)

    # ── Audio Segments ─────────────────────────────────────────────────
    op.create_table(
        "audio_segments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("document_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("chunk_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("document_chunks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("voice_id", sa.String(128), nullable=False),
        sa.Column("speed", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("storage_key", sa.String(1024), nullable=False),
        sa.Column("duration_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("file_size_bytes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("format", sa.String(10), nullable=False, server_default="'mp3'"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_audio_document_id", "audio_segments", ["document_id"])
    op.create_index("ix_audio_chunk_voice", "audio_segments", ["chunk_id", "voice_id", "speed"], unique=True)

    # ── Playback Sessions ──────────────────────────────────────────────
    op.create_table(
        "playback_sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("document_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("voice_id", sa.String(128), nullable=False),
        sa.Column("speed", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("current_chunk_index", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("position_ms", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_chunks", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
        sa.Column("last_active_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_sessions_user_id", "playback_sessions", ["user_id"])
    op.create_index("ix_sessions_document", "playback_sessions", ["user_id", "document_id"])

    # ── Voice Profiles (user preferences) ──────────────────────────────
    op.create_table(
        "voice_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("preferred_voice_id", sa.String(128), nullable=False, server_default="'en-US-AriaNeural'"),
        sa.Column("default_speed", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )

    # ── Audit Log ──────────────────────────────────────────────────────
    op.create_table(
        "audit_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("resource_type", sa.String(50), nullable=False),
        sa.Column("resource_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("details_json", postgresql.JSONB(), server_default="{}"),
        sa.Column("ip_address", sa.String(45), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("NOW()"), nullable=False),
    )
    op.create_index("ix_audit_user_id", "audit_log", ["user_id"])
    op.create_index("ix_audit_action", "audit_log", ["action"])
    op.create_index("ix_audit_created_at", "audit_log", ["created_at"])


def downgrade() -> None:
    """Drop all tables in reverse dependency order."""
    op.drop_table("audit_log")
    op.drop_table("voice_profiles")
    op.drop_table("playback_sessions")
    op.drop_table("audio_segments")
    op.drop_table("document_chunks")
    op.drop_table("documents")
    op.drop_table("users")

    # Drop enums
    op.execute("DROP TYPE IF EXISTS tone_category")
    op.execute("DROP TYPE IF EXISTS chunk_type")
    op.execute("DROP TYPE IF EXISTS user_tier")
    op.execute("DROP TYPE IF EXISTS document_status")
