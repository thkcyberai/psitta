"""032 app_config — remote control-plane key/value store.

The single source of truth for server-owned CLIENT configuration that must be
changeable WITHOUT a client release or a backend redeploy:

  * minimum_supported_version — the force-update floor; clients below it must
    upgrade before continuing.
  * recommended_version       — soft-nudge target for an optional update.
  * flags                     — feature flags / kill switches the client reads
    to enable, disable, or remotely kill a feature in an incident.

Stored as one row per logical config document (key -> jsonb value) so the shape
can evolve without a schema change. The API (GET /config) reads it fail-safe:
if this table is absent (code deployed before this migration) or a row is
malformed, the endpoint returns permissive defaults so a config fault can never
lock users out. Additive and fully reversible — dropping the table restores the
prior behaviour (endpoint serves defaults).

Revision ID: 032
Revises: 031
Create Date: 2026-07-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "032"
down_revision = "031"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "app_config",
        sa.Column("key", sa.String(64), primary_key=True),
        sa.Column(
            "value",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )


def downgrade() -> None:
    op.drop_table("app_config")
