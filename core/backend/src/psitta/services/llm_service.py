"""services/llm_service.py — LLM quota-gated summarize orchestrator (WD-B1).

Orchestrates document-fetch → quota pre-check → LLM call → quota increment
→ audit log for the POST /documents/{id}/summarize endpoint.
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

_MAX_SUMMARIZE_CHARS = 50_000


async def summarize_with_quota(
    db: AsyncSession,
    user_id: UUID,
    document_id: UUID,
    provider: LlmOpenAIProvider | None = None,
) -> dict:
    """Summarize a document with LLM quota pre-check and post-increment.

    Args:
        db: Active database session.
        user_id: Authenticated user UUID.
        document_id: Document to summarize (must belong to user).
        provider: LLM provider instance; defaults to LlmOpenAIProvider().

    Returns:
        Dict with summary, token counts, and quota state for the period.

    Raises:
        HTTPException 404 if document not found or not owned by user.
        HTTPException 422 if document has no text content.
        HTTPException 402 if plan has no LLM access or quota is exhausted.
        HTTPException 503 if the LLM provider call fails.
    """
    # ── 1. Fetch document ────────────────────────────────────────────────────
    result = await db.execute(
        text(
            "SELECT title, text_content FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": str(document_id), "uid": str(user_id)},
    )
    row = result.fetchone()
    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document not found",
        )
    doc_title: str = row[0] or "Untitled"
    doc_text: str = row[1] or ""

    if not doc_text.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Document has no text content to summarize",
        )

    # ── 2. Quota pre-check ───────────────────────────────────────────────────
    tokens_used, tokens_limit, period_start = await check_llm_quota(db, user_id)

    if tokens_limit == 0:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "message": (
                    "Summarize-it is not available on your current plan. "
                    "Upgrade to Writing Nook Pro or Creative Nook Pro to unlock."
                ),
                "tokens_used": 0,
                "tokens_limit": 0,
                "upgrade_url": "/billing/checkout-session",
            },
        )

    if tokens_used >= tokens_limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "message": (
                    "Monthly LLM token quota exhausted. "
                    "Your quota resets at the next billing anniversary."
                ),
                "tokens_used": tokens_used,
                "tokens_limit": tokens_limit,
                "period_start": period_start.isoformat(),
                "upgrade_url": "/billing/checkout-session",
            },
        )

    # ── 3. Call LLM provider ─────────────────────────────────────────────────
    if provider is None:
        provider = LlmOpenAIProvider()

    text_for_prompt = doc_text[:_MAX_SUMMARIZE_CHARS]

    try:
        summary, prompt_tokens, completion_tokens = await provider.summarize(
            text=text_for_prompt,
            doc_title=doc_title,
        )
    except LlmProviderError as exc:
        logger.error(
            "llm_service.provider_error",
            error=str(exc),
            document_id=str(document_id),
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Summarize-it is temporarily unavailable. Please try again later.",
        ) from exc

    total_tokens = prompt_tokens + completion_tokens

    # ── 4. Post-increment quota ──────────────────────────────────────────────
    if total_tokens > 0:
        await increment_llm_tokens(db, user_id, period_start, total_tokens)

    # ── 5. Audit log ─────────────────────────────────────────────────────────
    await audit_service.log_event(
        db,
        action="document.summarized",
        resource_type="document",
        user_id=str(user_id),
        resource_id=str(document_id),
        details={
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "total_tokens": total_tokens,
            "truncated": len(doc_text) > _MAX_SUMMARIZE_CHARS,
        },
    )

    logger.info(
        "llm_service.summarize.ok",
        document_id=str(document_id),
        prompt_tokens=prompt_tokens,
        completion_tokens=completion_tokens,
        tokens_remaining=max(0, tokens_limit - tokens_used - total_tokens),
    )

    return {
        "document_id": str(document_id),
        "summary": summary,
        "tokens_used_this_request": total_tokens,
        "tokens_used_period": tokens_used + total_tokens,
        "tokens_limit_period": tokens_limit,
    }
