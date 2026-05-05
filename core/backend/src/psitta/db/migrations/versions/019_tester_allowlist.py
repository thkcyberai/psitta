"""019 Tester allowlist (Item 11 — Pattern 3).

Backend-only allowlist that grants Reading Nook Pro entitlement to
opted-in alpha testers WITHOUT creating a Stripe customer/subscription.
Distinct from:
  * subscriptions       — Stripe webhook-managed paying customers
  * user_subscriptions  — dev/admin override (set_plan_override)

Lookup is by lowercased email (no FK to users.email — testers may be
added before they sign up). The resolver introduced in T11.2 unions
all three tables; if an active allowlist row exists for the
authenticated user's email, the user is treated as Reading Nook Pro
with current_period_end = expires_at and source="tester_allowlist".

revoked_at is a soft-revoke marker (NULL = active). expires_at is
required so every grant has an automatic sunset; default 30 days
applied at the service layer, not in the schema.

Revision ID: 019
Revises: 018
Create Date: 2026-05-05
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "019"
down_revision = "018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tester_allowlist",
        sa.Column("email", sa.String(320), primary_key=True),
        sa.Column(
            "plan_id",
            sa.String(64),
            nullable=False,
            server_default="reading_nook_pro",
        ),
        sa.Column(
            "granted_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("granted_by", sa.String(255), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )
    op.create_index(
        "ix_tester_allowlist_expires_at",
        "tester_allowlist",
        ["expires_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_tester_allowlist_expires_at", table_name="tester_allowlist"
    )
    op.drop_table("tester_allowlist")
