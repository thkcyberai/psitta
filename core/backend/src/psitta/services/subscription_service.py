"""subscription_service.py — M3a tier enforcement (no Stripe).

Responsibilities:
  - Look up a user's active plan
  - Check monthly doc upload quota
  - Check voice tier access
  - Increment usage counter
  - Dev override: set plan manually (no payment required)
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, select, text, update
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.services.plan_limits import _normalize_plan_id, get_plan_limits

logger = logging.getLogger(__name__)

# ── Plan limit constants ─────────────────────────────────────────────────────
# Superseded by services/plan_limits.py for new code paths (C.2 onward).
# Retained here only for legacy callers (set_plan_override membership check,
# get_user_plan public shape) until the dual-table subscriptions tech debt
# is collapsed (Apr 23 / Apr 27 Key Learnings; tracked in M9 backlog).
PLAN_LIMITS: dict[str, dict] = {
    "free": {
        "docs_per_month": 10,
        "max_doc_size_mb": 10,
        "voices_tier": "edge_only",
        "audio_cache_days": 7,
        "can_archive": False,
        "el_chars_per_period": 0,
    },
    "pro_monthly": {
        "docs_per_month": 50,
        "max_doc_size_mb": 50,
        "voices_tier": "all",
        "audio_cache_days": 90,
        "can_archive": True,
        "el_chars_per_period": 150_000,
    },
    "pro_annual": {
        "docs_per_month": 50,
        "max_doc_size_mb": 50,
        "voices_tier": "all",
        "audio_cache_days": 90,
        "can_archive": True,
        "el_chars_per_period": 150_000,
    },
}

# Edge TTS voice IDs (available on free tier)
EDGE_TTS_VOICES = {
    "en-US-JennyNeural",
    "en-US-GuyNeural",
    "en-US-AndrewNeural",
    "en-US-BrianNeural",
    "en-US-RogerNeural",
    "en-US-SteffanNeural",
    "en-US-AriaNeural",
    "en-US-DavisNeural",
    "en-US-TonyNeural",
    "en-US-JaneNeural",
    "en-US-JasonNeural",
    "en-US-SaraNeural",
}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _current_year_month() -> str:
    now = datetime.now(timezone.utc)
    return f"{now.year}-{now.month:02d}"


async def _get_active_plan_id(db: AsyncSession, user_id: UUID) -> str:
    """Return the user's current plan id, defaulting to 'free'."""
    row = await db.execute(
        text("""
            SELECT plan_id FROM user_subscriptions
            WHERE user_id = :uid AND status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
        """),
        {"uid": str(user_id)},
    )
    result = row.fetchone()
    return result[0] if result else "free"


async def get_user_plan(db: AsyncSession, user_id: UUID) -> dict:
    """Return the user's plan id and its limit dict."""
    plan_id = await _get_active_plan_id(db, user_id)
    limits = PLAN_LIMITS.get(plan_id, PLAN_LIMITS["free"])
    return {"plan_id": plan_id, "limits": limits}


# ── Quota enforcement ────────────────────────────────────────────────────────

async def get_monthly_doc_count(db: AsyncSession, user_id: UUID) -> int:
    """Return how many docs this user has uploaded this calendar month."""
    ym = _current_year_month()
    row = await db.execute(
        text("""
            SELECT docs_uploaded FROM usage_counters
            WHERE user_id = :uid AND year_month = :ym
        """),
        {"uid": str(user_id), "ym": ym},
    )
    result = row.fetchone()
    return result[0] if result else 0


async def check_and_increment_doc_quota(
    db: AsyncSession, user_id: UUID
) -> None:
    """
    Raises HTTP 402 if the user is at their monthly doc limit.
    Otherwise atomically increments their counter.

    Reads docs_per_month from services/plan_limits.py via _normalize_plan_id
    so legacy ENUM values (pro_monthly / pro_annual) map to canonical
    PlanLimits entries (reading_nook_pro). Kills the dual-PLAN_LIMITS read
    path that previously diverged for Stripe-paying users.
    """
    raw_plan_id = await _get_active_plan_id(db, user_id)
    canonical_plan_id = _normalize_plan_id(raw_plan_id)
    limits = get_plan_limits(canonical_plan_id)
    limit = limits.documents_per_month
    current = await get_monthly_doc_count(db, user_id)

    if limit != -1 and current >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": "quota_exceeded",
                "message": (
                    f"Monthly document limit reached ({current}/{limit}). "
                    "Upgrade to Pro for more documents."
                ),
                "plan": canonical_plan_id,
                "used": current,
                "limit": limit,
            },
        )

    # Upsert usage counter (id is required — generate for new rows)
    ym = _current_year_month()
    await db.execute(
        text("""
            INSERT INTO usage_counters (id, user_id, year_month, docs_uploaded, updated_at)
            VALUES (:id, :uid, :ym, 1, NOW())
            ON CONFLICT (user_id, year_month)
            DO UPDATE SET docs_uploaded = usage_counters.docs_uploaded + 1,
                          updated_at = NOW()
        """),
        {"id": str(uuid4()), "uid": str(user_id), "ym": ym},
    )
    await db.commit()


async def check_voice_access(
    db: AsyncSession, user_id: UUID, voice_id: str
) -> None:
    """
    Raises HTTP 403 if the user's plan doesn't allow the requested voice.
    Free tier: Edge TTS voices only.
    Pro tier: all voices.
    """
    plan_info = await get_user_plan(db, user_id)
    voices_tier = plan_info["limits"]["voices_tier"]

    if voices_tier == "edge_only" and voice_id not in EDGE_TTS_VOICES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "voice_not_available",
                "message": (
                    f"Voice '{voice_id}' is not available on the Free plan. "
                    "Upgrade to Pro to access all voices."
                ),
                "plan": plan_info["plan_id"],
                "voice_id": voice_id,
            },
        )


# ── ElevenLabs character quota (C.2) ─────────────────────────────────────────

async def _get_active_period_start(
    db: AsyncSession, user_id: UUID
) -> datetime | None:
    """Return the user's current billing period start, or None.

    Source-of-truth resolution order:
      1. subscriptions.current_period_start joined via stripe_customers
         (Stripe-managed Reading/Creative Nook Pro subscribers — real
         billing-anniversary date from Stripe Basil API items[0]).
      2. user_subscriptions.current_period_start (dev/admin override path
         via set_plan_override; no Stripe row exists for these users).

    Returns None when neither table has an active row — caller decides
    whether to treat as a free user or short-circuit the quota check.

    The dual-table read documents the live tech debt from the Apr 23 /
    Apr 27 Key Learnings (subscriptions vs user_subscriptions split).
    Collapses to a single subscriptions read once dev-override paths
    are migrated off user_subscriptions (M9 backlog).
    """
    row = await db.execute(
        text(
            """
            SELECT s.current_period_start
            FROM subscriptions s
            JOIN stripe_customers sc ON sc.id = s.stripe_customer_id
            WHERE sc.user_id = :uid AND s.status = 'active'
            ORDER BY s.created_at DESC LIMIT 1
            """
        ),
        {"uid": str(user_id)},
    )
    result = row.fetchone()
    if result and result[0] is not None:
        return result[0]

    row = await db.execute(
        text(
            """
            SELECT current_period_start FROM user_subscriptions
            WHERE user_id = :uid AND status = 'active'
            ORDER BY created_at DESC LIMIT 1
            """
        ),
        {"uid": str(user_id)},
    )
    result = row.fetchone()
    if result and result[0] is not None:
        return result[0]
    return None


async def check_el_quota(
    db: AsyncSession, user_id: UUID
) -> tuple[int, int, datetime]:
    """Return (chars_used, chars_limit, period_start) for this user.

    Pure read — does not raise, does not mutate. Caller (TTS router)
    decides whether to skip ElevenLabs based on the returned values.
    Free-tier and unknown-plan users get limit=0 which forces the
    router to fall back to Edge unconditionally.

    period_start defaults to NOW() when no active subscription row
    exists; in that case limit is also 0 so the value is never used to
    key a counter row.
    """
    raw_plan_id = await _get_active_plan_id(db, user_id)
    canonical_plan_id = _normalize_plan_id(raw_plan_id)
    limits = get_plan_limits(canonical_plan_id)
    chars_limit = limits.el_chars_per_period

    period_start = await _get_active_period_start(db, user_id)
    if period_start is None:
        return (0, chars_limit, datetime.now(timezone.utc))

    row = await db.execute(
        text(
            """
            SELECT chars_consumed FROM el_usage_counters
            WHERE user_id = :uid AND period_start = :ps
            """
        ),
        {"uid": str(user_id), "ps": period_start},
    )
    result = row.fetchone()
    chars_used = result[0] if result else 0
    return (chars_used, chars_limit, period_start)


async def increment_el_chars(
    db: AsyncSession,
    user_id: UUID,
    period_start: datetime,
    char_count: int,
) -> None:
    """Atomically increment EL chars consumed for (user_id, period_start).

    Insert-or-update on the unique (user_id, period_start) constraint
    from migration 018. Commits on success.
    """
    if char_count <= 0:
        return
    await db.execute(
        text(
            """
            INSERT INTO el_usage_counters
                (user_id, period_start, chars_consumed, created_at, updated_at)
            VALUES (:uid, :ps, :chars, NOW(), NOW())
            ON CONFLICT (user_id, period_start) DO UPDATE
            SET chars_consumed = el_usage_counters.chars_consumed + EXCLUDED.chars_consumed,
                updated_at = NOW()
            """
        ),
        {"uid": str(user_id), "ps": period_start, "chars": char_count},
    )
    await db.commit()


# ── Subscription management ──────────────────────────────────────────────────

async def ensure_free_subscription(db: AsyncSession, user_id: UUID) -> None:
    """
    Called on first user login / provisioning.
    Creates a free subscription row if the user has none.
    """
    row = await db.execute(
        text("SELECT id FROM user_subscriptions WHERE user_id = :uid LIMIT 1"),
        {"uid": str(user_id)},
    )
    if row.fetchone() is None:
        await db.execute(
            text("""
                INSERT INTO user_subscriptions
                    (user_id, plan_id, status, started_at)
                VALUES (:uid, 'free', 'active', NOW())
            """),
            {"uid": str(user_id)},
        )
        await db.commit()
        logger.info("Created free subscription for user %s", user_id)


async def set_plan_override(
    db: AsyncSession, user_id: UUID, plan_id: str
) -> dict:
    """
    Dev / admin override: manually set a user's plan without Stripe.
    Cancels any existing active subscription and creates a new one.
    """
    if plan_id not in PLAN_LIMITS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown plan_id '{plan_id}'. Valid: {list(PLAN_LIMITS.keys())}",
        )

    # Cancel existing active subscriptions
    await db.execute(
        text("""
            UPDATE user_subscriptions
            SET status = 'cancelled', cancelled_at = NOW(), updated_at = NOW()
            WHERE user_id = :uid AND status = 'active'
        """),
        {"uid": str(user_id)},
    )

    # Create new active subscription
    await db.execute(
        text("""
            INSERT INTO user_subscriptions
                (user_id, plan_id, status, started_at, current_period_start)
            VALUES (:uid, :plan_id, 'active', NOW(), NOW())
        """),
        {"uid": str(user_id), "plan_id": plan_id},
    )
    await db.commit()

    logger.info("Plan override: user %s -> %s", user_id, plan_id)
    return {"user_id": str(user_id), "plan_id": plan_id, "status": "active"}


async def get_subscription_summary(db: AsyncSession, user_id: UUID) -> dict:
    """Return full subscription info for /users/me/subscription."""
    plan_info = await get_user_plan(db, user_id)
    monthly_used = await get_monthly_doc_count(db, user_id)
    limit = plan_info["limits"]["docs_per_month"]

    row = await db.execute(
        text("""
            SELECT id, plan_id, status, started_at, current_period_start,
                   current_period_end, stripe_subscription_id
            FROM user_subscriptions
            WHERE user_id = :uid AND status = 'active'
            ORDER BY created_at DESC LIMIT 1
        """),
        {"uid": str(user_id)},
    )
    sub = row.fetchone()

    return {
        "plan_id": plan_info["plan_id"],
        "limits": plan_info["limits"],
        "usage": {
            "docs_this_month": monthly_used,
            "docs_limit": limit,
            "docs_remaining": max(0, limit - monthly_used) if limit != -1 else None,
        },
        "subscription": {
            "id": str(sub[0]) if sub else None,
            "status": sub[2] if sub else "none",
            "started_at": sub[3].isoformat() if sub and sub[3] else None,
            "period_end": sub[5].isoformat() if sub and sub[5] else None,
            "stripe_active": sub[6] is not None if sub else False,
        },
    }
