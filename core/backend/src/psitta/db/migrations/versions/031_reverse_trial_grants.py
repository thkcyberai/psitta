"""031 Reverse-trial grants (GTM Phase 1).

Time-boxed Writing Nook grant created on genuine new-user signup. A
writer resolves to ``writing_nook_pro`` until ``expires_at`` passes,
then falls through to Free automatically — expiry is LAZY (filtered at
read time in ``get_effective_plan``), exactly like ``tester_allowlist``,
so no scheduler/cron is required.

Distinct from:
  * subscriptions       — Stripe webhook-managed paying customers
  * user_subscriptions  — dev/admin override (set_plan_override)
  * tester_allowlist    — internal alpha testers (by email)

Keyed by user_id (one grant per user). ``ON CONFLICT (user_id) DO
NOTHING`` at the service layer makes the grant fire exactly once, so a
writer can't reset their trial by signing in again. ``revoked_at`` is a
soft-revoke marker (NULL = active). ``activated_at`` is set on the
writer's first real Writing Nook action (Phase 2 — the ``activated``
Loops event); nullable and unused in Phase 1.

Additive and fully reversible: dropping the table restores prior
behaviour (no user has a grant → resolver falls straight to Free).

Revision ID: 031
Revises: 030
Create Date: 2026-07-13
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "031"
down_revision = "030"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trial_grants",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "plan_id",
            sa.String(64),
            nullable=False,
            server_default="writing_nook_pro",
        ),
        sa.Column(
            "granted_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "source",
            sa.String(64),
            nullable=False,
            server_default="signup",
        ),
        sa.Column("activated_at", sa.DateTime(timezone=True), nullable=True),
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
        "ix_trial_grants_expires_at",
        "trial_grants",
        ["expires_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_trial_grants_expires_at", table_name="trial_grants")
    op.drop_table("trial_grants")
