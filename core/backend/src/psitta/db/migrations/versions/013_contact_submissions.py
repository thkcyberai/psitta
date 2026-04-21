"""013 Contact submissions table — M8b.2 website contact form.

Creates the ``contact_submissions`` table to receive messages from the
public contact form at https://psitta.ai/contact. Submissions are stored
for the founder to review; no notification or email-send pipeline yet.

Tables:
  - contact_submissions — one row per form submission

Status lifecycle (string, not enum, for operator flexibility):
  new → read → replied → archived

Revision ID: 013
Revises: 012
Create Date: 2026-04-21
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

# ── Revision identifiers ────────────────────────────────────────────────────
revision = "013"
down_revision = "012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "contact_submissions",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("first_name", sa.String(100), nullable=False),
        sa.Column("last_name", sa.String(100), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("phone", sa.String(30), nullable=True),
        sa.Column("message", sa.Text, nullable=False),
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
            server_default=sa.text("'new'"),
        ),
    )
    op.create_index(
        "ix_contact_submissions_status",
        "contact_submissions",
        ["status"],
    )
    op.create_index(
        "ix_contact_submissions_created_at",
        "contact_submissions",
        [sa.text("created_at DESC")],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_contact_submissions_created_at", table_name="contact_submissions"
    )
    op.drop_index("ix_contact_submissions_status", table_name="contact_submissions")
    op.drop_table("contact_submissions")
