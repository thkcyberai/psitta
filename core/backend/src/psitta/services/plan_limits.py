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
    """Feature gates and usage quotas for a subscription plan."""

    documents_per_month: int
    tts_minutes_per_month: int
    audio_cache_days: int
    voices: str | list[str]  # "all" or explicit list
    max_playback_speed: float
    word_highlight: bool
    download_docx: bool
    creativity_nooks: int = 0


PLAN_LIMITS: dict[str, PlanLimits] = {
    "free": PlanLimits(
        documents_per_month=3,
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
    ),
    "reading_nook_pro": PlanLimits(
        documents_per_month=50,
        tts_minutes_per_month=600,
        audio_cache_days=90,
        voices="all",
        max_playback_speed=4.0,
        word_highlight=True,
        download_docx=True,
    ),
    "creativity_nook_pro": PlanLimits(
        documents_per_month=50,
        tts_minutes_per_month=600,
        audio_cache_days=90,
        voices="all",
        max_playback_speed=4.0,
        word_highlight=True,
        download_docx=True,
        creativity_nooks=4,
    ),
}


def get_plan_limits(plan: str) -> PlanLimits:
    """Return limits for the given plan, defaulting to free."""
    return PLAN_LIMITS.get(plan, PLAN_LIMITS["free"])


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
