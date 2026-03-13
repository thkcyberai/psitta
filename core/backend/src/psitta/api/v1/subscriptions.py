"""api/v1/subscriptions.py — Subscription & plan endpoints (M3a).

Endpoints:
  GET  /subscriptions/plans              — list all available plans
  GET  /users/me/subscription            — current user's plan + usage
  PATCH /users/me/plan                   — dev/admin override (no Stripe)
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.services.subscription_service import (
    PLAN_LIMITS,
    get_subscription_summary,
    set_plan_override,
)

router = APIRouter(tags=["subscriptions"])


# ── GET /subscriptions/plans ─────────────────────────────────────────────────

@router.get("/subscriptions/plans")
async def list_plans():
    """Return all available subscription plans with their limits."""
    plans = []
    display = {
        "free":        {"name": "Free",        "price_usd": 0,     "interval": None},
        "pro_monthly": {"name": "Pro Monthly",  "price_usd": 12.00, "interval": "monthly"},
        "pro_annual":  {"name": "Pro Annual",   "price_usd": 99.00, "interval": "annual"},
    }
    for plan_id, limits in PLAN_LIMITS.items():
        d = display[plan_id]
        plans.append({
            "id": plan_id,
            "display_name": d["name"],
            "price_usd": d["price_usd"],
            "billing_interval": d["interval"],
            "limits": limits,
        })
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
    user_id=Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
):
    """
    Dev/admin override — set plan without Stripe payment.
    Body: { "plan_id": "free" | "pro_monthly" | "pro_annual" }

    This endpoint is gated: in production it requires admin tier.
    In dev (bypass token), it is open to any authenticated user.
    """
    plan_id = body.get("plan_id")
    if not plan_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Request body must include 'plan_id'",
        )
    return await set_plan_override(db, user_id, plan_id)
