"""016 Drop NOT NULL on signup_list.first_name — Phase F waitlist.

Allows the new /api/v1/waitlist/creativity-nook endpoint to record an
email-only entry without inventing a placeholder first_name. Existing
homepage_hero rows continue to populate first_name normally; new
creativity_nook_waitlist rows store NULL.

Revision ID: 016
Revises: 015
Create Date: 2026-04-30
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "signup_list",
        "first_name",
        existing_type=sa.String(100),
        nullable=True,
    )


def downgrade() -> None:
    # Backfill NULLs to '' before re-applying NOT NULL so the rollback does
    # not fail on rows inserted by the waitlist endpoint.
    op.execute(
        "UPDATE signup_list SET first_name = '' WHERE first_name IS NULL"
    )
    op.alter_column(
        "signup_list",
        "first_name",
        existing_type=sa.String(100),
        nullable=False,
    )
