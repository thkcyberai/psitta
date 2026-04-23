"""014 Signup list table — homepage email capture.

Creates the ``signup_list`` table to receive email submissions from the
public signup form at https://psitta.ai/signup. Each entry is keyed by a
unique email address and tagged with the source (e.g. ``homepage_hero``)
so that future attribution analysis can distinguish signup channels.

Tables:
  - signup_list — one row per unique email

Status lifecycle (CHECK-constrained string):
  pending → confirmed (future double opt-in) → unsubscribed

Revision ID: 014
Revises: 013
Create Date: 2026-04-22
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "signup_list",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("first_name", sa.String(100), nullable=False),
        sa.Column(
            "source",
            sa.String(50),
            nullable=False,
            server_default=sa.text("'homepage_hero'"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("NOW()"),
        ),
        sa.Column(
            "status",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'pending'"),
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'confirmed', 'unsubscribed')",
            name="ck_signup_list_status",
        ),
    )
    op.create_index(
        "ix_signup_list_created_at",
        "signup_list",
        [sa.text("created_at DESC")],
    )


def downgrade() -> None:
    op.drop_index("ix_signup_list_created_at", table_name="signup_list")
    op.drop_table("signup_list")
