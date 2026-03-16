"""010 add formatted_content to document_chunks

Revision ID: 010
Revises: 009
Create Date: 2026-03-16

Adds:
  - formatted_content JSONB column to document_chunks (nullable)
    Stores structured paragraph/run data for rich rendering.
    text_content remains the source of truth for TTS.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "010"
down_revision = "009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "document_chunks",
        sa.Column("formatted_content", JSONB, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("document_chunks", "formatted_content")
