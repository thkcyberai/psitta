"""024 Widen plan_id enum for Writing Nook Pro and Creative Nook Pro.

Adds two new values to the existing plan_id PostgreSQL ENUM so that
set_plan_override and future Stripe webhook writes can persist
writing_nook_pro and creative_nook_pro without hitting a DB-level
"invalid input value for enum plan_id" error.

Background: migration 009 created plan_id AS ENUM ('free',
'pro_monthly', 'pro_annual'). The canonical plan vocabulary in
services/plan_limits.py grew to four tiers (adding reading_nook_pro,
writing_nook_pro, creative_nook_pro), but the ENUM was never widened.
pro_monthly and pro_annual are retained and remain valid — existing rows
are NOT touched. reading_nook_pro is NOT added here; the legacy alias
(pro_monthly / pro_annual → reading_nook_pro) handled via
_normalize_plan_id in plan_limits.py is sufficient for all existing
rows and is unchanged.

Revision ID: 024
Revises: 023
Create Date: 2026-06-11
"""

from __future__ import annotations

from alembic import op

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "024"
down_revision = "023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ALTER TYPE ... ADD VALUE cannot run inside the surrounding migration
    # transaction (env.py sets transaction_per_migration=True). Use
    # autocommit_block() to commit the open transaction, execute the DDL
    # in autocommit mode, then resume normal transactional flow.
    # IF NOT EXISTS makes the statement idempotent — safe to re-run.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE plan_id ADD VALUE IF NOT EXISTS 'writing_nook_pro'")
        op.execute("ALTER TYPE plan_id ADD VALUE IF NOT EXISTS 'creative_nook_pro'")


def downgrade() -> None:
    # Forward-only migration — PostgreSQL provides no DROP VALUE for enum
    # types. Reversing would require recreating the type and every dependent
    # column (user_subscriptions.plan_id, subscription_plans.id), which is
    # destructive. If a rollback is ever needed, treat it as a forward
    # migration that cleans up any rows using the added values before
    # recreating the type. This no-op is intentional.
    pass
