"""Unit tests for LLM token quota functions (migration 023).

Mirrors the EL quota test pattern (test_resolver.py RecordingSession)
and validates all requirements from the Half 1 spec:

  - check_llm_quota() returns (tokens_used, tokens_limit, period_start)
  - check_llm_quota() reads llm_tokens_per_period via get_plan_limits()
  - Free → limit 0; Reading Nook → grandfathered upward to Writing
    Nook's 1,000,000 (A4 consolidation, DP-2)
  - Writing Nook → limit 1,000,000; Creative Nook → limit 2,000,000
  - Under-limit increments accumulate; at/over limit reports the cap
  - Period keying matches billing anniversary (subscriptions.period_start)
  - concurrent increments use atomic INSERT ON CONFLICT — SQL verified
  - get_plan_limits("writing_nook_pro") returns correct EL + LLM values

Uses the same RecordingSession fake as test_resolver.py — no live DB.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from psitta.services.plan_limits import PLAN_LIMITS, get_plan_limits
from psitta.services.subscription_service import (
    check_llm_quota,
    increment_llm_tokens,
)

# ── Fake DB scaffolding (identical to test_resolver.py) ─────────────────────


class _FakeResult:
    def __init__(self, row: Any = None):
        self._row = row

    def fetchone(self):
        return self._row

    def mappings(self):
        return self

    def first(self):
        return self._row


class _NoopSavepoint:
    """No-op async context manager modelling AsyncSession.begin_nested().

    get_effective_plan (reached here via check_llm_quota -> get_user_plan)
    wraps each entitlement lookup in a SAVEPOINT so a failure can't poison
    the request transaction. The fake session has no real transaction, so
    its savepoint just runs the body.
    """

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class RecordingSession:
    """AsyncSession stand-in keyed by SQL substring matching.

    First matching key wins. Records all (sql, params) pairs so tests
    can assert on issued SQL and bound parameters.
    """

    def __init__(self, result_map: dict[str, _FakeResult] | None = None):
        self._result_map = result_map or {}
        self.calls: list[tuple[str, dict]] = []
        self.commit = AsyncMock()

    def begin_nested(self):
        return _NoopSavepoint()

    async def execute(self, stmt: Any, params: Any = None):
        sql = str(stmt)
        self.calls.append((sql, dict(params or {})))
        for key, result in self._result_map.items():
            if key in sql:
                return result
        return _FakeResult(row=None)


def _now() -> datetime:
    return datetime.now(UTC)


# ── SQL substring keys ────────────────────────────────────────────────────────

SQL_STRIPE = "JOIN stripe_customers"
SQL_DEV = "FROM user_subscriptions"
SQL_ALLOWLIST = "FROM tester_allowlist"
SQL_LLM_READ = "FROM llm_usage_counters"
SQL_LLM_WRITE = "INTO llm_usage_counters"


# ── Helpers ──────────────────────────────────────────────────────────────────


def _stripe_row(
    lookup_key: str = "writing_nook_pro_monthly",
    days_into_period: int = 5,
    period_length: int = 30,
) -> dict:
    period_start = _now() - timedelta(days=days_into_period)
    period_end = period_start + timedelta(days=period_length)
    return {
        "lookup_key": lookup_key,
        "status": "active",
        "current_period_start": period_start,
        "current_period_end": period_end,
        "cancel_at_period_end": False,
    }


# ── 1. Plan limit values ──────────────────────────────────────────────────────


class TestLlmPlanLimitValues:
    """PLAN_LIMITS must carry correct llm_tokens_per_period per tier."""

    def test_free_llm_limit_is_zero(self):
        assert get_plan_limits("free").llm_tokens_per_period == 0

    def test_reading_nook_grandfathers_to_writing_llm_limit(self):
        # A4 consolidation: reading_nook_pro normalizes upward to
        # writing_nook_pro (DP-2), so grandfathered Reading customers
        # gain the full Writing Nook LLM allowance.
        assert (
            get_plan_limits("reading_nook_pro").llm_tokens_per_period
            == 1_000_000
        )

    def test_writing_nook_llm_limit_is_one_million(self):
        assert get_plan_limits("writing_nook_pro").llm_tokens_per_period == 1_000_000

    def test_creative_nook_llm_limit_is_two_million(self):
        assert get_plan_limits("creative_nook_pro").llm_tokens_per_period == 2_000_000

    def test_writing_nook_el_limit_is_250k(self):
        """Requirement F: writing_nook_pro EL chars confirmed alongside LLM."""
        assert get_plan_limits("writing_nook_pro").el_chars_per_period == 250_000

    def test_writing_nook_canonical_key_resolves(self):
        """writing_nook_pro is a direct PLAN_LIMITS key."""
        assert get_plan_limits("writing_nook_pro") is PLAN_LIMITS["writing_nook_pro"]

    def test_legacy_pro_monthly_grandfathers_to_writing(self):
        """A4 consolidation: the legacy Reading ENUM values resolve
        upward to Writing Nook (DP-2)."""
        assert get_plan_limits("pro_monthly") is PLAN_LIMITS["writing_nook_pro"]


# ── 2. check_llm_quota — no counter row yet ───────────────────────────────────


@pytest.mark.asyncio
async def test_check_llm_quota_no_row_returns_zero_used():
    """First call for a new period returns (0, limit, period_start)."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=3)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "writing_nook_pro_monthly",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=27),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=None),
    })

    used, limit, ps, _pe = await check_llm_quota(db, user_id)

    assert used == 0
    assert limit == 1_000_000
    assert ps == period_start


@pytest.mark.asyncio
async def test_check_llm_quota_existing_counter_row_returns_used():
    """Counter row present → returns its tokens_consumed value."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=10)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "writing_nook_pro_monthly",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=20),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=(350_000,)),
    })

    used, limit, ps, _pe = await check_llm_quota(db, user_id)

    assert used == 350_000
    assert limit == 1_000_000
    assert ps == period_start


# ── 3. check_llm_quota — Free limit 0 / Reading grandfathered upward ─────────


@pytest.mark.asyncio
async def test_check_llm_quota_free_plan_limit_is_zero():
    """Free plan: limit=0, no counter row needed."""
    user_id = uuid4()
    db = RecordingSession()  # all queries return empty → resolves to free

    used, limit, ps, _pe = await check_llm_quota(db, user_id)

    assert limit == 0
    assert used == 0
    # period_start is NOW() fallback when no active subscription
    assert ps is not None


@pytest.mark.asyncio
async def test_check_llm_quota_reading_nook_grandfathers_to_writing():
    """A4 consolidation: a historical Reading Nook Stripe subscription
    now resolves to writing_nook_pro (DP-2 grandfathered upward), so
    the customer receives the full Writing Nook LLM allowance instead
    of the retired tier's limit=0."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=2)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "reading_nook_pro_monthly",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=28),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=None),
    })

    used, limit, _, _pe = await check_llm_quota(db, user_id)

    assert limit == 1_000_000
    assert used == 0


@pytest.mark.asyncio
async def test_check_llm_quota_creative_nook_limit_is_two_million():
    """Creative Nook Pro: tokens_limit=2,000,000."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=1)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "creative_nook_pro_monthly",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=29),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=None),
    })

    used, limit, _, _pe = await check_llm_quota(db, user_id)

    assert limit == 2_000_000


# ── 4. check_llm_quota — at/over limit ───────────────────────────────────────


@pytest.mark.asyncio
async def test_check_llm_quota_at_limit_reports_cap():
    """When tokens_consumed == limit, (used==limit) is returned.

    Caller is responsible for the hard-stop; check_llm_quota itself is
    a pure read and never raises.
    """
    user_id = uuid4()
    period_start = _now() - timedelta(days=5)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "writing_nook_pro_annual",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=360),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=(1_000_000,)),
    })

    used, limit, _, _pe = await check_llm_quota(db, user_id)

    assert used == 1_000_000
    assert limit == 1_000_000
    assert used >= limit  # caller sees this and hard-stops


@pytest.mark.asyncio
async def test_check_llm_quota_over_limit_reports_true_consumed():
    """Overage (used > limit) is reported as-is — no clamping."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=2)
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "writing_nook_pro_monthly",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=28),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=(1_050_000,)),
    })

    used, limit, _, _pe = await check_llm_quota(db, user_id)

    assert used == 1_050_000
    assert limit == 1_000_000


# ── 5. check_llm_quota — period keying ───────────────────────────────────────


@pytest.mark.asyncio
async def test_check_llm_quota_passes_billing_anniversary_period_start_to_query():
    """The period_start bound to the llm_usage_counters query must be the
    billing-anniversary date from the subscription, not calendar month."""
    user_id = uuid4()
    period_start = datetime(2026, 4, 17, 0, 0, 0, tzinfo=UTC)  # billing date
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            row={
                "lookup_key": "writing_nook_pro_annual",
                "status": "active",
                "current_period_start": period_start,
                "current_period_end": period_start + timedelta(days=365),
                "cancel_at_period_end": False,
            }
        ),
        SQL_LLM_READ: _FakeResult(row=None),
    })

    _, _, returned_ps, _pe = await check_llm_quota(db, user_id)

    assert returned_ps == period_start
    # Confirm the llm_usage_counters SELECT was bound with this exact date.
    llm_calls = [
        params for sql, params in db.calls if SQL_LLM_READ in sql
    ]
    assert llm_calls, "llm_usage_counters SELECT was not issued"
    assert llm_calls[0]["ps"] == period_start


# ── 6. increment_llm_tokens — accumulation ───────────────────────────────────


@pytest.mark.asyncio
async def test_increment_llm_tokens_issues_upsert_sql():
    """increment_llm_tokens must issue the atomic INSERT ON CONFLICT upsert."""
    user_id = uuid4()
    period_start = _now() - timedelta(days=1)
    db = RecordingSession()

    await increment_llm_tokens(db, user_id, period_start, 5_000)

    write_calls = [sql for sql, _ in db.calls if SQL_LLM_WRITE in sql]
    assert write_calls, "INSERT INTO llm_usage_counters was not issued"
    sql = write_calls[0]
    # ON CONFLICT clause is the atomicity guarantee — assert it is present.
    assert "ON CONFLICT" in sql
    assert "DO UPDATE" in sql
    assert "tokens_consumed" in sql
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_increment_llm_tokens_binds_correct_params():
    """Bound parameters must include uid, ps, and delta."""
    user_id = uuid4()
    period_start = datetime(2026, 5, 1, 0, 0, 0, tzinfo=UTC)
    db = RecordingSession()

    await increment_llm_tokens(db, user_id, period_start, 12_345)

    write_params = [
        params for sql, params in db.calls if SQL_LLM_WRITE in sql
    ]
    assert write_params
    p = write_params[0]
    assert p["uid"] == str(user_id)
    assert p["ps"] == period_start
    assert p["delta"] == 12_345


@pytest.mark.asyncio
async def test_increment_llm_tokens_zero_delta_is_no_op():
    """delta=0 must not write to the DB (mirrors increment_el_chars guard)."""
    user_id = uuid4()
    db = RecordingSession()

    await increment_llm_tokens(db, user_id, _now(), 0)

    assert not db.calls
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_increment_llm_tokens_negative_delta_is_no_op():
    """Negative delta is silently ignored — no negative rollback possible."""
    user_id = uuid4()
    db = RecordingSession()

    await increment_llm_tokens(db, user_id, _now(), -100)

    assert not db.calls
    db.commit.assert_not_awaited()


# ── 7. Concurrent-safety: SQL shape ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_increment_llm_tokens_atomic_upsert_accumulates_correctly():
    """Two sequential increments must both commit via the upsert path.

    The INSERT ON CONFLICT DO UPDATE SET tokens_consumed = ... + EXCLUDED...
    pattern is what makes concurrent Postgres calls race-safe. This test
    verifies the SQL shape is correct (both calls use the upsert) and that
    commit is called exactly twice — once per increment.
    """
    user_id = uuid4()
    period_start = _now() - timedelta(days=3)
    db = RecordingSession()

    await increment_llm_tokens(db, user_id, period_start, 100_000)
    await increment_llm_tokens(db, user_id, period_start, 200_000)

    write_calls = [sql for sql, _ in db.calls if SQL_LLM_WRITE in sql]
    assert len(write_calls) == 2
    for sql in write_calls:
        assert "ON CONFLICT" in sql
        assert "DO UPDATE" in sql
    assert db.commit.await_count == 2


# ── 8. Writing Nook tier definition (Requirement F) ──────────────────────────


class TestWritingNookTierDefinition:
    """Locks in the writing_nook_pro PlanLimits entry."""

    def test_el_chars_per_period(self):
        assert get_plan_limits("writing_nook_pro").el_chars_per_period == 250_000

    def test_llm_tokens_per_period(self):
        assert get_plan_limits("writing_nook_pro").llm_tokens_per_period == 1_000_000

    def test_voices_is_all(self):
        assert get_plan_limits("writing_nook_pro").voices == "all"

    def test_word_highlight_enabled(self):
        assert get_plan_limits("writing_nook_pro").word_highlight is True

    def test_can_edit_docx(self):
        assert get_plan_limits("writing_nook_pro").can_edit_docx is True

    def test_monthly_upload_limit(self):
        assert get_plan_limits("writing_nook_pro").monthly_upload_limit == 50

    def test_is_direct_plan_limits_key(self):
        assert get_plan_limits("writing_nook_pro") is PLAN_LIMITS["writing_nook_pro"]
