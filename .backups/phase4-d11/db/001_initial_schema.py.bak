"""Initial schema — all core tables for Psitta MVP.

Revision ID: 001_initial
Revises: None
Create Date: 2026-02-08
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import INET, JSONB, UUID

# revision identifiers, used by Alembic.
revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Enums ──────────────────────────────────────────────────────────
    source_type = sa.Enum("pdf", "docx", "txt", "markdown", "url", name="source_type")
    document_status = sa.Enum(
        "uploaded", "parsing", "parsed", "processing", "ready", "failed",
        name="document_status",
    )
    chunk_content_type = sa.Enum(
        "text", "heading", "list", "table", "image_desc", "chart_desc",
        name="chunk_content_type",
    )
    visual_element_type = sa.Enum("image", "chart", "table", "diagram", name="visual_element_type")
    voice_profile_status = sa.Enum(
        "draft", "recording", "processing", "ready", "failed",
        name="voice_profile_status",
    )
    consent_type = sa.Enum("self", "other", name="consent_type")
    job_status = sa.Enum(
        "pending", "processing", "completed", "failed", "dead_letter",
        name="job_status",
    )
    user_tier = sa.Enum("free", "pro", "enterprise", name="user_tier")

    # Create enums explicitly
    source_type.create(op.get_bind(), checkfirst=True)
    document_status.create(op.get_bind(), checkfirst=True)
    chunk_content_type.create(op.get_bind(), checkfirst=True)
    visual_element_type.create(op.get_bind(), checkfirst=True)
    voice_profile_status.create(op.get_bind(), checkfirst=True)
    consent_type.create(op.get_bind(), checkfirst=True)
    job_status.create(op.get_bind(), checkfirst=True)
    user_tier.create(op.get_bind(), checkfirst=True)

    # ── Users ──────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("external_id", sa.String(255), unique=True, nullable=False),
        sa.Column("email", sa.String(320), unique=True, nullable=False),
        sa.Column("display_name", sa.String(255), nullable=False),
        sa.Column("preferences", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("tier", user_tier, server_default="free", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # ── Documents ──────────────────────────────────────────────────────
    op.create_table(
        "documents",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(1000), nullable=False),
        sa.Column("source_type", source_type, nullable=False),
        sa.Column("source_url", sa.Text, nullable=True),
        sa.Column("file_key", sa.String(1000), nullable=False),
        sa.Column("file_size_bytes", sa.BigInteger, nullable=False),
        sa.Column("page_count", sa.Integer, nullable=True),
        sa.Column("status", document_status, server_default="uploaded", nullable=False),
        sa.Column("error_message", sa.Text, nullable=True),
        sa.Column("metadata", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), server_default=sa.text("now() + interval '60 days'"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("idx_documents_user_id", "documents", ["user_id"])
    op.create_index("idx_documents_status", "documents", ["status"])
    op.create_index("idx_documents_expires_at", "documents", ["expires_at"])

    # ── Document Chunks ────────────────────────────────────────────────
    op.create_table(
        "document_chunks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("document_id", UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sequence_num", sa.Integer, nullable=False),
        sa.Column("content_type", chunk_content_type, nullable=False),
        sa.Column("text_content", sa.Text, nullable=False),
        sa.Column("tone_tag", sa.String(50), server_default="neutral", nullable=False),
        sa.Column("word_timestamps", JSONB, nullable=True),
        sa.Column("page_number", sa.Integer, nullable=True),
        sa.Column("metadata", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("document_id", "sequence_num", name="uq_chunks_doc_seq"),
    )
    op.create_index("idx_chunks_document_id", "document_chunks", ["document_id"])

    # ── Visual Elements ────────────────────────────────────────────────
    op.create_table(
        "visual_elements",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("document_id", UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("chunk_id", UUID(as_uuid=True), sa.ForeignKey("document_chunks.id", ondelete="SET NULL"), nullable=True),
        sa.Column("element_type", visual_element_type, nullable=False),
        sa.Column("page_number", sa.Integer, nullable=False),
        sa.Column("bounding_box", JSONB, nullable=True),
        sa.Column("image_key", sa.String(1000), nullable=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # ── Audio Segments ─────────────────────────────────────────────────
    op.create_table(
        "audio_segments",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("document_id", UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("chunk_id", UUID(as_uuid=True), sa.ForeignKey("document_chunks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("voice_id", sa.String(255), nullable=False),
        sa.Column("speed", sa.Numeric(3, 2), server_default="1.0", nullable=False),
        sa.Column("audio_key", sa.String(1000), nullable=False),
        sa.Column("duration_ms", sa.Integer, nullable=False),
        sa.Column("format", sa.String(10), server_default="mp3", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("chunk_id", "voice_id", "speed", name="uq_audio_chunk_voice_speed"),
    )
    op.create_index("idx_audio_document_id", "audio_segments", ["document_id"])

    # ── Voice Profiles ─────────────────────────────────────────────────
    op.create_table(
        "voice_profiles",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("status", voice_profile_status, server_default="draft", nullable=False),
        sa.Column("language", sa.String(10), server_default="en", nullable=False),
        sa.Column("metadata", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # ── Voice Recordings ───────────────────────────────────────────────
    op.create_table(
        "voice_recordings",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("profile_id", UUID(as_uuid=True), sa.ForeignKey("voice_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("recording_key", sa.String(1000), nullable=False),
        sa.Column("transcript", sa.Text, nullable=True),
        sa.Column("duration_ms", sa.Integer, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # ── Consent Receipts ───────────────────────────────────────────────
    op.create_table(
        "consent_receipts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("profile_id", UUID(as_uuid=True), sa.ForeignKey("voice_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("consenter_email", sa.String(320), nullable=False),
        sa.Column("consent_type", consent_type, nullable=False),
        sa.Column("consent_text", sa.Text, nullable=False),
        sa.Column("ip_address", INET, nullable=True),
        sa.Column("user_agent", sa.Text, nullable=True),
        sa.Column("consented_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )

    # ── Playback Sessions ──────────────────────────────────────────────
    op.create_table(
        "playback_sessions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("document_id", UUID(as_uuid=True), sa.ForeignKey("documents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("voice_id", sa.String(255), nullable=False),
        sa.Column("speed", sa.Numeric(3, 2), server_default="1.0", nullable=False),
        sa.Column("position_ms", sa.BigInteger, server_default="0", nullable=False),
        sa.Column("current_chunk", sa.Integer, server_default="0", nullable=False),
        sa.Column("is_active", sa.Boolean, server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    # ── Audit Log ──────────────────────────────────────────────────────
    op.create_table(
        "audit_log",
        sa.Column("id", sa.BigInteger, primary_key=True, autoincrement=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("action", sa.String(100), nullable=False),
        sa.Column("resource_type", sa.String(100), nullable=False),
        sa.Column("resource_id", UUID(as_uuid=True), nullable=True),
        sa.Column("details", JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("ip_address", INET, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("idx_audit_user_id", "audit_log", ["user_id"])
    op.create_index("idx_audit_created_at", "audit_log", ["created_at"])

    # ── Jobs ───────────────────────────────────────────────────────────
    op.create_table(
        "jobs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("type", sa.String(100), nullable=False),
        sa.Column("payload", JSONB, nullable=False),
        sa.Column("status", job_status, server_default="pending", nullable=False),
        sa.Column("priority", sa.Integer, server_default="0", nullable=False),
        sa.Column("attempts", sa.Integer, server_default="0", nullable=False),
        sa.Column("max_attempts", sa.Integer, server_default="3", nullable=False),
        sa.Column("idempotency_key", sa.String(255), unique=True, nullable=True),
        sa.Column("error_message", sa.Text, nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("idx_jobs_status", "jobs", ["status"])
    op.create_index("idx_jobs_type", "jobs", ["type"])

    # ── Updated_at trigger function ────────────────────────────────────
    op.execute("""
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = now();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
    """)

    # Apply trigger to all tables with updated_at
    for table in ("users", "documents", "voice_profiles", "playback_sessions", "jobs"):
        op.execute(f"""
            CREATE TRIGGER trigger_{table}_updated_at
                BEFORE UPDATE ON {table}
                FOR EACH ROW
                EXECUTE FUNCTION update_updated_at_column();
        """)

    # ── Expired documents cleanup function ─────────────────────────────
    op.execute("""
        CREATE OR REPLACE FUNCTION cleanup_expired_documents()
        RETURNS INTEGER AS $$
        DECLARE
            deleted_count INTEGER;
        BEGIN
            DELETE FROM documents WHERE expires_at < now();
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RETURN deleted_count;
        END;
        $$ language 'plpgsql';
    """)


def downgrade() -> None:
    # Drop triggers
    for table in ("users", "documents", "voice_profiles", "playback_sessions", "jobs"):
        op.execute(f"DROP TRIGGER IF EXISTS trigger_{table}_updated_at ON {table}")

    op.execute("DROP FUNCTION IF EXISTS update_updated_at_column()")
    op.execute("DROP FUNCTION IF EXISTS cleanup_expired_documents()")

    # Drop tables in reverse dependency order
    op.drop_table("jobs")
    op.drop_table("audit_log")
    op.drop_table("playback_sessions")
    op.drop_table("consent_receipts")
    op.drop_table("voice_recordings")
    op.drop_table("voice_profiles")
    op.drop_table("audio_segments")
    op.drop_table("visual_elements")
    op.drop_table("document_chunks")
    op.drop_table("documents")
    op.drop_table("users")

    # Drop enums
    for enum_name in (
        "job_status", "consent_type", "voice_profile_status",
        "visual_element_type", "chunk_content_type", "document_status",
        "source_type", "user_tier",
    ):
        op.execute(f"DROP TYPE IF EXISTS {enum_name}")
