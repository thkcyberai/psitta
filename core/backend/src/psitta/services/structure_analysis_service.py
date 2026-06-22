"""services/structure_analysis_service.py — whole-manuscript Structure Analyzer.

Orchestrates project-narrative + manuscript fetch → quota pre-check → LLM call →
quota increment → privacy-safe audit for POST /projects/{id}/narrative/analyze.

Mirrors narrative_coach_service: same OpenAI provider, same per-tier LLM token
quota (plan_limits.llm_tokens_per_period), same 403 (not in plan) / 402 (quota
exhausted) gating. Where the coach judges one passage on save, this judges the
whole manuscript on demand.

PRIVACY: the manuscript is sent to the LLM for analysis but is NEVER written to
logs or the audit trail. Only per-beat status counts and token counts are
recorded.
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

# Bound the manuscript sent to the model so a long book can't blow the token
# budget on a single run. ~30k chars ≈ 7-8k tokens.
_MAX_MANUSCRIPT_CHARS = 30_000


async def analyze_structure_with_quota(
    db: AsyncSession,
    user_id: UUID,
    project_id: UUID,
    provider: LlmOpenAIProvider | None = None,
) -> dict:
    """Analyze a project's whole manuscript against its narrative beats.

    Raises:
        HTTPException 404 if the project is not found or not owned by user.
        HTTPException 422 if the project has no narrative attached, or has no
            written text to analyze.
        HTTPException 403 (llm_not_in_plan) if the plan has no LLM access.
        HTTPException 402 (llm_quota_exceeded) if entitled but quota exhausted.
        HTTPException 503 if the LLM provider call fails.
    """
    # ── 1. Project narrative (ownership + existence guard) ───────────────────
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
            status_code=status.HTTP_404_NOT_FOUND, detail="Project not found"
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
                    "This book has no narrative to analyze against yet. Choose "
                    "a structure in Blueprints → Narrative Structure and attach "
                    "it to the project first."
                ),
            },
        )

    # ── 2. Assemble the manuscript from the project's documents ──────────────
    chunk_rows = await db.execute(
        text(
            """
            SELECT d.title AS title, dc.text_content AS text_content
            FROM documents d
            JOIN document_chunks dc ON dc.document_id = d.id
            WHERE d.project_id = :pid AND d.status != 'deleted'
            ORDER BY d.created_at, dc.sequence_index
            """
        ),
        {"pid": str(project_id)},
    )
    parts: list[str] = []
    current_title: str | None = None
    for r in chunk_rows.mappings():
        title = r["title"] or "Untitled"
        if title != current_title:
            parts.append(f"\n\n## {title}\n")
            current_title = title
        parts.append((r["text_content"] or "").strip())
    manuscript = "\n".join(p for p in parts if p).strip()

    if not manuscript:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="This book has no written text to analyze yet.",
        )

    truncated = len(manuscript) > _MAX_MANUSCRIPT_CHARS
    manuscript = manuscript[:_MAX_MANUSCRIPT_CHARS]

    # ── 3. Quota pre-check ───────────────────────────────────────────────────
    tokens_used, tokens_limit, period_start, period_end = await check_llm_quota(
        db, user_id
    )

    if tokens_limit == 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error": "llm_not_in_plan",
                "message": (
                    "Structure Analyzer is not available on your current plan. "
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

    # ── 4. Call LLM provider ─────────────────────────────────────────────────
    if provider is None:
        provider = LlmOpenAIProvider()

    structure_name = _structure_display_name(structure_key)

    try:
        analysis, prompt_tokens, completion_tokens = await provider.analyze_structure(
            structure_name=structure_name,
            variant=variant,
            beats=beats,
            manuscript=manuscript,
        )
    except LlmProviderError as exc:
        logger.error(
            "structure_analysis.provider_error",
            error=str(exc),
            project_id=str(project_id),
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Structure Analyzer is temporarily unavailable. Please try again later.",
        ) from exc

    total_tokens = prompt_tokens + completion_tokens

    # ── 5. Post-increment quota ──────────────────────────────────────────────
    if total_tokens > 0:
        await increment_llm_tokens(db, user_id, period_start, total_tokens)

    # ── 6. Audit (status counts + tokens only — NO manuscript, NO notes) ─────
    beats_out = analysis.get("beats") or []
    status_counts: dict[str, int] = {"present": 0, "thin": 0, "missing": 0}
    for b in beats_out:
        st = (b.get("status") or "").lower()
        if st in status_counts:
            status_counts[st] += 1

    await audit_service.log_event(
        db,
        action="project.structure_analyzed",
        resource_type="project",
        user_id=str(user_id),
        resource_id=str(project_id),
        details={
            "status_counts": status_counts,
            "beats_analyzed": len(beats_out),
            "manuscript_chars": len(manuscript),
            "truncated": truncated,
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
        },
    )

    logger.info(
        "structure_analysis.ok",
        project_id=str(project_id),
        status_counts=status_counts,
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        tokens_remaining=max(0, tokens_limit - tokens_used - total_tokens),
    )

    return {
        "overall": analysis.get("overall", "") or "",
        "beats": beats_out,
        "tokens_used_this_request": total_tokens,
        "tokens_used_period": tokens_used + total_tokens,
        "tokens_limit_period": tokens_limit,
    }


def _structure_display_name(key: str) -> str:
    """Prettify a stored structure key into a human label for the prompt."""
    return " ".join(w.capitalize() for w in key.split("_") if w) or key
