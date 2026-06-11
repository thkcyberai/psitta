"""services/billing_handlers.py — Stripe webhook event handlers (M3 Phase B3).

Each handler processes one Stripe event type and updates subscription
state in the database. Handlers are called from the webhook endpoint
in api/v1/billing.py.

Contract:
  - Handlers receive a raw Stripe event dict and an AsyncSession.
  - Each handler is a single DB transaction (caller manages commit/rollback).
  - Handlers raise on unrecoverable errors; the webhook endpoint catches
    and returns 200 regardless (Stripe retries on non-2xx).
  - All state changes are audit-logged for SOC 2 compliance.
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from typing import Any

import stripe
import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import get_settings
from psitta.db.session import async_session_factory
from psitta.services import audit_service
from psitta.services.plan_limits import _normalize_plan_id, get_plan_limits

# Stripe SDK API version: Basil (March 2025) — period fields on items, not subscription root.

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── lookup_key / status mappers ──────────────────────────────────────────

# Map Stripe lookup_keys onto the M3a quota plan_ids used by
# user_subscriptions.plan_id (ENUM: free|pro_monthly|pro_annual).
# Both reading_nook_pro and creative_nook_pro collapse onto the same
# pro_* tier because PLAN_LIMITS in subscription_service.py applies
# identical quotas to both products. Keys MUST track every value in
# billing.py's VALID_LOOKUP_KEYS allowlist -- adding a new lookup_key
# without updating this dict would silently downgrade paying customers
# to 'free' (or skip the user_subscriptions write entirely). The
# Stripe-side legacy "creativity_nook_pro_*" prefix is preserved because
# that's what the Stripe Dashboard ships; see _PLAN_NAME_ALIASES in
# api/v1/billing.py for the corresponding read-side mapping.
_LOOKUP_KEY_TO_PLAN_ID: dict[str, str] = {
    # Reading Nook Pro — legacy ENUM values; ENUM widening (migration 024)
    # intentionally does NOT add reading_nook_pro because the alias
    # pro_monthly / pro_annual → reading_nook_pro in plan_limits.py is
    # sufficient for all resolution paths (read side) and the Stripe
    # subscription_events table preserves the original lookup_key.
    "reading_nook_pro_monthly": "pro_monthly",
    "reading_nook_pro_annual": "pro_annual",
    # Creative Nook Pro — Stripe-side "creativity_" prefix is intentional
    # (matches the Stripe Dashboard price lookup_keys, see VALID_LOOKUP_KEYS
    # and _PLAN_NAME_ALIASES). Now writes the canonical ENUM value added by
    # migration 024 instead of the legacy pro_monthly / pro_annual fallback.
    "creativity_nook_pro_monthly": "creative_nook_pro",
    "creativity_nook_pro_annual": "creative_nook_pro",
    # Writing Nook Pro — future Stripe product; entries pre-registered so
    # the webhook handler writes the correct ENUM value when the product
    # launches on the Stripe Dashboard.
    "writing_nook_pro_monthly": "writing_nook_pro",
    "writing_nook_pro_annual": "writing_nook_pro",
}


def _lookup_key_to_plan_id(lookup_key: str) -> str | None:
    """Map a Stripe lookup_key to a user_subscriptions.plan_id ENUM value.

    Returns None for unrecognized keys so callers can fail-open (log
    a warning, skip the user_subscriptions write) rather than write
    'free' and downgrade a paying customer.
    """
    return _LOOKUP_KEY_TO_PLAN_ID.get(lookup_key)


# Map Stripe subscription status to user_subscriptions.status ENUM
# (subscription_status: active|cancelled|expired|trialing).
#
# Two deliberate choices encoded here:
#   * past_due maps to 'active' on purpose. Stripe retries payment for
#     3-21 days; the customer is still entitled during that grace
#     period. The actual downgrade fires when Stripe sends
#     customer.subscription.deleted at the end of the retry window.
#   * incomplete / incomplete_expired / unpaid map to 'cancelled' so
#     never-paid sessions don't leave a 'pending' row that the quota
#     enforcer reads as Pro.
#
# Note the spelling drift: the subscriptions table (M3 B1, migration
# 012) uses 'canceled' (American), the user_subscriptions ENUM (M3a,
# migration 009) uses 'cancelled' (British). Writing 'canceled' to
# user_subscriptions trips the ENUM check.
_STRIPE_STATUS_TO_US_STATUS: dict[str, str] = {
    "active": "active",
    "trialing": "trialing",
    "past_due": "active",
    "canceled": "cancelled",
    "incomplete": "cancelled",
    "incomplete_expired": "cancelled",
    "unpaid": "cancelled",
}


def _stripe_status_to_us_status(stripe_status: str) -> str | None:
    """Map a Stripe subscription status to user_subscriptions.status.

    Returns None for unrecognized future Stripe statuses so callers
    can fail-open rather than risk downgrading a paying customer
    because of an enum drift on Stripe's side.
    """
    return _STRIPE_STATUS_TO_US_STATUS.get(stripe_status)


# ── checkout.session.completed ───────────────────────────────────────────

async def handle_checkout_session_completed(
    event: dict,
    db: AsyncSession,
) -> None:
    """Process a completed Checkout session — create the subscription record.

    Retrieves the full Stripe Subscription object to get price details,
    then inserts a row into the subscriptions table linked to the
    stripe_customers record.
    """
    session = event["data"]["object"]
    stripe_customer_id_str = session["customer"]
    stripe_subscription_id = session["subscription"]
    metadata = session.get("metadata", {})
    user_id = metadata.get("psitta_user_id")
    lookup_key = metadata.get("lookup_key", "")

    # Look up our internal stripe_customers row
    row = await db.execute(
        text(
            "SELECT id FROM stripe_customers "
            "WHERE stripe_customer_id = :sc_id"
        ),
        {"sc_id": stripe_customer_id_str},
    )
    sc_row = row.fetchone()
    if not sc_row:
        logger.warning(
            "billing.handler.no_stripe_customer",
            stripe_customer_id=stripe_customer_id_str,
            event_id=event["id"],
        )
        return

    internal_sc_id = sc_row[0]

    # Retrieve subscription from Stripe for price details. The returned
    # StripeObject is converted to a plain dict tree so nested .get()
    # calls (e.g. price.get("lookup_key")) don't trip __getattr__.
    settings = get_settings()
    stripe.api_key = settings.STRIPE_SECRET_KEY_TEST.get_secret_value()

    sub = stripe_obj_to_dict(stripe.Subscription.retrieve(stripe_subscription_id))
    item = sub["items"]["data"][0]
    price = item["price"]

    resolved_lookup_key = lookup_key or price.get("lookup_key", "")

    # Stripe Basil API (March 2025) moved period fields from subscription
    # root to subscription item. Schema assumes single-item subscription,
    # which is true for Psitta v1.
    period_start = _ts_to_dt(item.get("current_period_start"))
    period_end = _ts_to_dt(item.get("current_period_end"))

    await db.execute(
        text(
            "INSERT INTO subscriptions "
            "(stripe_customer_id, stripe_subscription_id, stripe_product_id, "
            " stripe_price_id, lookup_key, status, "
            " current_period_start, current_period_end, "
            " cancel_at_period_end) "
            "VALUES "
            "(:sc_id, :sub_id, :product_id, :price_id, :lookup_key, "
            " :status, :period_start, :period_end, :cancel_at_period_end) "
            "ON CONFLICT (stripe_subscription_id) DO NOTHING"
        ),
        {
            "sc_id": internal_sc_id,
            "sub_id": stripe_subscription_id,
            "product_id": str(price.get("product", "")),
            "price_id": price["id"],
            "lookup_key": resolved_lookup_key,
            "status": sub["status"],
            "period_start": period_start,
            "period_end": period_end,
            "cancel_at_period_end": sub.get(
                "cancel_at_period_end", False
            ),
        },
    )

    # Mirror the new subscription into user_subscriptions so the quota
    # enforcer (subscription_service._get_active_plan_id) recognises
    # the customer as Pro. Same DB session as the subscriptions INSERT
    # above -- atomicity is preserved by the request transaction.
    # Background: CLAUDE.md Key Learning 2026-04-23 (dual-table tech
    # debt). The full consolidation is M9; this commit is the
    # surgical fix that unblocks paying customers.
    plan_id_value = _lookup_key_to_plan_id(resolved_lookup_key)
    if plan_id_value is None:
        logger.warning(
            "billing.handler.unknown_lookup_key",
            lookup_key=resolved_lookup_key,
            event_id=event["id"],
            stripe_subscription_id=stripe_subscription_id,
        )
    elif user_id is None:
        # Stripe metadata.psitta_user_id should always be present (set
        # at Checkout Session creation in api/v1/billing.py:215-218),
        # but treat its absence as an observable warning rather than
        # a crash so a single misconfigured event doesn't poison the
        # request transaction.
        logger.warning(
            "billing.handler.no_psitta_user_id",
            event_id=event["id"],
            stripe_subscription_id=stripe_subscription_id,
        )
    else:
        # Cancel any prior active row -- one user, one active sub at
        # a time. Mirrors subscription_service.set_plan_override's
        # established pattern (subscription_service.py:217-225).
        await db.execute(
            text(
                "UPDATE user_subscriptions SET "
                "  status = 'cancelled', "
                "  cancelled_at = NOW(), "
                "  updated_at = NOW() "
                "WHERE user_id = :uid AND status = 'active'"
            ),
            {"uid": user_id},
        )
        await db.execute(
            text(
                "INSERT INTO user_subscriptions "
                "(user_id, plan_id, status, started_at, "
                " current_period_start, current_period_end, "
                " stripe_subscription_id, stripe_customer_id) "
                "VALUES "
                "(:uid, :plan_id, 'active', NOW(), "
                " :period_start, :period_end, "
                " :stripe_sub_id, :stripe_customer_id)"
            ),
            {
                "uid": user_id,
                "plan_id": plan_id_value,
                "period_start": period_start,
                "period_end": period_end,
                "stripe_sub_id": stripe_subscription_id,
                "stripe_customer_id": stripe_customer_id_str,
            },
        )
        logger.info(
            "user_subscription.upserted",
            user_id=user_id,
            plan_id=plan_id_value,
            status="active",
            stripe_subscription_id=stripe_subscription_id,
        )

    # resource_id stores the Psitta user UUID (audit_log.resource_id is
    # a UUID column). The Stripe identifiers are kept in details_json so
    # the SOC 2 trail still ties the audit row to the Stripe records.
    await audit_service.log_event(
        db,
        action="billing.subscription_created",
        resource_type="subscription",
        user_id=user_id,
        resource_id=user_id,
        details={
            "stripe_subscription_id": stripe_subscription_id,
            "stripe_customer_id": stripe_customer_id_str,
            "lookup_key": resolved_lookup_key,
            "status": sub["status"],
        },
    )

    logger.info(
        "billing.subscription_created",
        stripe_subscription_id=stripe_subscription_id,
        lookup_key=resolved_lookup_key,
        status=sub["status"],
    )


# ── customer.subscription.updated ────────────────────────────────────────

async def handle_subscription_updated(
    event: dict,
    db: AsyncSession,
) -> None:
    """Process a subscription update — renewals, plan changes, cancel scheduling.

    Updates the local subscription row to mirror Stripe state.
    """
    sub_obj = event["data"]["object"]
    stripe_sub_id = sub_obj["id"]
    new_status = sub_obj["status"]

    # Find existing local subscription. The JOIN pulls the Psitta user
    # UUID for the audit_log row — Stripe webhooks don't carry it on
    # subscription updates, so we resolve it through stripe_customers.
    # current_period_start is fetched so the C.3 rotation block can
    # detect a renewal (old period_start != new period_start).
    row = await db.execute(
        text(
            "SELECT s.id, s.status, s.current_period_start, sc.user_id "
            "FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE s.stripe_subscription_id = :sub_id"
        ),
        {"sub_id": stripe_sub_id},
    )
    existing = row.mappings().first()
    if not existing:
        logger.warning(
            "billing.handler.subscription_not_found",
            stripe_subscription_id=stripe_sub_id,
            event_id=event["id"],
        )
        return

    previous_status = existing["status"]
    previous_period_start = existing["current_period_start"]
    psitta_user_id = str(existing["user_id"])
    item = sub_obj["items"]["data"][0]
    price = item["price"]
    lookup_key = price.get("lookup_key", "")

    canceled_at = _ts_to_dt(sub_obj.get("canceled_at"))
    # Stripe Basil API (March 2025) moved period fields from subscription
    # root to subscription item. Schema assumes single-item subscription,
    # which is true for Psitta v1.
    period_start = _ts_to_dt(item.get("current_period_start"))
    period_end = _ts_to_dt(item.get("current_period_end"))
    now = datetime.now(UTC)

    await db.execute(
        text(
            "UPDATE subscriptions SET "
            "  status = :status, "
            "  stripe_product_id = :product_id, "
            "  stripe_price_id = :price_id, "
            "  lookup_key = :lookup_key, "
            "  current_period_start = :period_start, "
            "  current_period_end = :period_end, "
            "  cancel_at_period_end = :cancel_at_period_end, "
            "  canceled_at = :canceled_at, "
            "  updated_at = :now "
            "WHERE stripe_subscription_id = :sub_id"
        ),
        {
            "status": new_status,
            "product_id": str(price.get("product", "")),
            "price_id": price["id"],
            "lookup_key": lookup_key,
            "period_start": period_start,
            "period_end": period_end,
            "cancel_at_period_end": sub_obj.get(
                "cancel_at_period_end", False
            ),
            "canceled_at": canceled_at,
            "now": now,
            "sub_id": stripe_sub_id,
        },
    )

    # Mirror to user_subscriptions for the quota enforcer. Fail-open
    # on unrecognized Stripe statuses (log warning, leave row
    # untouched) so a future Stripe enum value doesn't downgrade a
    # paying customer. plan_id is only updated when the lookup_key
    # resolves cleanly -- otherwise we'd risk overwriting a valid
    # plan_id with the legacy 'free' default.
    new_us_status = _stripe_status_to_us_status(new_status)
    new_plan_id = _lookup_key_to_plan_id(lookup_key)
    if new_us_status is None:
        logger.warning(
            "billing.handler.unknown_stripe_status",
            stripe_subscription_id=stripe_sub_id,
            stripe_status=new_status,
            event_id=event["id"],
        )
    else:
        params = {
            "status": new_us_status,
            "period_start": period_start,
            "period_end": period_end,
            "cancelled_at": canceled_at,
            "now": now,
            "sub_id": stripe_sub_id,
        }
        plan_clause = ""
        if new_plan_id is not None:
            plan_clause = "  plan_id = :plan_id, "
            params["plan_id"] = new_plan_id

        await db.execute(
            text(
                "UPDATE user_subscriptions SET "
                "  status = :status, "
                + plan_clause
                + "  current_period_start = :period_start, "
                "  current_period_end = :period_end, "
                "  cancelled_at = :cancelled_at, "
                "  updated_at = :now "
                "WHERE stripe_subscription_id = :sub_id"
            ),
            params,
        )
        logger.info(
            "user_subscription.upserted",
            user_id=psitta_user_id,
            plan_id=new_plan_id,
            status=new_us_status,
            stripe_subscription_id=stripe_sub_id,
        )

    # ── EL quota period rotation (C.3) ──────────────────────────────────
    # The (user_id, period_start) compound key in el_usage_counters means
    # the new period naturally starts at zero — check_el_quota reads
    # against the current period_start and either finds the new row at 0
    # or finds no row and returns 0. The eager INSERT here makes the
    # rotation observable in the table for forensic / SQL audit purposes.
    #
    # Wrapped in try/except so a rotation-block failure can never block
    # the webhook ack — Stripe will retry for 3 days on non-200, and the
    # subscription update itself is the load-bearing work above.
    #
    # v1.1 fix queued: _lookup_key_to_plan_id collapses both Reading Nook
    # Pro and Creative Nook Pro lookup_keys onto pro_monthly/pro_annual,
    # which _normalize_plan_id then maps to reading_nook_pro. C-Pro
    # subscribers get the R-Pro 150k EL limit until the ENUM
    # differentiation is fixed. lookup_key is logged here so the audit
    # trail preserves the real source-of-truth.
    if (
        previous_period_start is not None
        and period_start is not None
        and previous_period_start != period_start
        and new_status == "active"
    ):
        try:
            canonical_plan_id = _normalize_plan_id(new_plan_id or "")
            new_chars_limit = get_plan_limits(canonical_plan_id).el_chars_per_period
            await db.execute(
                text(
                    "INSERT INTO el_usage_counters "
                    "(user_id, period_start, chars_consumed, created_at, updated_at) "
                    "VALUES (:uid, :ps, 0, NOW(), NOW()) "
                    "ON CONFLICT (user_id, period_start) DO NOTHING"
                ),
                {"uid": psitta_user_id, "ps": period_start},
            )
            logger.info(
                "billing.el_period_rotated",
                user_id=psitta_user_id,
                plan=canonical_plan_id,
                lookup_key=lookup_key,
                previous_period_start=previous_period_start.isoformat(),
                new_period_start=period_start.isoformat(),
                chars_limit=new_chars_limit,
            )
            await audit_service.log_event(
                db,
                action="billing.el_period_rotated",
                resource_type="subscription",
                user_id=psitta_user_id,
                resource_id=psitta_user_id,
                details={
                    "stripe_subscription_id": stripe_sub_id,
                    "plan": canonical_plan_id,
                    "lookup_key": lookup_key,
                    "previous_period_start": previous_period_start.isoformat(),
                    "new_period_start": period_start.isoformat(),
                    "chars_limit": new_chars_limit,
                },
            )
        except Exception as e:
            logger.warning(
                "billing.el_period_rotation_failed",
                user_id=psitta_user_id,
                stripe_subscription_id=stripe_sub_id,
                error=str(e),
            )

    await audit_service.log_event(
        db,
        action="billing.subscription_updated",
        resource_type="subscription",
        user_id=psitta_user_id,
        resource_id=psitta_user_id,
        details={
            "stripe_subscription_id": stripe_sub_id,
            "previous_status": previous_status,
            "new_status": new_status,
            "lookup_key": lookup_key,
        },
    )

    logger.info(
        "billing.subscription_updated",
        stripe_subscription_id=stripe_sub_id,
        previous_status=previous_status,
        new_status=new_status,
    )


# ── customer.subscription.deleted ────────────────────────────────────────

async def handle_subscription_deleted(
    event: dict,
    db: AsyncSession,
) -> None:
    """Process a subscription deletion — mark as canceled."""
    sub_obj = event["data"]["object"]
    stripe_sub_id = sub_obj["id"]
    now = datetime.now(UTC)

    # JOIN to fetch the Psitta user UUID for the audit_log row.
    row = await db.execute(
        text(
            "SELECT s.id, sc.user_id "
            "FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE s.stripe_subscription_id = :sub_id"
        ),
        {"sub_id": stripe_sub_id},
    )
    existing = row.mappings().first()
    if not existing:
        logger.warning(
            "billing.handler.subscription_not_found",
            stripe_subscription_id=stripe_sub_id,
            event_id=event["id"],
        )
        return

    psitta_user_id = str(existing["user_id"])

    await db.execute(
        text(
            "UPDATE subscriptions SET "
            "  status = 'canceled', "
            "  canceled_at = :now, "
            "  updated_at = :now "
            "WHERE stripe_subscription_id = :sub_id"
        ),
        {"now": now, "sub_id": stripe_sub_id},
    )

    # Mirror cancellation to user_subscriptions for the quota enforcer.
    # Note the spelling drift -- subscriptions uses 'canceled'
    # (American), the user_subscriptions ENUM uses 'cancelled' (British,
    # see migration 009).
    await db.execute(
        text(
            "UPDATE user_subscriptions SET "
            "  status = 'cancelled', "
            "  cancelled_at = :now, "
            "  updated_at = :now "
            "WHERE stripe_subscription_id = :sub_id"
        ),
        {"now": now, "sub_id": stripe_sub_id},
    )
    logger.info(
        "user_subscription.upserted",
        user_id=psitta_user_id,
        status="cancelled",
        stripe_subscription_id=stripe_sub_id,
    )

    await audit_service.log_event(
        db,
        action="billing.subscription_canceled",
        resource_type="subscription",
        user_id=psitta_user_id,
        resource_id=psitta_user_id,
        details={
            "stripe_subscription_id": stripe_sub_id,
            "status": "canceled",
        },
    )

    logger.info(
        "billing.subscription_canceled",
        stripe_subscription_id=stripe_sub_id,
    )


# ── invoice.payment_failed ───────────────────────────────────────────────

async def handle_payment_failed(
    event: dict,
    db: AsyncSession,
) -> None:
    """Process a failed invoice payment — mark subscription as past_due."""
    invoice = event["data"]["object"]
    stripe_sub_id = invoice.get("subscription")
    invoice_id = invoice.get("id", "")

    if not stripe_sub_id:
        logger.info(
            "billing.handler.payment_failed_no_subscription",
            invoice_id=invoice_id,
        )
        return

    now = datetime.now(UTC)

    # JOIN to fetch the Psitta user UUID for the audit_log row.
    row = await db.execute(
        text(
            "SELECT s.id, sc.user_id "
            "FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE s.stripe_subscription_id = :sub_id"
        ),
        {"sub_id": stripe_sub_id},
    )
    existing = row.mappings().first()
    if not existing:
        logger.warning(
            "billing.handler.subscription_not_found",
            stripe_subscription_id=stripe_sub_id,
            event_id=event["id"],
        )
        return

    psitta_user_id = str(existing["user_id"])

    await db.execute(
        text(
            "UPDATE subscriptions SET "
            "  status = 'past_due', "
            "  updated_at = :now "
            "WHERE stripe_subscription_id = :sub_id"
        ),
        {"now": now, "sub_id": stripe_sub_id},
    )

    await audit_service.log_event(
        db,
        action="billing.payment_failed",
        resource_type="subscription",
        user_id=psitta_user_id,
        resource_id=psitta_user_id,
        details={
            "stripe_subscription_id": stripe_sub_id,
            "invoice_id": invoice_id,
        },
    )

    logger.info(
        "billing.payment_failed",
        stripe_subscription_id=stripe_sub_id,
        invoice_id=invoice_id,
    )


# ── Helpers ──────────────────────────────────────────────────────────────

async def store_webhook_event(
    *,
    event_id: str,
    event_type: str,
    stripe_subscription_id: str | None,
    payload: str,
) -> bool:
    """Persist a webhook event in its OWN database transaction.

    Returns True if a new row was inserted, False on duplicate delivery
    (idempotency hit). Uses ``ON CONFLICT (stripe_event_id) DO NOTHING``
    so two concurrent deliveries of the same event collapse atomically
    without a check-then-act race.

    Why a separate session: the request session is shared with the
    handler logic (subscriptions INSERT, audit_log INSERT, ...). If
    any of those fail, the request transaction aborts and rolls back —
    which would also lose the forensic trail row if it lived in the
    same transaction. Persisting here in an independent session means
    the event payload survives every handler crash, so failed deliveries
    can be reprocessed manually from ``subscription_events.payload``.
    """
    async with async_session_factory() as session:
        result = await session.execute(
            text(
                "INSERT INTO subscription_events "
                "(stripe_event_id, event_type, stripe_subscription_id, payload) "
                "VALUES (:eid, :etype, :sub_id, :payload) "
                "ON CONFLICT (stripe_event_id) DO NOTHING "
                "RETURNING id"
            ),
            {
                "eid": event_id,
                "etype": event_type,
                "sub_id": stripe_subscription_id,
                "payload": payload,
            },
        )
        inserted = result.fetchone() is not None
        await session.commit()
        return inserted


def stripe_obj_to_dict(obj: Any) -> dict:
    """Recursively convert a Stripe API object to a plain dict.

    StripeObject is a dict subclass, but its nested values are also
    StripeObjects whose ``__getattr__`` raises ``AttributeError`` for
    missing keys instead of returning ``None`` — which means a routine
    ``foo.get("bar")`` blows up with ``AttributeError: get`` because
    Python first looks up ``get`` as an attribute on the StripeObject
    and falls into the trap. Round-tripping through JSON gives us pure
    dict / list / scalar trees so downstream code can use standard
    mapping access without surprises.

    Stripe's ``StripeObject.__str__`` emits a JSON-formatted dump of the
    full object tree, so ``json.loads(str(obj))`` is the canonical
    Stripe-recommended deep conversion.
    """
    return json.loads(str(obj))


def _ts_to_dt(ts: int | None) -> datetime | None:
    """Convert a Unix timestamp from Stripe to a timezone-aware datetime."""
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, tz=UTC)
