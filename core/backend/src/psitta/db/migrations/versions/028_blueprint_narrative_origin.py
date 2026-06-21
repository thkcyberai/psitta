"""028 Record a blueprint's narrative origin.

When a writer builds a Book Structure from the Narrative Structure tab, the
chosen story framework and audience variant are now remembered on the blueprint
itself — its "narrative DNA". This is what later lets the Writing Desk and the
AI know which beat a section is meant to be, to coach against deviation.

Columns added to ``blueprints``:
  * ``narrative_structure_key`` — stable catalog key of the chosen structure
        (e.g. 'heros_journey'). NULL for blueprints not built from a narrative.
  * ``narrative_variant``       — the chosen Best-For audience (e.g. 'Adventure').
        NULL when absent.

No CHECK constraint: the catalog of structures/variants lives in the app and
grows over time; pinning it in the database would force a migration per new
structure. Length/shape is validated at the API schema instead.

Both columns are nullable and additive — existing blueprints are untouched and
behave exactly as before (the fields simply read NULL). Fully reversible by
dropping the two columns.

Revision ID: 028
Revises: 027
Create Date: 2026-06-21
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "028"
down_revision = "027"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "blueprints",
        sa.Column("narrative_structure_key", sa.Text(), nullable=True),
    )
    op.add_column(
        "blueprints",
        sa.Column("narrative_variant", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("blueprints", "narrative_variant")
    op.drop_column("blueprints", "narrative_structure_key")
