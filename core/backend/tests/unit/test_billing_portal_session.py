"""Unit tests for POST /billing/portal-session.

The route handler ``create_portal_session`` in ``api/v1/billing.py``
is exercised directly (bypassing FastAPI's dependency injection) so
the test can control the AsyncSession and the Stripe SDK call without
a running app or a Postgres connection. Same pattern as
``test_billing_handlers.py``: a recording fake AsyncSession plus
``unittest.mock.patch.object`` against the route module.

Three scenarios:
  * Pro user with stripe_customers row → returns the Stripe portal URL
  * Free user with no stripe_customers row → HTTP 404, Stripe never called
  * Stripe API failure → HTTP 502 with a clean message; provider-side
    error text MUST NOT leak to the client
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException, status

from psitta.api.v1 import billing
from psitta.api.v1.billing import create_portal_session


# ── Test scaffolding ─────────────────────────────────────────────────────


class _FakeResult:
    """Stand-in for SQLAlchemy Result. Supports r.mappings().first()."""

    def __init__(self, mapping: dict | None = None):
        self._mapping = mapping

    def mappings(self):
        return self

    def first(self):
        return self._mapping


class RecordingSession:
    """AsyncSession stand-in returning a single canned mapping result.

    Records every ``execute(stmt, params)`` call so tests can assert
    the SELECT was issued with the expected user_id binding.
    """

    def __init__(self, mapping: dict | None = None):
        self._mapping = mapping
        self.calls: list[tuple[str, dict]] = []

    async def execute(self, stmt, params=None):
        self.calls.append((str(stmt), dict(params or {})))
        return _FakeResult(mapping=self._mapping)


def _fake_request() -> MagicMock:
    """Minimal Request stand-in exposing request.client.host."""
    req = MagicMock()
    req.client.host = "127.0.0.1"
    return req


@pytest.fixture
def fake_settings():
    """get_settings() stand-in returning a Stripe test secret."""
    s = MagicMock()
    s.STRIPE_SECRET_KEY_TEST.get_secret_value = MagicMock(
        return_value="sk_test_fixture_not_real"
    )
    return s


# ── Tests ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_portal_session_returns_url_for_pro_user(fake_settings):
    """Happy path: Pro user with a stripe_customers row gets the
    portal URL back. Verifies the route looks up the right customer
    by user_id and forwards the cus_xxx ID + return_url to Stripe.
    """
    user_id = "11111111-1111-1111-1111-111111111111"
    fake_db = RecordingSession(mapping={"stripe_customer_id": "cus_test_pro"})

    fake_session = MagicMock()
    fake_session.id = "bps_test_session"
    fake_session.url = "https://billing.stripe.com/p/session/test_url"

    with patch.object(
        billing, "get_settings", return_value=fake_settings
    ), patch.object(
        billing.stripe.billing_portal.Session,
        "create",
        return_value=fake_session,
    ) as mock_create, patch.object(
        billing.audit_service,
        "log_event",
        new=AsyncMock(return_value=None),
    ):
        response = await create_portal_session(
            request=_fake_request(),
            user_id=user_id,
            db=fake_db,
        )

    assert response.url == "https://billing.stripe.com/p/session/test_url"

    # Stripe called with the right customer + return_url (CloudFront
    # trailing-slash fix from 2026-04-27).
    mock_create.assert_called_once_with(
        customer="cus_test_pro",
        return_url="https://psitta.ai/",
    )

    # The SELECT bound user_id correctly.
    select_calls = [
        (sql, params)
        for sql, params in fake_db.calls
        if "FROM stripe_customers" in sql
    ]
    assert len(select_calls) == 1
    assert select_calls[0][1]["user_id"] == user_id


@pytest.mark.asyncio
async def test_portal_session_returns_404_for_free_user(fake_settings):
    """Free user with no stripe_customers row gets a clean 404 with an
    actionable message. Stripe must NOT be called — Free users have
    nothing to manage."""
    user_id = "22222222-2222-2222-2222-222222222222"
    fake_db = RecordingSession(mapping=None)

    with patch.object(
        billing, "get_settings", return_value=fake_settings
    ), patch.object(
        billing.stripe.billing_portal.Session,
        "create",
    ) as mock_create:
        with pytest.raises(HTTPException) as exc_info:
            await create_portal_session(
                request=_fake_request(),
                user_id=user_id,
                db=fake_db,
            )

    assert exc_info.value.status_code == status.HTTP_404_NOT_FOUND
    assert "Subscribe first" in exc_info.value.detail
    mock_create.assert_not_called()


@pytest.mark.asyncio
async def test_portal_session_handles_stripe_error(fake_settings):
    """Stripe API failure surfaces as HTTP 502 with a clean,
    user-safe message. Provider-side error text is logged but MUST
    NOT leak to the client."""
    user_id = "33333333-3333-3333-3333-333333333333"
    fake_db = RecordingSession(mapping={"stripe_customer_id": "cus_test_err"})

    stripe_err = billing.stripe.StripeError("Stripe-side internal error")

    with patch.object(
        billing, "get_settings", return_value=fake_settings
    ), patch.object(
        billing.stripe.billing_portal.Session,
        "create",
        side_effect=stripe_err,
    ), patch.object(
        billing.audit_service,
        "log_event",
        new=AsyncMock(return_value=None),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await create_portal_session(
                request=_fake_request(),
                user_id=user_id,
                db=fake_db,
            )

    assert exc_info.value.status_code == status.HTTP_502_BAD_GATEWAY
    assert "Payment provider error" in exc_info.value.detail
    # Provider-side error string MUST NOT leak.
    assert "Stripe-side internal error" not in exc_info.value.detail
