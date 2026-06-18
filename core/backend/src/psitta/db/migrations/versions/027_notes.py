"""027 Add notes table for Scribbles.

A note (a "scribble") is a short, colored text snippet for quick idea capture.
Scribbles are intentionally NOT documents — they have no chunks, audio, covers
or pipeline — so they get their own small, owned table rather than overloading
``documents``.

Columns:
  * ``id``        — UUID primary key.
  * ``user_id``   — owner (FK to users.id, ON DELETE CASCADE).
  * ``content``   — the note text.
  * ``color``     — a pastel tag (e.g. 'yellow', 'pink'), default 'yellow'.
  * ``created_at`` / ``updated_at`` — timestamps.

Additive and fully reversible (drop the table).

Revision ID: 027
Revises: 026
Create Date: 2026-06-18
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "027"
down_revision = "026"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notes",
        sa.Column(
            "id", postgresql.UUID(as_uuid=True), primary_key=True
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("content", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "color", sa.String(length=20), nullable=False,
            server_default="yellow",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_notes_user_id", "notes", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_notes_user_id", table_name="notes")
    op.drop_table("notes")
