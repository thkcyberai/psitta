"""026 Add avatar_url and quote to users for the Profile space.

Adds two nullable columns to ``users``:
  * ``avatar_url``  — the S3 storage key of the writer's uploaded photo
                      (e.g. ``avatars/<user_id>.jpg``), NULL when none.
  * ``quote``       — the writer's short quote/message shown under the photo.

Both are additive and nullable, so the change is backward compatible (existing
rows read NULL) and trivially reversible by dropping the columns.

Revision ID: 026
Revises: 025
Create Date: 2026-06-18
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "026"
down_revision = "025"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users", sa.Column("avatar_url", sa.String(length=1024), nullable=True)
    )
    op.add_column("users", sa.Column("quote", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "quote")
    op.drop_column("users", "avatar_url")
