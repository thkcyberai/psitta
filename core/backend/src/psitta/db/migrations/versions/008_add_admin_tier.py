"""
008 — Add 'admin' to user_tier enum.

Extends the user_tier PostgreSQL enum to include 'admin' role,
enabling role-based access control for administrative users.

Revision ID: 008
Revises: 007
Create Date: 2026-03-12
"""

from __future__ import annotations

from alembic import op

# Revision identifiers
revision: str = "008"
down_revision: str = "007"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    """Add 'admin' value to user_tier enum."""
    # PostgreSQL ALTER TYPE ... ADD VALUE is not transactional,
    # so we must execute outside a transaction block.
    op.execute("ALTER TYPE user_tier ADD VALUE IF NOT EXISTS 'admin'")


def downgrade() -> None:
    """Cannot remove enum values in PostgreSQL — recreate would be needed.

    This is intentionally left as a no-op because removing enum values
    requires recreating the type and all dependent columns.
    """
    pass
