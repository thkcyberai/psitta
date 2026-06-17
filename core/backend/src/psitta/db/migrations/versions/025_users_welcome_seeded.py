"""025 Add users.welcome_seeded flag for one-time Writing Nook welcome kit.

Adds a single boolean column ``welcome_seeded`` (default FALSE) to the
``users`` table. It is the one-time claim marker for the Writing Nook
welcome-kit seeding routine: a writer's Library is seeded with the 6
starter documents exactly once, and a writer who later deletes those
documents is not re-seeded.

The column is additive and nullable-with-default, so the change is
backward compatible (existing rows read FALSE) and trivially reversible
by dropping the column.

Revision ID: 025
Revises: 024
Create Date: 2026-06-18
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "025"
down_revision = "024"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "welcome_seeded",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "welcome_seeded")
