"""subscription_service.py — M3a tier enforcement (no Stripe).

Responsibilities:
  - Look up a user's active plan via the unified ``get_effective_plan``
    resolver — Stripe → user_subscriptions dev_override → tester_allowlist
    → free
  - Check monthly doc upload quota
  - Check voice tier access
  - Increment usage counter
  - Dev override: set plan manually (no payment required)
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.services.plan_limits import _normalize_plan_id, get_plan_limits
from psitta.services.tester_allowlist import check_allowlist_entitlement

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
    # Authoritative limits live in services/plan_limits.py.
    # This entry satisfies set_plan_override's membership check only.
    # Pending M9 dual-table collapse (Apr 23 / Apr 27 Key Learnings).
    "writing_nook_pro": {
        "docs_per_month": 50,
        "max_doc_size_mb": 50,
        "voices_tier": "all",
        "audio_cache_days": 90,
        "can_archive": True,
        "el_chars_per_period": 250_000,
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
    now = datetime.now(UTC)
    return f"{now.year}-{now.month:02d}"


# ── Effective plan resolver (Item 11 — Pattern 3 backend allowlist) ──────────

@dataclass(frozen=True)
class EffectivePlan:
    """Resolved entitlement for a user across all three storage paths.

    The single source of truth for "is this user Pro and through which
    mechanism?" — collapses the historical dual-table read pattern
    (subscriptions vs user_subscriptions, Apr 23 / Apr 27 Key Learnings)
    into one resolver and adds the tester_allowlist path on top.

    Fields:
        plan_id: canonical PLAN_LIMITS key (`free`, `reading_nook_pro`,
            `creative_nook_pro`). Safe to feed straight into
            ``get_plan_limits``.
        raw_plan_id: the plan id in the storage shape that wrote it
            (Stripe lookup_key, Postgres ENUM string, allowlist canonical).
            Preserved so legacy callers and audit logs don't lose
            information.
        current_period_start / current_period_end: billing-anniversary
            window. For ``stripe`` these are subscription period dates;
            for ``dev_override`` they're whatever ``set_plan_override``
            wrote; for ``tester_allowlist`` they're ``granted_at`` and
            ``expires_at``; for ``free`` both are ``None``.
        cancel_at_period_end: only meaningful for ``stripe``. Other
            sources default to ``False``.
        source: ``stripe`` | ``dev_override`` | ``tester_allowlist`` | ``free``.
    """

    plan_id: str
    raw_plan_id: str
    current_period_start: datetime | None
    current_period_end: datetime | None
    cancel_at_period_end: bool
    source: str


def _canonicalize_lookup_key(lookup_key: str) -> str:
    """Strip Stripe billing-period suffix and normalize legacy prefix.

    Stripe lookup_keys look like ``reading_nook_pro_monthly`` or
    ``creativity_nook_pro_annual``. We need ``reading_nook_pro`` /
    ``creative_nook_pro`` (canonical PLAN_LIMITS keys). Mirrors the
    parse done in ``api/v1/billing._parse_lookup_key`` but kept local
    here to avoid a service → API import.
    """
    base = lookup_key.removesuffix("_monthly").removesuffix("_annual")
    return {"creativity_nook_pro": "creative_nook_pro"}.get(base, base)


async def _lookup_user_email(db: AsyncSession, user_id: UUID) -> str | None:
    """Fetch users.email by internal user id. None if user row is missing."""
    row = await db.execute(
        text("SELECT email FROM users WHERE id = :uid LIMIT 1"),
        {"uid": str(user_id)},
    )
    result = row.fetchone()
    return result[0] if result else None


async def get_effective_plan(
    db: AsyncSession,
    user_id: UUID,
    email: str | None = None,
) -> EffectivePlan:
    """Resolve a user's entitlement across all three storage paths.

    Resolution order (highest precedence first):
      1. ``subscriptions`` ⋈ ``stripe_customers`` — real Stripe-paying
         customer. Only ``status='active'`` rows.
      2. ``user_subscriptions`` (dev/admin override via
         ``set_plan_override``). Only ``status='active'`` rows.
      3. ``tester_allowlist`` (Item 11 Internal Alpha pathway). Active =
         ``revoked_at IS NULL AND expires_at > NOW()``. Lookup uses the
         caller-provided ``email`` if present, else ``users.email`` for
         the given user_id.
      4. Free.

    The first match wins — when a tester later subscribes via Stripe,
    the Stripe row supersedes the allowlist automatically without
    requiring the allowlist row to be revoked.

    ``email`` is taken when the caller has a fresher source than
    ``users.email`` (typically the JWT ``TokenClaims.email``). Auto-
    provisioned users may have a synthetic ``<uuid>@auth0.local``
    placeholder in ``users.email`` (Apr 27 Key Learning) — passing the
    JWT email avoids a benign allowlist miss in that window.
    """
    # 1. Stripe — highest precedence
    row = await db.execute(
        text(
            """
            SELECT s.lookup_key, s.current_period_start,
                   s.current_period_end, s.cancel_at_period_end
            FROM subscriptions s
            JOIN stripe_customers sc ON sc.id = s.stripe_customer_id
            WHERE sc.user_id = :uid AND s.status = 'active'
            ORDER BY s.created_at DESC LIMIT 1
            """
        ),
        {"uid": str(user_id)},
    )
    sub = row.mappings().first()
    if sub:
        canonical = _canonicalize_lookup_key(sub["lookup_key"])
        return EffectivePlan(
            plan_id=canonical,
            raw_plan_id=sub["lookup_key"],
            current_period_start=sub["current_period_start"],
            current_period_end=sub["current_period_end"],
            cancel_at_period_end=bool(sub["cancel_at_period_end"]),
            source="stripe",
        )

    # 2. Dev/admin override
    row = await db.execute(
        text(
            """
            SELECT plan_id, current_period_start, current_period_end
            FROM user_subscriptions
            WHERE user_id = :uid AND status = 'active'
            ORDER BY created_at DESC LIMIT 1
            """
        ),
        {"uid": str(user_id)},
    )
    dev = row.mappings().first()
    if dev:
        canonical = _normalize_plan_id(dev["plan_id"])
        return EffectivePlan(
            plan_id=canonical,
            raw_plan_id=dev["plan_id"],
            current_period_start=dev["current_period_start"],
            current_period_end=dev["current_period_end"],
            cancel_at_period_end=False,
            source="dev_override",
        )

    # 3. Tester allowlist
    # JWT email claim may be empty string (not None) for Cognito
    # auto-provisioned users — TokenClaims.email defaults to "" when
    # the access token omits the email claim, so callers pass "" not
    # None for those sessions. Treat empty as missing so the
    # users.email fallback fires; otherwise allowlist lookup is
    # silently skipped for every alpha tester whose JWT lacks the
    # claim. Discovered during T11.3b visual smoke.
    if not email:
        email = await _lookup_user_email(db, user_id)
    if email:
        entry = await check_allowlist_entitlement(db, email)
        if entry:
            return EffectivePlan(
                plan_id=_normalize_plan_id(entry.plan_id),
                raw_plan_id=entry.plan_id,
                current_period_start=entry.granted_at,
                current_period_end=entry.expires_at,
                cancel_at_period_end=False,
                source="tester_allowlist",
            )

    # 4. Free
    return EffectivePlan(
        plan_id="free",
        raw_plan_id="free",
        current_period_start=None,
        current_period_end=None,
        cancel_at_period_end=False,
        source="free",
    )


async def _get_active_plan_id(db: AsyncSession, user_id: UUID) -> str:
    """Return the user's current raw plan id (legacy shape, default 'free').

    Thin wrapper around ``get_effective_plan`` preserved for callers
    that only need the plan id string. New code should call
    ``get_effective_plan`` directly so all five entitlement fields are
    available without re-resolution.
    """
    plan = await get_effective_plan(db, user_id)
    return plan.raw_plan_id


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

    Thin wrapper around ``get_effective_plan`` preserved for legacy
    callers. The resolver covers all three entitlement sources
    (Stripe subscriptions, user_subscriptions dev_override,
    tester_allowlist) with the same precedence order.
    """
    plan = await get_effective_plan(db, user_id)
    return plan.current_period_start


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

    Single resolver call (down from 2 in the pre-T11.2 implementation
    that delegated to ``_get_active_plan_id`` + ``_get_active_period_start``
    independently). Net DB read reduction in tts_router synthesize path:
    3 → 2 per call.
    """
    plan = await get_effective_plan(db, user_id)
    limits = get_plan_limits(plan.plan_id)
    chars_limit = limits.el_chars_per_period

    if plan.current_period_start is None:
        return (0, chars_limit, datetime.now(UTC))

    row = await db.execute(
        text(
            """
            SELECT chars_consumed FROM el_usage_counters
            WHERE user_id = :uid AND period_start = :ps
            """
        ),
        {"uid": str(user_id), "ps": plan.current_period_start},
    )
    result = row.fetchone()
    chars_used = result[0] if result else 0
    return (chars_used, chars_limit, plan.current_period_start)


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


# ── LLM token quota (migration 023) ──────────────────────────────────────────

async def check_llm_quota(
    db: AsyncSession, user_id: UUID
) -> tuple[int, int, datetime, datetime | None]:
    """Return (tokens_used, tokens_limit, period_start, period_end) for this user.

    Pure read — does not raise, does not mutate. Caller decides whether
    to hard-stop the LLM feature based on the returned values.

    Free and Reading Nook users get limit=0 (no LLM access). Writing
    Nook gets 1,000,000; Creative Nook gets 2,000,000.

    period_start/period_end default to NOW()/None when no active subscription
    row exists; in that case limit is also 0 so the values are never used to
    key a counter row. Mirrors check_el_quota() exactly — same period
    source (billing anniversary via get_effective_plan), same plan
    resolution path.
    """
    plan = await get_effective_plan(db, user_id)
    limits = get_plan_limits(plan.plan_id)
    tokens_limit = limits.llm_tokens_per_period

    if plan.current_period_start is None:
        return (0, tokens_limit, datetime.now(UTC), None)

    row = await db.execute(
        text(
            """
            SELECT tokens_consumed FROM llm_usage_counters
            WHERE user_id = :uid AND period_start = :ps
            """
        ),
        {"uid": str(user_id), "ps": plan.current_period_start},
    )
    result = row.fetchone()
    tokens_used = result[0] if result else 0
    return (tokens_used, tokens_limit, plan.current_period_start, plan.current_period_end)


async def increment_llm_tokens(
    db: AsyncSession,
    user_id: UUID,
    period_start: datetime,
    delta: int,
) -> None:
    """Atomically increment LLM tokens consumed for (user_id, period_start).

    Insert-or-update on the unique (user_id, period_start) constraint
    from migration 023. Race-safe: PostgreSQL serialises the UPDATE
    under the unique constraint so concurrent calls from multiple
    requests accumulate correctly without lost updates. Commits on
    success. Mirrors increment_el_chars() exactly.
    """
    if delta <= 0:
        return
    await db.execute(
        text(
            """
            INSERT INTO llm_usage_counters
                (user_id, period_start, tokens_consumed, created_at, updated_at)
            VALUES (:uid, :ps, :delta, NOW(), NOW())
            ON CONFLICT (user_id, period_start) DO UPDATE
            SET tokens_consumed = llm_usage_counters.tokens_consumed + EXCLUDED.tokens_consumed,
                updated_at = NOW()
            """
        ),
        {"uid": str(user_id), "ps": period_start, "delta": delta},
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

    # ElevenLabs char usage for the current billing period (C.3 endpoint
    # extension). check_el_quota's UNION lookup picks the correct period
    # (subscriptions preferred, user_subscriptions fallback) so el_used
    # reflects the current period even mid-rollover.
    el_used, el_limit, _el_period_start = await check_el_quota(db, user_id)

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

    # v1.1 cleanup: consolidate period_start resolution with
    # _get_active_period_start UNION pattern from check_el_quota so the
    # endpoint's reset_at always agrees with the row that backs the
    # quota counter for Stripe-paying users mid-rollover.
    el_reset_at = sub[5].isoformat() if sub and sub[5] else None

    return {
        "plan_id": plan_info["plan_id"],
        "limits": plan_info["limits"],
        "usage": {
            "docs_this_month": monthly_used,
            "docs_limit": limit,
            "docs_remaining": max(0, limit - monthly_used) if limit != -1 else None,
            "el_chars_used": el_used,
            "el_chars_limit": el_limit,
            "el_chars_remaining": max(0, el_limit - el_used),
            "el_chars_reset_at": el_reset_at,
        },
        "subscription": {
            "id": str(sub[0]) if sub else None,
            "status": sub[2] if sub else "none",
            "started_at": sub[3].isoformat() if sub and sub[3] else None,
            "period_end": sub[5].isoformat() if sub and sub[5] else None,
            "stripe_active": sub[6] is not None if sub else False,
        },
    }
