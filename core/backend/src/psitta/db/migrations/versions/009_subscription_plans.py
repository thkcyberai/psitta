"""009 subscription plans and user subscriptions

Revision ID: 009
Revises: 008
Create Date: 2026-03-13

Creates:
  - plan_id enum (free, pro_monthly, pro_annual)
  - subscription_status enum (active, cancelled, expired, trialing)
  - subscription_plans table  -- canonical plan definitions + limits
  - user_subscriptions table  -- per-user active subscription
  - Seed rows for the 3 plans
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB, ENUM

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "009"
down_revision = "008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. Enums ─────────────────────────────────────────────────────────────
    op.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_id') THEN
                CREATE TYPE plan_id AS ENUM ('free', 'pro_monthly', 'pro_annual');
            END IF;
        END $$
    """)
    op.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
                CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'expired', 'trialing');
            END IF;
        END $$
    """)

    # ── 2. subscription_plans ────────────────────────────────────────────────
    op.create_table(
        "subscription_plans",
        sa.Column("id", ENUM("free", "pro_monthly", "pro_annual", name="plan_id", create_type=False),
                  primary_key=True),
        sa.Column("display_name", sa.String(64), nullable=False),
        sa.Column("price_usd_cents", sa.Integer, nullable=False),          # 0 = free
        sa.Column("billing_interval", sa.String(16), nullable=True),       # monthly / annual / NULL
        sa.Column("docs_per_month", sa.Integer, nullable=False),           # -1 = unlimited
        sa.Column("max_doc_size_mb", sa.Integer, nullable=False),
        sa.Column("voices_tier", sa.String(16), nullable=False),           # edge_only / all
        sa.Column("audio_cache_days", sa.Integer, nullable=False),
        sa.Column("can_archive", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("limits_json", JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("NOW()")),
    )

    # ── 3. user_subscriptions ────────────────────────────────────────────────
    op.create_table(
        "user_subscriptions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("plan_id", ENUM("free", "pro_monthly", "pro_annual", name="plan_id", create_type=False),
                  nullable=False),
        sa.Column("status",
                  ENUM("active", "cancelled", "expired", "trialing",
                       name="subscription_status", create_type=False),
                  nullable=False, server_default=sa.text("'active'")),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("stripe_subscription_id", sa.String(128), nullable=True),   # wired in M3b
        sa.Column("stripe_customer_id", sa.String(128), nullable=True),        # wired in M3b
        sa.Column("metadata_json", JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("NOW()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("NOW()")),
    )

    op.create_index("ix_user_subscriptions_user_status",
                    "user_subscriptions", ["user_id", "status"])

    # ── 4. usage_counters (monthly doc count per user) ───────────────────────
    op.create_table(
        "usage_counters",
        sa.Column("id", UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False),
        sa.Column("year_month", sa.String(7), nullable=False),  # e.g. "2026-03"
        sa.Column("docs_uploaded", sa.Integer, nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False,
                  server_default=sa.text("NOW()")),
        sa.UniqueConstraint("user_id", "year_month", name="uq_usage_user_month"),
    )

    # ── 5. Seed plan rows ────────────────────────────────────────────────────
    op.execute("""
        INSERT INTO subscription_plans
            (id, display_name, price_usd_cents, billing_interval,
             docs_per_month, max_doc_size_mb, voices_tier,
             audio_cache_days, can_archive, limits_json)
        VALUES
            ('free',        'Free',         0,      NULL,
             3,  10, 'edge_only', 7,  false, '{}'),
            ('pro_monthly', 'Pro Monthly',  1200,   'monthly',
             50, 50, 'all',       90, true,  '{}'),
            ('pro_annual',  'Pro Annual',   9900,   'annual',
             50, 50, 'all',       90, true,  '{"annual_discount": true}')
    """)


def downgrade() -> None:
    op.drop_table("usage_counters")
    op.drop_table("user_subscriptions")
    op.drop_table("subscription_plans")
    op.execute("DROP TYPE IF EXISTS subscription_status")
    op.execute("DROP TYPE IF EXISTS plan_id")
