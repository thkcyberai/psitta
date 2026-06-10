"""023 LLM token usage counters per billing period.

Tracks LLM token consumption per user per billing-anniversary period.
Mirrors el_usage_counters (migration 018) exactly in structure.

The (user_id, period_start) unique constraint ensures one counter row
per user per billing period; period_start is sourced from
subscriptions.current_period_start (Stripe Basil API items[0]) at the
moment the row is first inserted, matching the EL counter convention.

Counter is incremented from the LLM call path after every successful
completion (Summarize-it WD-B1 and future Writing/Creative tier LLM
features). Per-user pre-call check reads this table; when
tokens_consumed >= plan limit, the caller hard-stops with a clear
notice rather than silently degrading (different behavior from EL,
which silently falls back to Edge).

Writing Nook Pro:   1,000,000 tokens/period
Creative Nook Pro:  2,000,000 tokens/period
Free / Reading Nook: 0 (no LLM access)

Revision ID: 023
Revises: 022
Create Date: 2026-06-10
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "023"
down_revision = "022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "llm_usage_counters",
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
        ),
        sa.Column("period_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "tokens_consumed",
            sa.BigInteger,
            nullable=False,
            server_default="0",
        ),
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
        sa.UniqueConstraint(
            "user_id", "period_start", name="uq_llm_usage_user_period"
        ),
    )
    op.create_index(
        "ix_llm_usage_counters_user_id",
        "llm_usage_counters",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_llm_usage_counters_user_id", table_name="llm_usage_counters"
    )
    op.drop_table("llm_usage_counters")
