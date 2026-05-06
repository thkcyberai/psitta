"""Unit tests for subscription_service.get_effective_plan resolver.

Verifies the 4-step entitlement resolution chain:
  1. Stripe (subscriptions ⋈ stripe_customers, status='active')
  2. dev_override (user_subscriptions, status='active')
  3. tester_allowlist (Item 11 — Pattern 3 Internal Alpha pathway)
  4. free

Plus precedence rules: Stripe > dev_override > allowlist > free, and
the email-fallback path (resolver fetches users.email when caller
doesn't pass one).

DB I/O exercised through a recording fake AsyncSession (no live
Postgres) — same RecordingSession pattern as test_billing_handlers
and test_tester_allowlist.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from psitta.services.subscription_service import (
    EffectivePlan,
    get_effective_plan,
)

# ── Fake DB scaffolding (parallels tests/unit/test_tester_allowlist.py) ──


class _FakeResult:
    """SQLAlchemy Result stand-in. Supports .fetchone() and
    .mappings().first()."""

    def __init__(
        self,
        row: Any = None,
        mapping: dict | None = None,
    ):
        self._row = row
        self._mapping = mapping

    def fetchone(self):
        return self._row

    def mappings(self):
        return self

    def first(self):
        return self._mapping


class RecordingSession:
    """AsyncSession stand-in keyed by SQL substring matching.

    Result_map keys are substrings tested against the SQL text. First
    match wins. Calls that don't match any key return an empty result.
    Tests inspect ``self.calls`` to assert on issued SQL and bound
    parameters.
    """

    def __init__(self, result_map: dict[str, _FakeResult] | None = None):
        self._result_map = result_map or {}
        self.calls: list[tuple[str, dict]] = []
        self.commit = AsyncMock()

    async def execute(self, stmt: Any, params: Any = None):
        sql = str(stmt)
        self.calls.append((sql, dict(params or {})))
        for key, result in self._result_map.items():
            if key in sql:
                return result
        return _FakeResult(row=None, mapping=None)


def _now() -> datetime:
    return datetime.now(UTC)


# ── SQL substring keys used to route fake results ───────────────────────

SQL_STRIPE = "JOIN stripe_customers"
SQL_DEV = "FROM user_subscriptions"
SQL_ALLOWLIST = "FROM tester_allowlist"
SQL_USER_EMAIL = "FROM users WHERE id"


# ── Row builders ────────────────────────────────────────────────────────


def _stripe_row(
    lookup_key: str = "reading_nook_pro_monthly",
    period_start: datetime | None = None,
    period_end: datetime | None = None,
    cancel_at_period_end: bool = False,
) -> dict:
    return {
        "lookup_key": lookup_key,
        "current_period_start": period_start or (_now() - timedelta(days=5)),
        "current_period_end": period_end or (_now() + timedelta(days=25)),
        "cancel_at_period_end": cancel_at_period_end,
    }


def _dev_row(
    plan_id: str = "pro_monthly",
    period_start: datetime | None = None,
    period_end: datetime | None = None,
) -> dict:
    return {
        "plan_id": plan_id,
        "current_period_start": period_start or (_now() - timedelta(days=10)),
        "current_period_end": period_end or (_now() + timedelta(days=20)),
    }


def _allowlist_entry_row(
    email: str = "alice@example.com",
    plan_id: str = "reading_nook_pro",
    granted_at: datetime | None = None,
    expires_at: datetime | None = None,
) -> dict:
    return {
        "email": email,
        "plan_id": plan_id,
        "granted_at": granted_at or (_now() - timedelta(days=2)),
        "expires_at": expires_at or (_now() + timedelta(days=28)),
        "granted_by": "luis@psitta.ai",
        "notes": None,
        "revoked_at": None,
    }


# ── 1. source=stripe ────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_source_stripe():
    user_id = uuid4()
    db = RecordingSession({SQL_STRIPE: _FakeResult(mapping=_stripe_row())})

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert isinstance(plan, EffectivePlan)
    assert plan.source == "stripe"
    assert plan.plan_id == "reading_nook_pro"
    assert plan.raw_plan_id == "reading_nook_pro_monthly"
    assert plan.current_period_start is not None
    assert plan.current_period_end is not None
    # Stripe path stops the chain — dev_override and allowlist must NOT
    # be queried (precedence guarantee).
    sqls = [c[0] for c in db.calls]
    assert any(SQL_STRIPE in s for s in sqls)
    assert not any(SQL_DEV in s for s in sqls)
    assert not any(SQL_ALLOWLIST in s for s in sqls)


# ── 2. source=dev_override ──────────────────────────────────────────────


@pytest.mark.asyncio
async def test_source_dev_override():
    user_id = uuid4()
    # No Stripe row, but user_subscriptions has an active dev_override row.
    db = RecordingSession({SQL_DEV: _FakeResult(mapping=_dev_row())})

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert plan.source == "dev_override"
    # Legacy 'pro_monthly' ENUM normalizes to canonical 'reading_nook_pro'.
    assert plan.plan_id == "reading_nook_pro"
    assert plan.raw_plan_id == "pro_monthly"
    assert plan.current_period_start is not None
    # Allowlist must NOT be queried when dev_override hits.
    sqls = [c[0] for c in db.calls]
    assert not any(SQL_ALLOWLIST in s for s in sqls)


# ── 3. source=tester_allowlist ──────────────────────────────────────────


@pytest.mark.asyncio
async def test_source_tester_allowlist():
    user_id = uuid4()
    expires = _now() + timedelta(days=29)
    granted = _now() - timedelta(days=1)
    db = RecordingSession({
        SQL_ALLOWLIST: _FakeResult(
            mapping=_allowlist_entry_row(
                granted_at=granted, expires_at=expires
            )
        ),
    })

    plan = await get_effective_plan(db, user_id, email="Alice@Example.com")

    assert plan.source == "tester_allowlist"
    assert plan.plan_id == "reading_nook_pro"
    # Allowlist period uses granted_at + expires_at directly.
    assert plan.current_period_start == granted
    assert plan.current_period_end == expires
    assert plan.cancel_at_period_end is False
    # Email passed by caller — resolver must NOT do a users SELECT lookup.
    sqls = [c[0] for c in db.calls]
    assert not any(SQL_USER_EMAIL in s for s in sqls)


# ── 4. source=free ──────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_source_free_no_rows():
    user_id = uuid4()
    db = RecordingSession()  # All queries return empty.

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert plan.source == "free"
    assert plan.plan_id == "free"
    assert plan.raw_plan_id == "free"
    assert plan.current_period_start is None
    assert plan.current_period_end is None
    assert plan.cancel_at_period_end is False


# ── Precedence: Stripe > dev_override ───────────────────────────────────


@pytest.mark.asyncio
async def test_precedence_stripe_over_dev_override():
    user_id = uuid4()
    # Both Stripe AND user_subscriptions populated. Stripe must win.
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(mapping=_stripe_row()),
        SQL_DEV: _FakeResult(mapping=_dev_row()),
    })

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert plan.source == "stripe"


# ── Precedence: Stripe > tester_allowlist ───────────────────────────────


@pytest.mark.asyncio
async def test_precedence_stripe_over_allowlist():
    user_id = uuid4()
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(mapping=_stripe_row()),
        SQL_ALLOWLIST: _FakeResult(mapping=_allowlist_entry_row()),
    })

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert plan.source == "stripe"
    # Stripe short-circuits; allowlist query never runs.
    sqls = [c[0] for c in db.calls]
    assert not any(SQL_ALLOWLIST in s for s in sqls)


# ── Precedence: dev_override > tester_allowlist ─────────────────────────


@pytest.mark.asyncio
async def test_precedence_dev_override_over_allowlist():
    user_id = uuid4()
    # No Stripe, but both user_subscriptions and tester_allowlist hit.
    db = RecordingSession({
        SQL_DEV: _FakeResult(mapping=_dev_row()),
        SQL_ALLOWLIST: _FakeResult(mapping=_allowlist_entry_row()),
    })

    plan = await get_effective_plan(db, user_id, email="alice@example.com")

    assert plan.source == "dev_override"
    sqls = [c[0] for c in db.calls]
    assert not any(SQL_ALLOWLIST in s for s in sqls)


# ── Email fallback: when caller doesn't pass email ──────────────────────


@pytest.mark.asyncio
async def test_email_fallback_fetches_from_users_table():
    user_id = uuid4()
    user_email = "alice@example.com"
    # No Stripe, no dev. Resolver must SELECT users.email then check
    # the allowlist with that email.
    db = RecordingSession({
        SQL_USER_EMAIL: _FakeResult(row=(user_email,)),
        SQL_ALLOWLIST: _FakeResult(mapping=_allowlist_entry_row(email=user_email)),
    })

    plan = await get_effective_plan(db, user_id, email=None)

    assert plan.source == "tester_allowlist"
    # users.email lookup must have happened (caller didn't supply email).
    sqls = [c[0] for c in db.calls]
    assert any(SQL_USER_EMAIL in s for s in sqls)
    # The allowlist query must have been parameterised with the
    # lowercased email returned from users.
    allowlist_calls = [
        params for sql, params in db.calls if SQL_ALLOWLIST in sql
    ]
    assert allowlist_calls
    assert allowlist_calls[0]["email"] == user_email


@pytest.mark.asyncio
async def test_email_fallback_handles_empty_string():
    """JWT email claim defaults to '' (empty string) when Cognito's
    access token omits the email claim — the auth middleware sets
    TokenClaims.email='' in that case, so callers pass '' not None.

    The resolver must treat empty-string email the same as missing
    email and fall back to users.email for the allowlist lookup.
    Pre-fix the check was 'if email is None' which silently skipped
    the fallback for empty strings, and every alpha tester whose
    JWT lacks the email claim resolved to source=free regardless of
    their allowlist entry.
    """
    user_id = uuid4()
    user_email = "alice@example.com"
    db = RecordingSession({
        SQL_USER_EMAIL: _FakeResult(row=(user_email,)),
        SQL_ALLOWLIST: _FakeResult(mapping=_allowlist_entry_row(email=user_email)),
    })

    # Caller passes "" (empty string) — same shape as the JWT no-email
    # path in production.
    plan = await get_effective_plan(db, user_id, email="")

    assert plan.source == "tester_allowlist"
    sqls = [c[0] for c in db.calls]
    assert any(SQL_USER_EMAIL in s for s in sqls), (
        "users.email fallback must fire for empty-string email"
    )


@pytest.mark.asyncio
async def test_email_fallback_user_row_missing():
    user_id = uuid4()
    # users SELECT returns no row → resolver must fall through to free
    # without raising.
    db = RecordingSession({
        SQL_USER_EMAIL: _FakeResult(row=None),
    })

    plan = await get_effective_plan(db, user_id, email=None)

    assert plan.source == "free"
    sqls = [c[0] for c in db.calls]
    # No allowlist query when email is unresolvable — saves a roundtrip.
    assert not any(SQL_ALLOWLIST in s for s in sqls)


# ── Stripe lookup_key canonicalization ──────────────────────────────────


@pytest.mark.asyncio
async def test_stripe_creativity_lookup_key_normalizes_to_creative():
    """The Stripe-side ``creativity_nook_pro`` legacy prefix must
    surface as canonical ``creative_nook_pro`` in plan_id while
    raw_plan_id preserves the original Stripe shape."""
    user_id = uuid4()
    db = RecordingSession({
        SQL_STRIPE: _FakeResult(
            mapping=_stripe_row(lookup_key="creativity_nook_pro_annual"),
        ),
    })

    plan = await get_effective_plan(db, user_id)

    assert plan.plan_id == "creative_nook_pro"
    assert plan.raw_plan_id == "creativity_nook_pro_annual"
    assert plan.source == "stripe"
