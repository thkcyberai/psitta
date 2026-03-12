"""
007 — Add auth0_user_id to users table.

Adds auth0_user_id column for storing the Auth0 subject identifier
(e.g., "auth0|abc123"). This enables direct Auth0 <-> user mapping
for JWT-based authentication.

The existing external_id column is preserved for backward compatibility
and may be used for other external identity providers.

Revision ID: 007
Revises: 006
Create Date: 2026-03-12
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# Revision identifiers
revision: str = "007"
down_revision: str = "006"
branch_labels: str | None = None
depends_on: str | None = None


def upgrade() -> None:
    """Add auth0_user_id column to users table."""
    op.add_column(
        "users",
        sa.Column("auth0_user_id", sa.String(255), unique=True, nullable=True),
    )
    op.create_index("ix_users_auth0_user_id", "users", ["auth0_user_id"])


def downgrade() -> None:
    """Remove auth0_user_id column from users table."""
    op.drop_index("ix_users_auth0_user_id", table_name="users")
    op.drop_column("users", "auth0_user_id")
