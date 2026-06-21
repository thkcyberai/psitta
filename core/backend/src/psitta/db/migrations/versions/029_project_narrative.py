"""029 Record a project's chosen narrative structure.

Stores the writer's narrative pick on the PROJECT (the book) — separate from the
Book Structure. A narrative is the story shape, not a book outline, so it lives
here, never as blueprint sections. This is what the Project → Narrative tab
displays and what the AI will later coach against.

Columns added to ``projects`` (all nullable; NULL = no narrative chosen yet):
  * ``narrative_structure_key`` TEXT  — stable catalog key (e.g. 'hero_s_journey').
  * ``narrative_variant``       TEXT  — chosen Best-For audience (e.g. 'Adventure').
  * ``narrative_beats``         JSONB — ordered list of the chosen beat names.

Additive and fully reversible (drop the three columns). Existing projects are
untouched and read NULL.

Revision ID: 029
Revises: 028
Create Date: 2026-06-21
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "029"
down_revision = "028"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "projects",
        sa.Column("narrative_structure_key", sa.Text(), nullable=True),
    )
    op.add_column(
        "projects",
        sa.Column("narrative_variant", sa.Text(), nullable=True),
    )
    op.add_column(
        "projects",
        sa.Column(
            "narrative_beats",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    op.drop_column("projects", "narrative_beats")
    op.drop_column("projects", "narrative_variant")
    op.drop_column("projects", "narrative_structure_key")
