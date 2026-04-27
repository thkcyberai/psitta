"""api/v1/billing.py — Stripe billing endpoints (M3 Phase B2 + B3).

Endpoints:
  POST /billing/checkout-session  — create a Stripe Checkout session
  GET  /billing/status            — current user's subscription status
  POST /billing/webhook           — Stripe webhook receiver (no auth, sig-verified)

Security:
  - checkout-session and status require JWT authentication
  - webhook uses Stripe signature verification (no JWT)
  - lookup_key validated against explicit allowlist
  - Stripe errors never exposed to client
  - Audit trail on all billing actions
  - Webhook is idempotent via subscription_events table
"""

from __future__ import annotations

import json
import traceback

import stripe
import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import get_settings
from psitta.dependencies import get_current_user_id, get_db_session
from psitta.middleware.auth import TokenClaims, get_current_user
from psitta.services import audit_service
from psitta.services.billing_handlers import (
    handle_checkout_session_completed,
    handle_payment_failed,
    handle_subscription_deleted,
    handle_subscription_updated,
    store_webhook_event,
    stripe_obj_to_dict,
)
from psitta.services.plan_limits import plan_limits_to_dict

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()

# ── Constants ────────────────────────────────────────────────────────────

VALID_LOOKUP_KEYS: frozenset[str] = frozenset({
    "reading_nook_pro_monthly",
    "reading_nook_pro_annual",
    "creativity_nook_pro_monthly",
    "creativity_nook_pro_annual",
})

_FREE_STATUS = {
    "plan": "free",
    "billing_period": None,
    "status": "none",
    "current_period_end": None,
    "cancel_at_period_end": False,
}


# ── GET /billing/plans (public) ───────────────────────────────────────────

@router.get(
    "/plans",
    summary="List available plans and their feature limits",
)
async def list_plans():
    """Return all plan definitions with feature gates and quotas.

    Public endpoint — no authentication required. Used by the Flutter
    app and psitta.ai website to display plan comparison tables.
    """
    return {"plans": plan_limits_to_dict()}


# ── Request / Response Schemas ───────────────────────────────────────────

class CheckoutSessionRequest(BaseModel):
    """Request body for creating a Stripe Checkout session."""

    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")

    lookup_key: str


class CheckoutSessionResponse(BaseModel):
    """Response containing the Stripe Checkout URL."""

    checkout_url: str


class BillingStatusResponse(BaseModel):
    """Current subscription status for the authenticated user."""

    plan: str
    billing_period: str | None
    status: str
    current_period_end: str | None
    cancel_at_period_end: bool


# ── POST /billing/checkout-session ───────────────────────────────────────

@router.post(
    "/checkout-session",
    response_model=CheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a Stripe Checkout session",
)
async def create_checkout_session(
    body: CheckoutSessionRequest,
    request: Request,
    user_id=Depends(get_current_user_id),
    claims: TokenClaims = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Create a Stripe Checkout session for subscription signup.

    Returns a URL to the Stripe-hosted Checkout page. The client
    redirects the user to this URL to complete payment.
    """
    settings = get_settings()

    # 1. Validate lookup_key
    if body.lookup_key not in VALID_LOOKUP_KEYS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid lookup_key. Must be one of: {', '.join(sorted(VALID_LOOKUP_KEYS))}",
        )

    # 2. Check for existing active subscription
    result = await db.execute(
        text(
            "SELECT s.id FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE sc.user_id = :user_id AND s.status = 'active' "
            "LIMIT 1"
        ),
        {"user_id": user_id},
    )
    if result.fetchone() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Active subscription already exists. "
                "Use the billing portal to manage your plan."
            ),
        )

    # 3. Configure Stripe
    stripe.api_key = settings.STRIPE_SECRET_KEY_TEST.get_secret_value()

    # 4. Look up or create Stripe Customer
    row = await db.execute(
        text("SELECT id, stripe_customer_id FROM stripe_customers WHERE user_id = :user_id"),
        {"user_id": user_id},
    )
    customer_row = row.mappings().first()

    if customer_row:
        stripe_customer_id = customer_row["stripe_customer_id"]
    else:
        try:
            customer = stripe.Customer.create(
                email=claims.email or None,
                metadata={"psitta_user_id": str(user_id)},
            )
        except stripe.StripeError as exc:
            logger.error("billing.stripe_customer_create_failed", error=str(exc))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Payment provider error. Please try again later.",
            ) from exc

        stripe_customer_id = customer.id
        await db.execute(
            text(
                "INSERT INTO stripe_customers (user_id, stripe_customer_id) "
                "VALUES (:user_id, :stripe_customer_id)"
            ),
            {"user_id": user_id, "stripe_customer_id": stripe_customer_id},
        )
        await db.flush()

    # 5. Resolve lookup_key to Stripe Price
    try:
        prices = stripe.Price.list(lookup_keys=[body.lookup_key], active=True)
    except stripe.StripeError as exc:
        logger.error("billing.stripe_price_lookup_failed", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error. Please try again later.",
        ) from exc

    if not prices.data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No active price found for lookup_key '{body.lookup_key}'.",
        )
    price_id = prices.data[0].id

    # 6. Create Checkout Session
    try:
        session = stripe.checkout.Session.create(
            mode="subscription",
            customer=stripe_customer_id,
            line_items=[{"price": price_id, "quantity": 1}],
            success_url="https://psitta.ai/billing/success/?session_id={CHECKOUT_SESSION_ID}",
            cancel_url="https://psitta.ai/billing/cancel/",
            metadata={
                "psitta_user_id": str(user_id),
                "lookup_key": body.lookup_key,
            },
        )
    except stripe.StripeError as exc:
        logger.error("billing.stripe_checkout_create_failed", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error. Please try again later.",
        ) from exc

    # 7. Audit log
    await audit_service.log_event(
        db,
        action="billing.checkout_session_created",
        resource_type="billing",
        user_id=str(user_id),
        details={"lookup_key": body.lookup_key},
        ip_address=request.client.host if request.client else None,
    )

    logger.info(
        "billing.checkout_session_created",
        user_id=str(user_id),
        lookup_key=body.lookup_key,
    )

    return CheckoutSessionResponse(checkout_url=session.url)


# ── GET /billing/status ──────────────────────────────────────────────────

@router.get(
    "/status",
    response_model=BillingStatusResponse,
    summary="Get current subscription status",
)
async def get_billing_status(
    request: Request,
    user_id=Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
):
    """Return the current user's subscription status.

    Always returns a valid response — free plan defaults if no
    subscription exists.
    """
    # 1. Look up Stripe Customer
    row = await db.execute(
        text("SELECT id FROM stripe_customers WHERE user_id = :user_id"),
        {"user_id": user_id},
    )
    customer_row = row.fetchone()

    if not customer_row:
        return BillingStatusResponse(**_FREE_STATUS)

    # 2. Get most recent subscription
    result = await db.execute(
        text(
            "SELECT lookup_key, status, current_period_end, cancel_at_period_end "
            "FROM subscriptions "
            "WHERE stripe_customer_id = :sc_id "
            "ORDER BY created_at DESC LIMIT 1"
        ),
        {"sc_id": customer_row[0]},
    )
    sub = result.mappings().first()

    if not sub or sub["status"] == "canceled":
        return BillingStatusResponse(**_FREE_STATUS)

    # 3. Map lookup_key to plan and billing_period
    lookup_key = sub["lookup_key"]
    plan, billing_period = _parse_lookup_key(lookup_key)

    # 4. Format period end
    period_end = sub["current_period_end"]
    period_end_str = period_end.isoformat() if period_end else None

    # 5. Audit log
    await audit_service.log_event(
        db,
        action="billing.status_checked",
        resource_type="billing",
        user_id=str(user_id),
        details={"plan": plan},
        ip_address=request.client.host if request.client else None,
    )

    return BillingStatusResponse(
        plan=plan,
        billing_period=billing_period,
        status=sub["status"],
        current_period_end=period_end_str,
        cancel_at_period_end=sub["cancel_at_period_end"],
    )


# ── POST /billing/webhook ────────────────────────────────────────────────

# Maps Stripe event types to their handler functions.
_EVENT_HANDLERS = {
    "checkout.session.completed": handle_checkout_session_completed,
    "customer.subscription.updated": handle_subscription_updated,
    "customer.subscription.deleted": handle_subscription_deleted,
    "invoice.payment_failed": handle_payment_failed,
}


@router.post(
    "/webhook",
    summary="Stripe webhook receiver",
    response_class=JSONResponse,
)
async def stripe_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db_session),
):
    """Receive and process Stripe webhook events.

    Security: No JWT — Stripe signature verification instead.
    Idempotency: Events recorded in subscription_events before processing.
    Fail-safe: Always returns 200 to prevent Stripe retry storms.
    """
    settings = get_settings()
    raw_body = await request.body()
    signature = request.headers.get("Stripe-Signature", "")

    # ── Step 1: Signature verification ───────────────────────────────
    try:
        event = stripe.Webhook.construct_event(
            payload=raw_body,
            sig_header=signature,
            secret=settings.STRIPE_WEBHOOK_SECRET.get_secret_value(),
        )
    except ValueError as exc:
        logger.warning("billing.webhook.invalid_payload")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid payload",
        ) from exc
    except stripe.SignatureVerificationError as exc:
        logger.warning("billing.webhook.invalid_signature")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid signature",
        ) from exc

    # Convert the entire StripeObject tree to plain dicts ONCE, here at
    # the entry point. Every downstream consumer (handlers, idempotency
    # writer, audit logger) gets standard mappings — no need to repeat
    # the workaround for StripeObject's missing-key AttributeError trap.
    event = stripe_obj_to_dict(event)

    event_id = event["id"]
    event_type = event["type"]
    event_data = event["data"]["object"]
    stripe_sub_id = (
        event_data.get("subscription")
        or event_data.get("id", "")
    )

    logger.info(
        "billing.webhook.received",
        event_id=event_id,
        event_type=event_type,
    )

    # ── Step 2: Persist event (independent transaction + idempotency) ─
    # store_webhook_event opens its own DB session and commits before
    # returning, so the forensic trail row survives even if the handler
    # below crashes the request transaction. ON CONFLICT on the unique
    # ``stripe_event_id`` index handles duplicate Stripe deliveries
    # atomically — no check-then-act race.
    inserted = await store_webhook_event(
        event_id=event_id,
        event_type=event_type,
        stripe_subscription_id=stripe_sub_id or None,
        payload=json.dumps(event),
    )
    if not inserted:
        logger.info(
            "billing.webhook.duplicate",
            event_id=event_id,
        )
        return JSONResponse({"received": True})

    # ── Step 3: Event routing ────────────────────────────────────────
    handler = _EVENT_HANDLERS.get(event_type)
    if handler is None:
        logger.info(
            "billing.webhook.unhandled_type",
            event_type=event_type,
        )
        return JSONResponse({"received": True})

    try:
        await handler(event, db)
    except Exception:
        # Log the full traceback but ALWAYS return 200.
        # The event is already persisted in subscription_events via the
        # independent transaction above — even though the request session
        # below has now rolled back, the payload is durable and the
        # event can be reprocessed manually from subscription_events.
        logger.error(
            "billing.webhook.handler_failed",
            event_id=event_id,
            event_type=event_type,
            traceback=traceback.format_exc(),
        )

    # ── Step 4: Always 200 ───────────────────────────────────────────
    return JSONResponse({"received": True})


# ── Helpers ──────────────────────────────────────────────────────────────

# Stripe lookup keys use the legacy "creativity_nook_pro" prefix — they
# must match what's configured in the Stripe Dashboard and cannot be
# renamed without breaking the Price lookup. Internally we expose the
# Beta-correct identifier "creative_nook_pro" everywhere else, so this
# alias table is applied at the parse boundary.
_PLAN_NAME_ALIASES: dict[str, str] = {
    "creativity_nook_pro": "creative_nook_pro",
}


def _parse_lookup_key(lookup_key: str) -> tuple[str, str]:
    """Extract plan name and billing period from a Stripe lookup key.

    The Stripe-side lookup keys still use ``creativity_nook_pro_*``,
    but the returned plan name is normalised to the internal identifier
    (``creative_nook_pro``) used by PLAN_LIMITS and the Flutter client.

    "reading_nook_pro_monthly"   → ("reading_nook_pro", "monthly")
    "creativity_nook_pro_annual" → ("creative_nook_pro", "annual")
    """
    if lookup_key.endswith("_monthly"):
        plan = lookup_key.removesuffix("_monthly")
        period = "monthly"
    elif lookup_key.endswith("_annual"):
        plan = lookup_key.removesuffix("_annual")
        period = "annual"
    else:
        # Fallback — should not happen with validated keys
        return lookup_key, "monthly"
    return _PLAN_NAME_ALIASES.get(plan, plan), period
