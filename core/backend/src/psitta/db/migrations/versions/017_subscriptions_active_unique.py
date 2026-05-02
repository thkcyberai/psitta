"""017 Partial unique index on subscriptions(stripe_customer_id) WHERE status='active'.

Last-line defense against duplicate active subscriptions for one Stripe
customer. The /billing/checkout-session endpoint queries Stripe directly
before creating a session (billing.py:4b), but if that check is bypassed
(network blip, future code path, race), this index makes the duplicate
INSERT in handle_checkout_session_completed fail loudly with
IntegrityError instead of silently allowing two parallel charges.

Background: production incident May 2 2026 — test3 customer ended up
with two active Reading Nook Pro subs (monthly + annual) because the
local-DB duplicate check at billing.py step 2 races against webhook
arrival.

The upgrade() refuses to run if any (stripe_customer_id) currently has
more than one status='active' row. Cleanup must happen in Stripe first
(cancel the duplicate, let the webhook flip status to 'canceled'), then
this migration can be re-applied.

Revision ID: 017
Revises: 016
Create Date: 2026-05-02
"""

from __future__ import annotations

from alembic import op


# ── Revision identifiers ────────────────────────────────────────────────────
revision = "017"
down_revision = "016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Pre-flight guard: refuse to create the index if duplicates exist,
    # because the index creation itself would fail with a less actionable
    # error message ("could not create unique index ..."). This raises
    # before the index attempt with the offending stripe_customer_ids
    # listed so the operator knows exactly what to clean up in Stripe.
    conn = op.get_bind()
    duplicates = conn.exec_driver_sql(
        "SELECT stripe_customer_id, COUNT(*) AS active_count "
        "FROM subscriptions "
        "WHERE status = 'active' "
        "GROUP BY stripe_customer_id "
        "HAVING COUNT(*) > 1"
    ).fetchall()
    if duplicates:
        offenders = ", ".join(
            f"{row[0]} ({row[1]} active rows)" for row in duplicates
        )
        raise RuntimeError(
            "Cannot create uq_subscriptions_one_active_per_customer: "
            "existing duplicate active subscriptions found. Cancel the "
            "duplicates in Stripe and let the webhook flip status to "
            f"'canceled' before re-running this migration. Offenders: {offenders}"
        )

    op.create_index(
        "uq_subscriptions_one_active_per_customer",
        "subscriptions",
        ["stripe_customer_id"],
        unique=True,
        postgresql_where="status = 'active'",
    )


def downgrade() -> None:
    op.drop_index(
        "uq_subscriptions_one_active_per_customer",
        table_name="subscriptions",
    )
