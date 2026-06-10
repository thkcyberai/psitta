"""Unit tests for llm_service.summarize_with_quota (WD-B1).

Tests orchestration logic — document fetch, quota pre-check, provider call,
token increment, and audit log — using mocks and a minimal fake DB.
No live DB or OpenAI calls are made.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import ANY, AsyncMock, patch
from uuid import uuid4

import pytest
from fastapi import HTTPException

from psitta.services.llm_service import summarize_with_quota


# ── Minimal fake DB for document fetch ───────────────────────────────────────


class _FakeResult:
    def __init__(self, row: Any = None):
        self._row = row

    def fetchone(self) -> Any:
        return self._row


class FakeDb:
    """AsyncSession stub that returns a fixed document row on document SELECT."""

    def __init__(self, doc_row: Any = None):
        self._doc_row = doc_row
        self.commit = AsyncMock()

    async def execute(self, stmt: Any, params: Any = None) -> _FakeResult:
        sql = str(stmt)
        if "text_content FROM documents" in sql:
            return _FakeResult(row=self._doc_row)
        return _FakeResult(row=None)


def _fake_db(
    title: str = "My Document",
    text: str = "Some meaningful content here.",
) -> FakeDb:
    return FakeDb(doc_row=(title, text))


def _now() -> datetime:
    return datetime.now(UTC)


# ── Test: successful summarization ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_success_returns_summary():
    """Happy path: provider returns summary, result dict is correct."""
    user_id = uuid4()
    document_id = uuid4()
    period_start = _now() - timedelta(days=5)

    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("A great summary.", 300, 100)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch("psitta.services.llm_service.increment_llm_tokens", new_callable=AsyncMock),
        patch("psitta.services.audit_service.log_event", new_callable=AsyncMock),
    ):
        result = await summarize_with_quota(
            db=_fake_db(),
            user_id=user_id,
            document_id=document_id,
            provider=mock_provider,
        )

    assert result["summary"] == "A great summary."
    assert result["tokens_used_this_request"] == 400  # 300 + 100
    assert result["tokens_used_period"] == 400
    assert result["tokens_limit_period"] == 1_000_000
    assert result["document_id"] == str(document_id)


@pytest.mark.asyncio
async def test_summarize_accounts_for_existing_usage_in_period_total():
    """tokens_used_period should be prior usage + this request's tokens."""
    user_id = uuid4()
    document_id = uuid4()
    period_start = _now() - timedelta(days=10)

    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary.", 500, 200)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(100_000, 1_000_000, period_start),  # 100k already used
        ),
        patch("psitta.services.llm_service.increment_llm_tokens", new_callable=AsyncMock),
        patch("psitta.services.audit_service.log_event", new_callable=AsyncMock),
    ):
        result = await summarize_with_quota(
            db=_fake_db(),
            user_id=user_id,
            document_id=document_id,
            provider=mock_provider,
        )

    assert result["tokens_used_period"] == 100_700  # 100_000 + 700


# ── Test: quota increment ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_increments_quota_with_total_tokens():
    """increment_llm_tokens must be called with prompt+completion total."""
    user_id = uuid4()
    document_id = uuid4()
    period_start = _now() - timedelta(days=3)
    db = _fake_db()

    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary text.", 500, 200)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch(
            "psitta.services.llm_service.increment_llm_tokens",
            new_callable=AsyncMock,
        ) as mock_increment,
        patch("psitta.services.audit_service.log_event", new_callable=AsyncMock),
    ):
        await summarize_with_quota(
            db=db,
            user_id=user_id,
            document_id=document_id,
            provider=mock_provider,
        )

    mock_increment.assert_awaited_once_with(db, user_id, period_start, 700)


@pytest.mark.asyncio
async def test_summarize_skips_increment_when_total_tokens_is_zero():
    """If provider returns zero tokens, increment is skipped (mirrors EL guard)."""
    user_id = uuid4()
    document_id = uuid4()
    period_start = _now() - timedelta(days=1)

    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary.", 0, 0)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch(
            "psitta.services.llm_service.increment_llm_tokens",
            new_callable=AsyncMock,
        ) as mock_increment,
        patch("psitta.services.audit_service.log_event", new_callable=AsyncMock),
    ):
        await summarize_with_quota(
            db=_fake_db(),
            user_id=user_id,
            document_id=document_id,
            provider=mock_provider,
        )

    mock_increment.assert_not_awaited()


# ── Test: audit log ───────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_calls_audit_log_with_correct_fields():
    user_id = uuid4()
    document_id = uuid4()
    period_start = _now() - timedelta(days=1)

    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary.", 200, 50)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 2_000_000, period_start),
        ),
        patch("psitta.services.llm_service.increment_llm_tokens", new_callable=AsyncMock),
        patch(
            "psitta.services.audit_service.log_event",
            new_callable=AsyncMock,
        ) as mock_audit,
    ):
        await summarize_with_quota(
            db=_fake_db(),
            user_id=user_id,
            document_id=document_id,
            provider=mock_provider,
        )

    mock_audit.assert_awaited_once()
    kw = mock_audit.call_args.kwargs
    assert kw["action"] == "document.summarized"
    assert kw["resource_type"] == "document"
    assert kw["resource_id"] == str(document_id)
    assert kw["user_id"] == str(user_id)
    assert kw["details"]["total_tokens"] == 250
    assert kw["details"]["prompt_tokens"] == 200
    assert kw["details"]["completion_tokens"] == 50


# ── Test: 404 — document not found ───────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_raises_404_when_doc_not_found():
    db = FakeDb(doc_row=None)
    with pytest.raises(HTTPException) as exc_info:
        await summarize_with_quota(
            db=db,
            user_id=uuid4(),
            document_id=uuid4(),
        )
    assert exc_info.value.status_code == 404


# ── Test: 422 — no text content ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_raises_422_when_doc_has_no_text():
    with pytest.raises(HTTPException) as exc_info:
        await summarize_with_quota(
            db=_fake_db(text=""),
            user_id=uuid4(),
            document_id=uuid4(),
        )
    assert exc_info.value.status_code == 422


@pytest.mark.asyncio
async def test_summarize_raises_422_when_doc_text_is_whitespace_only():
    with pytest.raises(HTTPException) as exc_info:
        await summarize_with_quota(
            db=_fake_db(text="   \n\t  "),
            user_id=uuid4(),
            document_id=uuid4(),
        )
    assert exc_info.value.status_code == 422


# ── Test: 402 — plan has no LLM access ───────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_raises_402_for_free_plan():
    """Free plan: tokens_limit=0 → upgrade message."""
    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 0, _now()),
        ),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await summarize_with_quota(
                db=_fake_db(),
                user_id=uuid4(),
                document_id=uuid4(),
            )

    assert exc_info.value.status_code == 402
    detail = exc_info.value.detail
    assert detail["tokens_limit"] == 0
    assert "upgrade" in detail["message"].lower()


@pytest.mark.asyncio
async def test_summarize_raises_402_for_reading_nook_plan():
    """Reading Nook Pro: EL access but no LLM (limit=0)."""
    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 0, _now()),
        ),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await summarize_with_quota(
                db=_fake_db(),
                user_id=uuid4(),
                document_id=uuid4(),
            )

    assert exc_info.value.status_code == 402


# ── Test: 402 — quota exhausted ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_raises_402_when_quota_at_limit():
    period_start = _now() - timedelta(days=10)
    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(1_000_000, 1_000_000, period_start),
        ),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await summarize_with_quota(
                db=_fake_db(),
                user_id=uuid4(),
                document_id=uuid4(),
            )

    assert exc_info.value.status_code == 402
    detail = exc_info.value.detail
    assert detail["tokens_used"] == 1_000_000
    assert detail["tokens_limit"] == 1_000_000
    assert "exhausted" in detail["message"].lower()


@pytest.mark.asyncio
async def test_summarize_raises_402_when_quota_over_limit():
    """Over-limit (used > limit) is also blocked."""
    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(1_050_000, 1_000_000, _now()),
        ),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await summarize_with_quota(
                db=_fake_db(),
                user_id=uuid4(),
                document_id=uuid4(),
            )

    assert exc_info.value.status_code == 402


# ── Test: 503 — provider failure ─────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_raises_503_on_provider_error():
    from psitta.providers.llm_openai import LlmProviderError

    period_start = _now() - timedelta(days=2)
    mock_provider = AsyncMock()
    mock_provider.summarize.side_effect = LlmProviderError("Connection timeout")

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch(
            "psitta.services.llm_service.increment_llm_tokens",
            new_callable=AsyncMock,
        ) as mock_increment,
        patch("psitta.services.audit_service.log_event", new_callable=AsyncMock),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await summarize_with_quota(
                db=_fake_db(),
                user_id=uuid4(),
                document_id=uuid4(),
                provider=mock_provider,
            )

    assert exc_info.value.status_code == 503
    # Quota must NOT be incremented on provider failure.
    mock_increment.assert_not_awaited()


# ── Test: text truncation ─────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_summarize_truncates_long_text_to_50k_chars():
    """Documents longer than _MAX_SUMMARIZE_CHARS are truncated before the prompt."""
    period_start = _now() - timedelta(days=1)
    long_text = "x" * 60_000
    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary.", 100, 50)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch("psitta.services.llm_service.increment_llm_tokens", new_callable=AsyncMock),
        patch(
            "psitta.services.audit_service.log_event",
            new_callable=AsyncMock,
        ) as mock_audit,
    ):
        await summarize_with_quota(
            db=_fake_db(text=long_text),
            user_id=uuid4(),
            document_id=uuid4(),
            provider=mock_provider,
        )

    # Provider received exactly 50 000 chars.
    call_kw = mock_provider.summarize.call_args.kwargs
    assert len(call_kw["text"]) == 50_000

    # Audit log records truncated=True.
    audit_details = mock_audit.call_args.kwargs["details"]
    assert audit_details["truncated"] is True


@pytest.mark.asyncio
async def test_summarize_not_truncated_within_limit():
    """Documents within _MAX_SUMMARIZE_CHARS are sent as-is; truncated=False."""
    period_start = _now() - timedelta(days=1)
    short_text = "y" * 1_000
    mock_provider = AsyncMock()
    mock_provider.summarize.return_value = ("Summary.", 50, 20)

    with (
        patch(
            "psitta.services.llm_service.check_llm_quota",
            new_callable=AsyncMock,
            return_value=(0, 1_000_000, period_start),
        ),
        patch("psitta.services.llm_service.increment_llm_tokens", new_callable=AsyncMock),
        patch(
            "psitta.services.audit_service.log_event",
            new_callable=AsyncMock,
        ) as mock_audit,
    ):
        await summarize_with_quota(
            db=_fake_db(text=short_text),
            user_id=uuid4(),
            document_id=uuid4(),
            provider=mock_provider,
        )

    audit_details = mock_audit.call_args.kwargs["details"]
    assert audit_details["truncated"] is False
