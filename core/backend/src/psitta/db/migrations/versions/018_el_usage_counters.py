"""018 EL usage counters per billing period.

Tracks ElevenLabs character consumption per user per billing-anniversary
period. Distinct from usage_counters (calendar-month docs counter)
because EL char limits should reset on the user's actual billing
anniversary, not on month rollover -- this matters for annual
subscribers whose period straddles many calendar months.

Counter is incremented from the TTS router after every successful
ElevenLabs call (C.2 follow-up commit). Per-user pre-call check reads
this table; when chars_consumed >= plan limit, the router degrades to
Edge silently rather than 402-ing the request.

The (user_id, period_start) unique constraint ensures one counter row
per user per billing period; period_start is sourced from
subscriptions.current_period_start (Stripe Basil API items[0]) at the
moment the row is first inserted.

Revision ID: 018
Revises: 017
Create Date: 2026-05-02
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "el_usage_counters",
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
            "chars_consumed",
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
            "user_id", "period_start", name="uq_el_usage_user_period"
        ),
    )
    op.create_index(
        "ix_el_usage_counters_user_id",
        "el_usage_counters",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_el_usage_counters_user_id", table_name="el_usage_counters"
    )
    op.drop_table("el_usage_counters")
