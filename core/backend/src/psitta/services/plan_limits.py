"""services/plan_limits.py — Stripe-product plan limits and quota checks (M3 B4).

Defines per-plan feature gates and usage quotas for the Stripe billing
model. These map to the Stripe product / lookup_key structure, NOT the
legacy M3a ``subscription_plans`` table or ``rbac.py`` tiers.

Reconciliation: ``rbac.py`` (free/pro/admin) and
``subscription_service.py`` (free/pro_monthly/pro_annual) will be
migrated to this structure once Stripe billing is fully live. Until
then, all three coexist — this file is authoritative for Stripe-gated
features.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from typing import Any
from uuid import UUID

import structlog
from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Plan limit definitions ───────────────────────────────────────────────

@dataclass(frozen=True)
class PlanLimits:
    """Feature gates and usage quotas for a subscription plan.

    Beta-readiness note: ``monthly_upload_limit`` and ``can_edit_docx``
    are the authoritative flags the M3 upload + DOCX-edit routes will
    enforce. ``documents_per_month`` is kept for backwards compat with
    ``check_document_upload_limit`` until that check is migrated.
    """

    documents_per_month: int
    tts_minutes_per_month: int
    audio_cache_days: int
    voices: str | list[str]  # "all" or explicit list
    max_playback_speed: float
    word_highlight: bool
    download_docx: bool
    # Beta enforcement-ready flags (M3).
    can_edit_docx: bool = False
    monthly_upload_limit: int = 0
    # Count of Creative Nooks the plan includes. Held at 0 across all
    # plans for the Beta — no Creative Nook features are shipped yet.
    creative_nooks_limit: int = 0
    # ElevenLabs character allowance per billing period. 0 = no EL
    # access (router degrades to Edge). Populated by C.1, enforced by
    # C.2 (router pre-call check) against the el_usage_counters table.
    el_chars_per_period: int = 0
    # LLM token allowance per billing period. 0 = no LLM feature access
    # (hard stop with notice). Enforced against the llm_usage_counters
    # table (migration 023). Backs Summarize-it (WD-B1) and any future
    # Writing/Creative tier LLM features.
    llm_tokens_per_period: int = 0


PLAN_LIMITS: dict[str, PlanLimits] = {
    "free": PlanLimits(
        documents_per_month=10,
        tts_minutes_per_month=30,
        audio_cache_days=7,
        voices=[
            "edge_tts_default_1",
            "edge_tts_default_2",
            "edge_tts_default_3",
        ],
        max_playback_speed=2.0,
        word_highlight=False,
        download_docx=False,
        can_edit_docx=False,
        monthly_upload_limit=10,
        el_chars_per_period=0,
    ),
    "reading_nook_pro": PlanLimits(
        documents_per_month=50,
        tts_minutes_per_month=600,
        audio_cache_days=90,
        voices="all",
        max_playback_speed=4.0,
        word_highlight=True,
        download_docx=True,
        can_edit_docx=True,
        monthly_upload_limit=50,
        el_chars_per_period=150_000,
        llm_tokens_per_period=0,
    ),
    "writing_nook_pro": PlanLimits(
        documents_per_month=50,
        tts_minutes_per_month=600,
        audio_cache_days=90,
        voices="all",
        max_playback_speed=4.0,
        word_highlight=True,
        download_docx=True,
        can_edit_docx=True,
        monthly_upload_limit=50,
        el_chars_per_period=250_000,
        llm_tokens_per_period=1_000_000,
    ),
    "creative_nook_pro": PlanLimits(
        documents_per_month=50,
        tts_minutes_per_month=600,
        audio_cache_days=90,
        voices="all",
        max_playback_speed=4.0,
        word_highlight=True,
        download_docx=True,
        can_edit_docx=True,
        monthly_upload_limit=50,
        creative_nooks_limit=0,  # Beta — no Creative Nook features built yet
        el_chars_per_period=400_000,
        llm_tokens_per_period=2_000_000,
    ),
}


# Legacy and period-suffixed plan_id aliases. Maps every non-canonical
# string the system might encounter (Postgres user_subscriptions.plan_id
# ENUM values written by the Stripe webhook handler, forward-compat
# Creative Nook period suffixes, the legacy "creativity" prefix
# retained on the Stripe side) onto the canonical PLAN_LIMITS keys.
# Keep in sync with billing_handlers._LOOKUP_KEY_TO_PLAN_ID (write
# side) and api/v1/billing._PLAN_NAME_ALIASES (parse boundary).
_LEGACY_PLAN_ID_ALIASES: dict[str, str] = {
    "pro_monthly": "reading_nook_pro",
    "pro_annual": "reading_nook_pro",
    "creative_pro_monthly": "creative_nook_pro",
    "creative_pro_annual": "creative_nook_pro",
    "creativity_nook_pro": "creative_nook_pro",
}


def _normalize_plan_id(plan: str) -> str:
    """Canonicalize an inbound plan_id string for PLAN_LIMITS lookup.

    Pure function — no logging, no side effects. Returns the canonical
    PLAN_LIMITS key for known legacy/period-suffixed inputs, or the
    cleaned input unchanged when no alias applies (the caller decides
    how to handle unknowns).
    """
    cleaned = plan.strip().lower()
    return _LEGACY_PLAN_ID_ALIASES.get(cleaned, cleaned)


def get_plan_limits(plan: str) -> PlanLimits:
    """Return limits for the given plan, defaulting to free.

    Accepts canonical PLAN_LIMITS keys, the legacy Postgres plan_id
    ENUM values written by the Stripe webhook handler ('pro_monthly',
    'pro_annual'), and forward-compat creative period values. Unknown
    inputs emit a structured warning and fall back to the free tier
    so a typo or future schema drift fails loudly rather than silently.
    """
    canonical = _normalize_plan_id(plan)
    limits = PLAN_LIMITS.get(canonical)
    if limits is None:
        logger.warning(
            "plan_limits.unknown_plan_id",
            plan=plan,
            normalized=canonical,
        )
        return PLAN_LIMITS["free"]
    return limits


def plan_limits_to_dict() -> dict[str, dict[str, Any]]:
    """Serialize all plan limits for the public /billing/plans endpoint."""
    return {name: asdict(limits) for name, limits in PLAN_LIMITS.items()}


# ── Quota checks ─────────────────────────────────────────────────────────

async def check_document_upload_limit(
    user_id: UUID,
    plan: str,
    db: AsyncSession,
) -> None:
    """Raise 403 if the user has exceeded their monthly document upload limit.

    Counts documents uploaded by this user in the current calendar month
    and compares against the plan's ``documents_per_month`` quota.

    Args:
        user_id: The authenticated user's internal UUID.
        plan: Plan name (``"free"``, ``"reading_nook_pro"``, etc.).
        db: Active database session.

    Raises:
        HTTPException 403 if the limit is exceeded.
    """
    limits = get_plan_limits(plan)
    year_month = datetime.now(UTC).strftime("%Y-%m")

    result = await db.execute(
        text(
            "SELECT docs_uploaded FROM usage_counters "
            "WHERE user_id = :user_id AND year_month = :ym"
        ),
        {"user_id": user_id, "ym": year_month},
    )
    row = result.fetchone()
    current_count = row[0] if row else 0

    if current_count >= limits.documents_per_month:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "message": (
                    f"Monthly document limit reached "
                    f"({limits.documents_per_month} documents). "
                    "Upgrade your plan for more."
                ),
                "limit": limits.documents_per_month,
                "used": current_count,
                "upgrade_url": "/billing/checkout-session",
            },
        )
