"""030 Map a document to a narrative beat (Scene Mapper).

Records which beat of the project's chosen narrative a document covers — the
storage behind the Scene Mapper. A document covers at most one beat, so this is
a single nullable column rather than a join table.

Column added to ``documents`` (nullable; NULL = unassigned):
  * ``narrative_beat`` TEXT — the chosen beat's LABEL (e.g. 'Ordeal'), matching
    one entry of the owning project's ``narrative_beats``. Stored as the label
    (not an index) so it stays human-readable; if the project's narrative later
    changes, a mapping to a beat no longer in the list simply stops displaying.

Additive and fully reversible (drop the column). Existing documents are
untouched and read NULL.

Revision ID: 030
Revises: 029
Create Date: 2026-06-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "030"
down_revision = "029"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "documents",
        sa.Column("narrative_beat", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("documents", "narrative_beat")
