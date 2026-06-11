"""api/v1/subscriptions.py — Subscription & plan endpoints (M3a).

Endpoints:
  GET  /subscriptions/plans              — list all available plans
  GET  /users/me/subscription            — current user's plan + usage
  PATCH /users/me/plan                   — dev/admin override (no Stripe)
"""

from __future__ import annotations

from dataclasses import asdict

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.middleware.auth import require_role
from psitta.services import audit_service
from psitta.services.plan_limits import get_plan_limits
from psitta.services.subscription_service import (
    get_subscription_summary,
    set_plan_override,
)

router = APIRouter(tags=["subscriptions"])


# ── GET /subscriptions/plans ─────────────────────────────────────────────────

@router.get("/subscriptions/plans")
async def list_plans():
    """Return the three legacy plan tiers with their limits.

    Legacy endpoint — retained for backward compatibility. The authoritative
    surface for new tiers (writing_nook_pro, creative_nook_pro) is
    GET /billing/plans which uses plan_limits_to_dict() from plan_limits.py.
    """
    display = {
        "free":        {"name": "Free",        "price_usd": 0,     "interval": None},
        "pro_monthly": {"name": "Pro Monthly",  "price_usd": 12.00, "interval": "monthly"},
        "pro_annual":  {"name": "Pro Annual",   "price_usd": 99.00, "interval": "annual"},
    }
    plans = [
        {
            "id": plan_id,
            "display_name": d["name"],
            "price_usd": d["price_usd"],
            "billing_interval": d["interval"],
            # get_plan_limits normalises pro_monthly/pro_annual →
            # reading_nook_pro internally; limits are from the canonical dict.
            "limits": asdict(get_plan_limits(plan_id)),
        }
        for plan_id, d in display.items()
    ]
    return {"plans": plans}


# ── GET /users/me/subscription ───────────────────────────────────────────────

@router.get("/users/me/subscription")
async def get_my_subscription(
    user_id=Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
):
    """Return the current user's active plan, limits, and usage for this month."""
    return await get_subscription_summary(db, user_id)


# ── PATCH /users/me/plan ─────────────────────────────────────────────────────

@router.patch("/users/me/plan")
async def override_plan(
    body: dict,
    request: Request,
    _claims=Depends(require_role("admin")),
    user_id=Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Admin-only override — set plan without Stripe payment.

    Requires the caller to carry the 'admin' Cognito group role; all other
    authenticated users receive 403.  The dev-bypass token already carries
    roles=['admin'] (auth.py), so this gate is transparent in local dev.

    Body: { "plan_id": "free" | "pro_monthly" | "pro_annual" | "writing_nook_pro" }
    """
    plan_id = body.get("plan_id")
    if not plan_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Request body must include 'plan_id'",
        )
    result = await set_plan_override(db, user_id, plan_id)
    await audit_service.log_event(
        db,
        action="subscription.plan_override",
        resource_type="subscription",
        user_id=str(user_id),
        resource_id=str(user_id),
        details={"plan_id": plan_id},
        ip_address=request.client.host if request.client else None,
    )
    return result
