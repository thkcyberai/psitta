"""api/v1/billing.py — Stripe billing endpoints (M3 Phase B2 + B3).

Endpoints:
  POST /billing/checkout-session  — create a Stripe Checkout session
  POST /billing/portal-session    — create a Stripe Customer Portal session
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
from psitta.services.plan_limits import get_plan_limits, plan_limits_to_dict
from psitta.services.subscription_service import get_effective_plan

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()

# ── Constants ────────────────────────────────────────────────────────────

# A4 product consolidation (2026-07-20): Writing Nook is the only
# purchasable product. Reading Nook is discontinued (existing subs are
# grandfathered upward via the reading→writing aliases in plan_limits /
# _PLAN_NAME_ALIASES / subscription_service); Creative Nook is
# roadmap-only ("Coming Soon") and gets no checkout path until it ships.
VALID_LOOKUP_KEYS: frozenset[str] = frozenset({
    "writing_nook_pro_monthly",
    "writing_nook_pro_annual",
})

# Stripe-native free trial applied to every new Checkout session,
# code-level so the trial length is deterministic and reviewable here
# rather than hidden in per-price Dashboard config. This is the single
# trial source of truth — the signup-time reverse trial is disabled
# (config.REVERSE_TRIAL_ENABLED now defaults False) so a new writer
# can't stack 14 signup days on top of 14 checkout days.
TRIAL_PERIOD_DAYS = 14

_FREE_STATUS = {
    "plan": "free",
    "billing_period": None,
    "status": "none",
    "current_period_end": None,
    "cancel_at_period_end": False,
    "source": "free",
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


class PortalSessionResponse(BaseModel):
    """Response containing the Stripe Customer Portal URL."""

    url: str


class BillingStatusResponse(BaseModel):
    """Current subscription status for the authenticated user.

    ``source`` (T11.2) discloses which storage path resolved the
    entitlement: ``stripe`` (real paying customer), ``dev_override``
    (PATCH /users/me/plan), ``tester_allowlist`` (Item 11 alpha cohort),
    or ``free``. Desktop UI uses this to render the alpha-tester badge
    and hide the Stripe Customer Portal button for non-Stripe sources.

    ``el_chars_per_period`` and ``llm_tokens_per_period`` mirror the
    plan_limits.py canonical values for the resolved plan. Clients use
    these to size quota progress bars without a second endpoint call.
    0 means no access for that resource type on this plan.

    ``status`` (A4 trialing contract): for ``source == "stripe"`` this
    is ``"active"`` or ``"trialing"`` — BOTH mean entitled. A user
    inside the 14-day Stripe trial reports ``trialing`` with
    ``current_period_end`` = the trial end, which clients may use for
    "N days left" messaging. Clients MUST gate Pro features on
    ``status in ("active", "trialing")``, never ``== "active"`` alone.
    """

    plan: str
    billing_period: str | None
    status: str
    current_period_end: str | None
    cancel_at_period_end: bool
    source: str
    el_chars_per_period: int
    llm_tokens_per_period: int


# ── POST /billing/checkout-session ───────────────────────────────────────

@router.post(
    "/checkout-session",
    response_model=CheckoutSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a Stripe Checkout session",
)
async def create_checkout_session(  # noqa: PLR0912, PLR0915 -- numbered steps 1-7, each a distinct Stripe/DB interaction; extracting helpers would push noise around without clarifying intent
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

    # 2. Fast-path: local-DB check for existing active subscription. This
    # short-circuits the common case without a Stripe API call. The
    # Stripe-direct check at step 4b is the source of truth — local rows
    # lag behind real Stripe state by however long the webhook takes to
    # arrive, so this check alone is not sufficient.
    result = await db.execute(
        text(
            "SELECT s.id FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE sc.user_id = :user_id "
            "  AND s.status IN ('active', 'trialing') "
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

    # 4a. Sync Stripe Customer email to current JWT email (Bug B). The
    # Customer was created (line 180) with whatever JWT email was
    # present at the user's first /billing/checkout-session call and
    # is never refreshed afterwards. If the user subsequently changed
    # their email in Cognito, Stripe Dashboard / billing portal /
    # receipts all show the stale address. stripe.Customer.modify is
    # idempotent on Stripe's side — sending the current email when it
    # already matches is a no-op. Skip when customer_row is None
    # (just-created with current email from step 4) and when
    # claims.email is empty (sending "" would clear Stripe's record).
    # Failures are logged but do NOT block checkout — a stale email
    # is a UX nit, a failed checkout is a revenue event.
    if customer_row is not None and claims.email:
        try:
            stripe.Customer.modify(stripe_customer_id, email=claims.email)
            logger.info(
                "billing.stripe_customer_email_synced",
                user_id=str(user_id),
                stripe_customer_id=stripe_customer_id,
            )
        except stripe.StripeError as exc:
            logger.warning(
                "billing.stripe_customer_email_sync_failed",
                user_id=str(user_id),
                stripe_customer_id=stripe_customer_id,
                error=str(exc),
            )

    # 4b. Stripe-direct duplicate check. Defends against webhook lag: the
    # local check at step 2 reads the subscriptions table which is only
    # populated after Stripe sends checkout.session.completed. A user who
    # clicks Subscribe twice between the two webhook arrivals would pass
    # step 2 and end up with two active Stripe subscriptions on the same
    # customer (production incident May 2 2026 — test3 with monthly +
    # annual R-Pro).
    # Skip when customer_row is None: a Stripe Customer that was just
    # created in step 4 cannot have any subscriptions yet, so the API
    # round-trip is wasted on every brand-new signup.
    # A4: with the 14-day trial, an entitled subscription may be in
    # status 'trialing' — Stripe's status="active" filter does NOT
    # return trialing subs, so a mid-trial user could have opened a
    # second Checkout and started a second (trialing) subscription.
    # List with status="all" and block on any live entitled status.
    if customer_row is not None:
        try:
            all_subs = stripe.Subscription.list(
                customer=stripe_customer_id, status="all", limit=10
            )
        except stripe.StripeError as exc:
            logger.error("billing.stripe_active_sub_check_failed", error=str(exc))
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Payment provider error. Please try again later.",
            ) from exc
        active_subs_data = [
            s for s in all_subs.data if s.status in ("active", "trialing")
        ]
        if active_subs_data:
            logger.warning(
                "billing.duplicate_subscription_blocked",
                user_id=str(user_id),
                stripe_customer_id=stripe_customer_id,
                existing_stripe_subscription_id=active_subs_data[0].id,
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Active subscription already exists. "
                    "Use the billing portal to manage your plan."
                ),
            )

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
            # A4: every new subscription starts with the 14-day free
            # trial (card collected up front; first charge at trial
            # end). Webhooks deliver status='trialing', which the whole
            # entitlement chain now treats as entitled.
            subscription_data={"trial_period_days": TRIAL_PERIOD_DAYS},
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


# ── POST /billing/portal-session ─────────────────────────────────────────

@router.post(
    "/portal-session",
    response_model=PortalSessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a Stripe Customer Portal session",
)
async def create_portal_session(
    request: Request,
    user_id=Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
):
    """Create a Stripe Customer Portal session for subscription management.

    Returns a URL to the Stripe-hosted Customer Portal where the user
    can swap plans, switch billing periods, update payment method,
    download invoices, and cancel their subscription. The portal
    configuration (eligible products, cancellation reasons, proration
    behaviour, header text) is managed in the Stripe Dashboard.

    Free users with no stripe_customers row receive a 404 — they have
    nothing to manage. Stripe API failures return 502 with a clean
    message rather than leaking provider details.
    """
    settings = get_settings()

    # 1. Look up Stripe Customer
    row = await db.execute(
        text(
            "SELECT stripe_customer_id FROM stripe_customers "
            "WHERE user_id = :user_id"
        ),
        {"user_id": user_id},
    )
    customer_row = row.mappings().first()

    if not customer_row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No Stripe customer record. Subscribe first to manage subscription.",
        )

    # 2. Configure Stripe + create portal session
    stripe.api_key = settings.STRIPE_SECRET_KEY_TEST.get_secret_value()
    try:
        session = stripe.billing_portal.Session.create(
            customer=customer_row["stripe_customer_id"],
            return_url="https://psitta.ai/",
        )
    except stripe.StripeError as exc:
        logger.error("billing.stripe_portal_session_failed", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider error. Please try again later.",
        ) from exc

    # 3. Audit log
    await audit_service.log_event(
        db,
        action="billing.portal_session_created",
        resource_type="billing",
        user_id=str(user_id),
        details={"session_id": session.id},
        ip_address=request.client.host if request.client else None,
    )

    logger.info(
        "billing.portal_session.created",
        user_id=str(user_id),
        session_id=session.id,
    )

    return PortalSessionResponse(url=session.url)


# ── GET /billing/status ──────────────────────────────────────────────────

@router.get(
    "/status",
    response_model=BillingStatusResponse,
    summary="Get current subscription status",
)
async def get_billing_status(
    request: Request,
    user_id=Depends(get_current_user_id),
    claims: TokenClaims = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    """Return the current user's subscription status.

    Always returns a valid response — free plan defaults if no
    entitlement exists. T11.2 routes resolution through the unified
    ``get_effective_plan`` resolver so all four sources (stripe,
    dev_override, tester_allowlist, free) flow through one path; the
    response gains a ``source`` field exposing which path resolved.

    JWT email is forwarded to the resolver so allowlist lookup uses
    the freshest known address — auto-provisioned users may carry a
    synthetic ``users.email`` placeholder (Apr 27 Key Learning) which
    would otherwise miss a real-email allowlist row.
    """
    plan_state = await get_effective_plan(db, user_id, email=claims.email)

    # Map the resolver's source back into the BillingStatusResponse
    # shape that pre-T11.2 clients understand. Stripe is the only path
    # with a meaningful billing_period; dev_override / tester_allowlist
    # carry plan + period_end but never a Stripe-style monthly/annual
    # cadence label.
    if plan_state.source == "stripe":
        plan_name, billing_period = _parse_lookup_key(plan_state.raw_plan_id)
        # A4 trialing contract: report the real subscription status —
        # 'active' or 'trialing' (the only two statuses the resolver
        # accepts). Both mean ENTITLED; the desktop plan gate accepts
        # both (A2's client half). Anything else stays 'active' as a
        # defensive default (the resolver never returns other values).
        status_value = (
            "trialing" if plan_state.status == "trialing" else "active"
        )
        outcome = (
            "found_trialing" if status_value == "trialing" else "found_active"
        )
    elif plan_state.source in ("dev_override", "tester_allowlist", "reverse_trial"):
        # reverse_trial carries the granted plan (writing_nook_pro) with an
        # expires_at period end; report it as an active plan so the trial
        # writer gets the full Writing Nook UI. Without this, the source
        # fell into the else branch below and a live 14-day trial user was
        # reported as plan="free" — showing them the Free interface.
        plan_name = plan_state.plan_id
        billing_period = None
        status_value = "active"
        outcome = "found_active"
    else:
        plan_name = _FREE_STATUS["plan"]
        billing_period = _FREE_STATUS["billing_period"]
        status_value = _FREE_STATUS["status"]
        outcome = "no_active_sub"

    period_end_str = (
        plan_state.current_period_end.isoformat()
        if plan_state.current_period_end
        else None
    )

    # Plan limits — fetched once here so the response carries the quota
    # ceilings alongside the plan name; clients avoid a second call.
    plan_limits = get_plan_limits(plan_name)

    # Audit — emitted on every code path including Free, with the
    # resolver source exposed in details for forensic filtering.
    # Audit writes are SAVEPOINT-isolated and best-effort: this endpoint
    # must always return a valid status, so a failed audit INSERT can
    # never poison the request transaction or 500 the response.
    try:
        async with db.begin_nested():
            await audit_service.log_event(
                db,
                action="billing.status_checked",
                resource_type="billing",
                user_id=str(user_id),
                details={
                    "plan": plan_name,
                    "outcome": outcome,
                    "source": plan_state.source,
                },
                ip_address=request.client.host if request.client else None,
            )
    except Exception as exc:
        logger.warning(
            "billing.audit_failed",
            action="billing.status_checked",
            error=str(exc),
        )

    # Tester allowlist resolution gets its own event so CloudWatch
    # alerts can fire on a single action filter ("alpha tester X
    # resolved at Y") without sifting through every billing.status_checked
    # record. Frontend polls /billing/status periodically, so this
    # event provides natural surprise-expiry detection granularity
    # without flooding logs (no per-quota-check emission).
    if plan_state.source == "tester_allowlist":
        try:
            async with db.begin_nested():
                await audit_service.log_event(
                    db,
                    action="tester.entitlement_resolved",
                    resource_type="billing",
                    user_id=str(user_id),
                    details={
                        "email": claims.email,
                        "expires_at": (
                            plan_state.current_period_end.isoformat()
                            if plan_state.current_period_end
                            else None
                        ),
                    },
                    ip_address=request.client.host if request.client else None,
                )
        except Exception as exc:
            logger.warning(
                "billing.audit_failed",
                action="tester.entitlement_resolved",
                error=str(exc),
            )

    return BillingStatusResponse(
        plan=plan_name,
        billing_period=billing_period,
        status=status_value,
        current_period_end=period_end_str,
        cancel_at_period_end=plan_state.cancel_at_period_end,
        source=plan_state.source,
        el_chars_per_period=plan_limits.el_chars_per_period,
        llm_tokens_per_period=plan_limits.llm_tokens_per_period,
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
    # A4 product consolidation: historical Reading Nook subscriptions
    # are grandfathered UPWARD to Writing Nook (DP-2). The Stripe row
    # keeps its original lookup_key; every read-side surface reports
    # writing_nook_pro so the client renders the one remaining product.
    "reading_nook_pro": "writing_nook_pro",
}


def _parse_lookup_key(lookup_key: str) -> tuple[str, str]:
    """Extract plan name and billing period from a Stripe lookup key.

    The Stripe-side lookup keys still use ``creativity_nook_pro_*``,
    but the returned plan name is normalised to the internal identifier
    (``creative_nook_pro``) used by PLAN_LIMITS and the Flutter client.
    Discontinued Reading Nook keys normalise upward to Writing Nook
    (A4 consolidation, DP-2 grandfathering).

    "reading_nook_pro_monthly"   → ("writing_nook_pro", "monthly")
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
