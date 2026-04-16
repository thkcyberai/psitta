"""012 Stripe billing tables — M3 Phase B1

Creates the Stripe integration layer alongside the existing M3a
subscription tables (009). These tables map Stripe-side resources
to Psitta users and provide webhook event idempotency / forensics.

Tables:
  - stripe_customers — one-to-one link: users ↔ Stripe customer ID
  - subscriptions    — Stripe subscription lifecycle state
  - subscription_events — raw webhook payloads (append-only forensic trail)

Revision ID: 012
Revises: 011
Create Date: 2026-04-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "012"
down_revision = "011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. stripe_customers ─────────────────────────────────────────────────
    op.create_table(
        "stripe_customers",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("stripe_customer_id", sa.String(255), nullable=False, unique=True),
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
        "ix_stripe_customers_stripe_customer_id",
        "stripe_customers",
        ["stripe_customer_id"],
    )
    op.create_index(
        "ix_stripe_customers_user_id",
        "stripe_customers",
        ["user_id"],
    )

    # ── 2. subscriptions ────────────────────────────────────────────────────
    op.create_table(
        "subscriptions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "stripe_customer_id",
            UUID(as_uuid=True),
            sa.ForeignKey("stripe_customers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "stripe_subscription_id", sa.String(255), nullable=False, unique=True
        ),
        sa.Column("stripe_product_id", sa.String(255), nullable=False),
        sa.Column("stripe_price_id", sa.String(255), nullable=False),
        sa.Column("lookup_key", sa.String(100), nullable=False),
        sa.Column("status", sa.String(50), nullable=False),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "cancel_at_period_end",
            sa.Boolean,
            nullable=False,
            server_default=sa.text("false"),
        ),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
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
        "ix_subscriptions_stripe_subscription_id",
        "subscriptions",
        ["stripe_subscription_id"],
    )
    op.create_index(
        "ix_subscriptions_stripe_customer_id",
        "subscriptions",
        ["stripe_customer_id"],
    )
    op.create_index(
        "ix_subscriptions_status",
        "subscriptions",
        ["status"],
    )
    op.create_index(
        "ix_subscriptions_lookup_key",
        "subscriptions",
        ["lookup_key"],
    )

    # ── 3. subscription_events ──────────────────────────────────────────────
    op.create_table(
        "subscription_events",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "stripe_event_id", sa.String(255), nullable=False, unique=True
        ),
        sa.Column("event_type", sa.String(100), nullable=False),
        sa.Column("stripe_subscription_id", sa.String(255), nullable=True),
        sa.Column("payload", JSONB, nullable=False),
        sa.Column(
            "processed_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
    )
    op.create_index(
        "ix_subscription_events_stripe_event_id",
        "subscription_events",
        ["stripe_event_id"],
    )
    op.create_index(
        "ix_subscription_events_event_type",
        "subscription_events",
        ["event_type"],
    )
    op.create_index(
        "ix_subscription_events_stripe_subscription_id",
        "subscription_events",
        ["stripe_subscription_id"],
    )


def downgrade() -> None:
    # Reverse dependency order: events → subscriptions → customers
    op.drop_table("subscription_events")
    op.drop_table("subscriptions")
    op.drop_table("stripe_customers")
