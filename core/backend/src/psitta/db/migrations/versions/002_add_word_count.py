"""002 — Add word_count to documents.

Revision ID: 002
Revises: 001
Create Date: 2026-02-28
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# Revision identifiers
revision: str = "002"
down_revision: str | None = "001"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    op.add_column(
        "documents",
        sa.Column("word_count", sa.Integer(), nullable=False, server_default="0"),
    )
    # drop default after existing rows get value
    op.alter_column("documents", "word_count", server_default=None)


def downgrade() -> None:
    op.drop_column("documents", "word_count")
