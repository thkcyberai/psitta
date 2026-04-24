"""015 add chunk_positions to documents

Revision ID: 015
Revises: 014
Create Date: 2026-04-24

Adds:
  - chunk_positions JSONB column to documents (nullable)
    Persists the authoritative document-level character-offset map for
    the chunks that compose the document. Shape:
      [
        {"chunk_id": "uuid", "start_offset": int, "end_offset": int},
        ...
      ]
    Offsets are character positions in the concatenated plain text where
    chunks are joined by "\\n\\n". end_offset is exclusive.

  - Nullable because pre-M13.1b documents have never computed a position
    map. The Flutter client falls back to recomputing from chunkMap when
    the column is null, and persists on the first successful edit+save
    (lazy migration). This preserves backward-compat: a pre-M13.1b
    client reading an M13.1b document simply ignores the new column.
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "documents",
        sa.Column("chunk_positions", JSONB, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("documents", "chunk_positions")
