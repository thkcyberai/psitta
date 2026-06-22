"""services/narrative_coach_service.py — AI Story-Coach deviation check.

Orchestrates project-narrative fetch → quota pre-check → LLM call → quota
increment → privacy-safe audit for POST /projects/{id}/narrative/check.

Mirrors llm_service.summarize_with_quota, sharing the same OpenAI provider,
the same per-tier LLM token quota (plan_limits.llm_tokens_per_period), and the
same 403 (not in plan) / 402 (quota exhausted) gating.

PRIVACY: the writer's passage is sent to the LLM provider for judging but is
NEVER written to logs or the audit trail. Only token counts and the boolean
verdict are recorded.
"""

from __future__ import annotations

from uuid import UUID

import structlog
from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.providers.llm_openai import LlmOpenAIProvider, LlmProviderError
from psitta.services import audit_service
from psitta.services.subscription_service import check_llm_quota, increment_llm_tokens

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# Defensive bound — a coaching check looks at the passage in flight, not a whole
# manuscript. Keeps token cost and latency predictable.
_MAX_PASSAGE_CHARS = 8_000


async def check_narrative_with_quota(
    db: AsyncSession,
    user_id: UUID,
    project_id: UUID,
    passage: str,
    beat_index: int | None = None,
    provider: LlmOpenAIProvider | None = None,
) -> dict:
    """Judge whether a passage fits the project's committed narrative.

    Args:
        db: Active database session.
        user_id: Authenticated user UUID.
        project_id: Project to check against (must belong to user).
        passage: The text the writer just drafted.
        beat_index: Optional 0-based hint for the beat being written.
        provider: LLM provider instance; defaults to LlmOpenAIProvider().

    Returns:
        Dict with the verdict (aligned, message, suspected_beat) and token
        accounting for the period.

    Raises:
        HTTPException 404 if the project is not found or not owned by user.
        HTTPException 422 if the project has no narrative attached, or the
            passage is empty.
        HTTPException 403 (llm_not_in_plan) if the plan has no LLM access.
        HTTPException 402 (llm_quota_exceeded) if entitled but quota exhausted.
        HTTPException 503 if the LLM provider call fails.
    """
    # ── 1. Fetch project narrative (ownership + existence guard) ─────────────
    result = await db.execute(
        text(
            "SELECT narrative_structure_key, narrative_variant, narrative_beats "
            "FROM projects WHERE id = :pid AND user_id = :uid"
        ),
        {"pid": str(project_id), "uid": str(user_id)},
    )
    row = result.fetchone()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Project not found",
        )

    structure_key: str | None = row[0]
    variant: str | None = row[1]
    beats: list[str] = list(row[2]) if row[2] else []

    if not structure_key or not beats:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": "no_narrative",
                "message": (
                    "This book has no narrative to coach against yet. Choose a "
                    "structure in Blueprints → Narrative Structure and attach "
                    "it to the project first."
                ),
            },
        )

    passage = (passage or "").strip()
    if not passage:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No passage provided to check",
        )

    # ── 2. Quota pre-check ───────────────────────────────────────────────────
    tokens_used, tokens_limit, period_start, period_end = await check_llm_quota(
        db, user_id
    )

    if tokens_limit == 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "llm_not_in_plan",
                "message": (
                    "AI Story-Coaching is not available on your current plan. "
                    "Upgrade to Writing Nook Pro or Creative Nook Pro to unlock."
                ),
                "upgrade_url": "/billing/checkout-session",
            },
        )

    if tokens_used >= tokens_limit:
        reset_str = (
            period_end.strftime("%Y-%m-%d")
            if period_end
            else "your next billing anniversary"
        )
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": "llm_quota_exceeded",
                "message": f"Monthly LLM token quota exhausted. Resets on {reset_str}.",
                "quota": {
                    "tokens_used": tokens_used,
                    "tokens_limit": tokens_limit,
                    "period_start": period_start.isoformat(),
                    "period_end": period_end.isoformat() if period_end else None,
                },
                "upgrade_url": "/billing/checkout-session",
            },
        )

    # ── 3. Resolve display name + call LLM provider ──────────────────────────
    if provider is None:
        provider = LlmOpenAIProvider()

    structure_name = _structure_display_name(structure_key)
    passage_for_prompt = passage[:_MAX_PASSAGE_CHARS]

    try:
        verdict, prompt_tokens, completion_tokens = await provider.check_narrative(
            passage=passage_for_prompt,
            structure_name=structure_name,
            variant=variant,
            beats=beats,
            beat_index=beat_index,
        )
    except LlmProviderError as exc:
        logger.error(
            "narrative_coach.provider_error",
            error=str(exc),
            project_id=str(project_id),
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Story-coaching is temporarily unavailable. Please try again later.",
        ) from exc

    total_tokens = prompt_tokens + completion_tokens

    # ── 4. Post-increment quota ──────────────────────────────────────────────
    if total_tokens > 0:
        await increment_llm_tokens(db, user_id, period_start, total_tokens)

    # ── 5. Audit log (NO passage, NO message text — verdict + counts only) ───
    await audit_service.log_event(
        db,
        action="project.narrative_checked",
        resource_type="project",
        user_id=str(user_id),
        resource_id=str(project_id),
        details={
            "aligned": bool(verdict.get("aligned", True)),
            "beat_index": beat_index,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
            "passage_chars": len(passage),
            "truncated": len(passage) > _MAX_PASSAGE_CHARS,
        },
    )

    logger.info(
        "narrative_coach.ok",
        project_id=str(project_id),
        aligned=bool(verdict.get("aligned", True)),
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        tokens_remaining=max(0, tokens_limit - tokens_used - total_tokens),
    )

    return {
        "aligned": bool(verdict.get("aligned", True)),
        "message": verdict.get("message", "") or "",
        "suspected_beat": verdict.get("suspected_beat", "") or "",
        "tokens_used_this_request": total_tokens,
        "tokens_used_period": tokens_used + total_tokens,
        "tokens_limit_period": tokens_limit,
    }


def _structure_display_name(key: str) -> str:
    """Prettify a stored structure key into a human label for the prompt.

    The client persists a slug (e.g. ``hero_s_journey``). We don't keep the
    structure catalog server-side, so a title-cased slug is sufficient context
    for the LLM (e.g. ``Hero S Journey``). Best-effort only.
    """
    return " ".join(w.capitalize() for w in key.split("_") if w) or key
