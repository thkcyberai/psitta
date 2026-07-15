"""Unit tests for /billing/status resolver wiring (T11.2).

Covers the response-shape contract that desktop and website both
consume:
  * Allowlist hit → response.source == "tester_allowlist", current_period_end
    matches the allowlist row's expires_at
  * Stripe + allowlist both present → response.source == "stripe"
    (precedence rule, ensures real paying customers don't get demoted
    when their email also happens to be on the alpha allowlist)
  * Audit ``tester.entitlement_resolved`` event fires only on
    tester_allowlist source

Same recording-fake-session pattern as test_resolver.py and
test_billing_portal_session.py.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from psitta.api.v1 import billing
from psitta.api.v1.billing import get_billing_status

# ── Fake DB scaffolding ──────────────────────────────────────────────────


class _FakeResult:
    def __init__(self, row: Any = None, mapping: dict | None = None):
        self._row = row
        self._mapping = mapping

    def fetchone(self):
        return self._row

    def mappings(self):
        return self

    def first(self):
        return self._mapping


class _NoopSavepoint:
    """No-op async context manager modelling AsyncSession.begin_nested().

    get_effective_plan and get_billing_status wrap entitlement lookups
    and audit writes in SAVEPOINTs so a failure can't poison the request
    transaction. The fake session has no real transaction, so its
    savepoint just runs the body.
    """

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class RecordingSession:
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
        return _FakeResult(row=None, mapping=None)


# ── Helpers ──────────────────────────────────────────────────────────────


SQL_STRIPE = "JOIN stripe_customers"
SQL_DEV = "FROM user_subscriptions"
SQL_ALLOWLIST = "FROM tester_allowlist"
SQL_TRIAL = "FROM trial_grants"


def _now() -> datetime:
    return datetime.now(UTC)


def _fake_request():
    req = MagicMock()
    req.client.host = "127.0.0.1"
    return req


def _fake_claims(email: str = "alice@example.com"):
    claims = MagicMock()
    claims.email = email
    claims.sub = "auth0|fake_sub"
    return claims


def _stripe_row(
    lookup_key: str = "reading_nook_pro_monthly",
    period_end: datetime | None = None,
) -> dict:
    return {
        "lookup_key": lookup_key,
        "current_period_start": _now() - timedelta(days=5),
        "current_period_end": period_end or (_now() + timedelta(days=25)),
        "cancel_at_period_end": False,
    }


def _allowlist_row(
    email: str = "alice@example.com",
    expires_at: datetime | None = None,
) -> dict:
    return {
        "email": email,
        "plan_id": "reading_nook_pro",
        "granted_at": _now() - timedelta(days=2),
        "expires_at": expires_at or (_now() + timedelta(days=28)),
        "granted_by": "luis@psitta.ai",
        "notes": None,
        "revoked_at": None,
    }


def _trial_row(
    plan_id: str = "writing_nook_pro",
    expires_at: datetime | None = None,
) -> dict:
    return {
        "user_id": uuid4(),
        "plan_id": plan_id,
        "granted_at": _now() - timedelta(days=1),
        "expires_at": expires_at or (_now() + timedelta(days=13)),
        "activated_at": None,
        "revoked_at": None,
    }


# ── Tests ───────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_billing_status_allowlist_hit():
    """An allowlist-only user (no Stripe row, no dev_override) gets
    source='tester_allowlist' and current_period_end equal to the
    allowlist row's expires_at."""
    user_id = uuid4()
    expires = _now() + timedelta(days=29)
    fake_db = RecordingSession({
        SQL_ALLOWLIST: _FakeResult(
            mapping=_allowlist_row(
                email="alice@example.com", expires_at=expires
            )
        ),
    })

    audit_calls: list[dict] = []

    async def _capture_log(_db, **kwargs):
        audit_calls.append(kwargs)

    with patch.object(
        billing.audit_service, "log_event", new=AsyncMock(side_effect=_capture_log)
    ):
        response = await get_billing_status(
            request=_fake_request(),
            user_id=user_id,
            claims=_fake_claims(email="alice@example.com"),
            db=fake_db,
        )

    assert response.source == "tester_allowlist"
    assert response.plan == "reading_nook_pro"
    assert response.billing_period is None
    assert response.status == "active"
    assert response.cancel_at_period_end is False
    # Period_end == expires_at (ISO-formatted)
    assert response.current_period_end == expires.isoformat()

    # Audit: TWO events expected — billing.status_checked (always) plus
    # tester.entitlement_resolved (only when source is allowlist).
    actions = [c["action"] for c in audit_calls]
    assert "billing.status_checked" in actions
    assert "tester.entitlement_resolved" in actions

    # billing.status_checked must include source in its details payload.
    status_checked = next(
        c for c in audit_calls if c["action"] == "billing.status_checked"
    )
    assert status_checked["details"]["source"] == "tester_allowlist"
    assert status_checked["details"]["plan"] == "reading_nook_pro"

    # tester.entitlement_resolved details include email and expires_at.
    resolved = next(
        c for c in audit_calls if c["action"] == "tester.entitlement_resolved"
    )
    assert resolved["details"]["email"] == "alice@example.com"
    assert resolved["details"]["expires_at"] == expires.isoformat()


@pytest.mark.asyncio
async def test_billing_status_stripe_wins_over_allowlist():
    """User has BOTH a Stripe subscription AND an allowlist row.
    Resolver precedence guarantees source='stripe' — the allowlist
    row is silently ignored. Real paying customers must never be
    flagged as alpha testers in the response."""
    user_id = uuid4()
    fake_db = RecordingSession({
        SQL_STRIPE: _FakeResult(mapping=_stripe_row()),
        SQL_ALLOWLIST: _FakeResult(mapping=_allowlist_row()),
    })

    audit_calls: list[dict] = []

    async def _capture_log(_db, **kwargs):
        audit_calls.append(kwargs)

    with patch.object(
        billing.audit_service, "log_event", new=AsyncMock(side_effect=_capture_log)
    ):
        response = await get_billing_status(
            request=_fake_request(),
            user_id=user_id,
            claims=_fake_claims(email="alice@example.com"),
            db=fake_db,
        )

    assert response.source == "stripe"
    assert response.plan == "reading_nook_pro"
    assert response.billing_period == "monthly"
    assert response.status == "active"

    # Stripe path must NOT emit tester.entitlement_resolved.
    actions = [c["action"] for c in audit_calls]
    assert "billing.status_checked" in actions
    assert "tester.entitlement_resolved" not in actions

    # billing.status_checked details.source == 'stripe'
    status_checked = next(
        c for c in audit_calls if c["action"] == "billing.status_checked"
    )
    assert status_checked["details"]["source"] == "stripe"


@pytest.mark.asyncio
async def test_billing_status_free_user_no_extra_audit():
    """Free user (no Stripe, no dev, no allowlist) gets source='free'.
    tester.entitlement_resolved must NOT fire — only when the
    resolver actually returns the allowlist source."""
    user_id = uuid4()
    fake_db = RecordingSession()  # All queries return empty

    audit_calls: list[dict] = []

    async def _capture_log(_db, **kwargs):
        audit_calls.append(kwargs)

    with patch.object(
        billing.audit_service, "log_event", new=AsyncMock(side_effect=_capture_log)
    ):
        response = await get_billing_status(
            request=_fake_request(),
            user_id=user_id,
            claims=_fake_claims(email="alice@example.com"),
            db=fake_db,
        )

    assert response.source == "free"
    assert response.plan == "free"
    assert response.status == "none"
    assert response.current_period_end is None

    actions = [c["action"] for c in audit_calls]
    assert "tester.entitlement_resolved" not in actions


@pytest.mark.asyncio
async def test_billing_status_reverse_trial_reported_active():
    """A reverse-trial user (no Stripe/dev, active trial_grant) must be
    reported with plan='writing_nook_pro' and status='active' — NOT
    plan='free'. Regression guard: the source='reverse_trial' branch was
    missing from the response mapping, so a live 14-day trial user fell
    into the else branch and was told they were on the Free plan, which
    showed them the stripped Free interface instead of Writing Nook."""
    user_id = uuid4()
    expires = _now() + timedelta(days=13)
    fake_db = RecordingSession({
        SQL_TRIAL: _FakeResult(mapping=_trial_row(expires_at=expires)),
    })

    audit_calls: list[dict] = []

    async def _capture_log(_db, **kwargs):
        audit_calls.append(kwargs)

    with patch.object(
        billing.audit_service, "log_event", new=AsyncMock(side_effect=_capture_log)
    ):
        response = await get_billing_status(
            request=_fake_request(),
            user_id=user_id,
            claims=_fake_claims(email="alice@example.com"),
            db=fake_db,
        )

    assert response.source == "reverse_trial"
    assert response.plan == "writing_nook_pro"
    assert response.status == "active"
    assert response.billing_period is None
    assert response.current_period_end == expires.isoformat()

    # Trial is not the allowlist path — no tester.entitlement_resolved.
    actions = [c["action"] for c in audit_calls]
    assert "billing.status_checked" in actions
    assert "tester.entitlement_resolved" not in actions
    status_checked = next(
        c for c in audit_calls if c["action"] == "billing.status_checked"
    )
    assert status_checked["details"]["source"] == "reverse_trial"
    assert status_checked["details"]["plan"] == "writing_nook_pro"
