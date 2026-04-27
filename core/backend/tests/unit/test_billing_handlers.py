"""Unit tests for services/billing_handlers.py.

Two layers covered:
  * Pure-function mappers (_lookup_key_to_plan_id,
    _stripe_status_to_us_status) -- locked down so a future Stripe
    product addition cannot silently downgrade paying customers.
  * Webhook handlers exercised via a recording fake AsyncSession that
    captures every db.execute(stmt, params) call. We assert against
    the captured SQL + bound parameters without hitting Postgres.

Background: the user_subscriptions write path was added in
fix(billing): webhook handlers now write user_subscriptions table.
The dual-table architecture (subscriptions table for Stripe lifecycle,
user_subscriptions table for quota enforcement) is documented in
CLAUDE.md Key Learning 2026-04-23.
"""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from psitta.services import billing_handlers
from psitta.services.billing_handlers import (
    _lookup_key_to_plan_id,
    _stripe_status_to_us_status,
    handle_checkout_session_completed,
    handle_subscription_deleted,
)


# ── Pure-function tests ──────────────────────────────────────────────────

class TestLookupKeyMapping:
    """The lookup_key -> plan_id mapping is the source of truth for
    which Stripe products correspond to which quota tier. Drift here
    downgrades paying customers, so we lock each mapping down with an
    explicit assert keyed on a stable string."""

    def test_reading_nook_pro_monthly_maps_to_pro_monthly(self):
        assert _lookup_key_to_plan_id("reading_nook_pro_monthly") == "pro_monthly"

    def test_reading_nook_pro_annual_maps_to_pro_annual(self):
        assert _lookup_key_to_plan_id("reading_nook_pro_annual") == "pro_annual"

    def test_creativity_nook_pro_monthly_maps_to_pro_monthly(self):
        # Stripe-side prefix is the legacy "creativity"; the quota tier
        # collapses to the same pro_monthly because PLAN_LIMITS treats
        # both products identically.
        assert (
            _lookup_key_to_plan_id("creativity_nook_pro_monthly") == "pro_monthly"
        )

    def test_creativity_nook_pro_annual_maps_to_pro_annual(self):
        assert (
            _lookup_key_to_plan_id("creativity_nook_pro_annual") == "pro_annual"
        )

    def test_unknown_lookup_key_returns_none(self):
        # Critical fail-open behavior: an unknown key must NOT map to
        # 'free' or any pro tier. None lets the caller skip the write
        # and log a warning rather than silently downgrade the customer.
        assert _lookup_key_to_plan_id("future_plan_xyz_monthly") is None

    def test_empty_string_returns_none(self):
        assert _lookup_key_to_plan_id("") is None


class TestStripeStatusMapping:
    """The Stripe-status -> user_subscriptions-status mapping encodes
    two product decisions worth locking down explicitly."""

    def test_active_passes_through(self):
        assert _stripe_status_to_us_status("active") == "active"

    def test_trialing_passes_through(self):
        assert _stripe_status_to_us_status("trialing") == "trialing"

    def test_past_due_keeps_active_during_grace(self):
        # Stripe retries payment for 3-21 days; entitlement is preserved
        # until customer.subscription.deleted fires at the end of the
        # retry window. Without this mapping, every retried payment
        # would briefly downgrade the user.
        assert _stripe_status_to_us_status("past_due") == "active"

    def test_canceled_maps_to_british_cancelled(self):
        # Spelling drift between the two tables: subscriptions uses
        # 'canceled' (American), user_subscriptions ENUM uses
        # 'cancelled' (British). The mapper MUST emit British or the
        # ENUM check rejects the value.
        assert _stripe_status_to_us_status("canceled") == "cancelled"

    def test_incomplete_maps_to_cancelled(self):
        assert _stripe_status_to_us_status("incomplete") == "cancelled"

    def test_unknown_stripe_status_returns_none(self):
        # Future Stripe enum values must NOT silently downgrade. None
        # lets the handler fail-open with a warning instead.
        assert _stripe_status_to_us_status("future_status_v3") is None


# ── Handler test scaffolding ─────────────────────────────────────────────


class _FakeResult:
    """Stand-in for SQLAlchemy Result. Supports the access patterns
    used in billing_handlers: r.fetchone() and r.mappings().first()."""

    def __init__(self, row: Any = None, mapping: dict | None = None):
        self._row = row
        self._mapping = mapping

    def fetchone(self):
        return self._row

    def mappings(self):
        return self

    def first(self):
        return self._mapping


class RecordingSession:
    """AsyncSession stand-in that records every execute() call.

    result_map keys are substrings tested against the SQL text -- the
    first match wins. Calls that don't match any key get an empty
    result. Tests inspect ``self.calls`` to assert on issued SQL and
    bound parameters.
    """

    def __init__(self, result_map: dict[str, _FakeResult] | None = None):
        self._result_map = result_map or {}
        self.calls: list[tuple[str, dict]] = []

    async def execute(self, stmt, params=None):
        sql = str(stmt)
        self.calls.append((sql, dict(params or {})))
        for key, result in self._result_map.items():
            if key in sql:
                return result
        return _FakeResult(row=None, mapping=None)


def _make_stripe_sub_dict(
    sub_id: str,
    lookup_key: str = "reading_nook_pro_monthly",
    status: str = "active",
) -> dict:
    """Minimum Stripe Subscription dict tree the handler reads."""
    return {
        "id": sub_id,
        "status": status,
        "current_period_start": 1_777_298_830,
        "current_period_end": 1_779_977_230,
        "cancel_at_period_end": False,
        "canceled_at": None,
        "items": {
            "data": [
                {
                    "price": {
                        "id": "price_test_123",
                        "product": "prod_test_456",
                        "lookup_key": lookup_key,
                    }
                }
            ],
        },
    }


@pytest.fixture
def fake_settings():
    """get_settings() stand-in returning just enough for the handler
    to set stripe.api_key without any external lookup."""
    s = MagicMock()
    s.STRIPE_SECRET_KEY_TEST.get_secret_value = MagicMock(
        return_value="sk_test_fixture_not_real"
    )
    return s


# ── Handler tests ────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_handle_checkout_session_completed_writes_user_subscription(
    fake_settings,
):
    """A successful Checkout completion must INSERT a user_subscriptions
    row with the correct plan_id and stripe_subscription_id alongside
    the existing subscriptions INSERT. Without the second write, the
    quota enforcer keeps the customer on Free.

    Also asserts the prior-active-row UPDATE that maintains the
    one-active-row-per-user invariant.
    """
    sc_internal_id = "11111111-1111-1111-1111-111111111111"
    psitta_user_id = "22222222-2222-2222-2222-222222222222"
    stripe_sub_id = "sub_test_writes"

    fake_db = RecordingSession(
        {"FROM stripe_customers": _FakeResult(row=(sc_internal_id,))},
    )

    event = {
        "id": "evt_test_writes",
        "data": {
            "object": {
                "id": "cs_test_writes",
                "customer": "cus_test_writes",
                "subscription": stripe_sub_id,
                "metadata": {
                    "psitta_user_id": psitta_user_id,
                    "lookup_key": "reading_nook_pro_monthly",
                },
            }
        },
    }

    sub_dict = _make_stripe_sub_dict(stripe_sub_id)
    # Patch the Stripe call (handler does stripe.Subscription.retrieve)
    # and the obj-to-dict helper (so we control the dict tree directly,
    # without depending on Stripe's __str__ JSON serialization).
    with patch.object(
        billing_handlers, "get_settings", return_value=fake_settings
    ), patch.object(
        billing_handlers.stripe.Subscription,
        "retrieve",
        return_value=MagicMock(),
    ), patch.object(
        billing_handlers, "stripe_obj_to_dict", return_value=sub_dict
    ), patch.object(
        billing_handlers.audit_service,
        "log_event",
        new=AsyncMock(return_value=None),
    ):
        await handle_checkout_session_completed(event, fake_db)

    insert_calls = [
        (sql, params)
        for sql, params in fake_db.calls
        if "INSERT INTO user_subscriptions" in sql
    ]
    cancel_prior_calls = [
        (sql, params)
        for sql, params in fake_db.calls
        if "UPDATE user_subscriptions" in sql and "WHERE user_id" in sql
    ]

    assert len(insert_calls) == 1, (
        f"Expected exactly 1 user_subscriptions INSERT, got "
        f"{len(insert_calls)}. All calls: {fake_db.calls}"
    )
    insert_params = insert_calls[0][1]
    assert insert_params["uid"] == psitta_user_id
    assert insert_params["plan_id"] == "pro_monthly"
    assert insert_params["stripe_sub_id"] == stripe_sub_id
    assert insert_params["stripe_customer_id"] == "cus_test_writes"

    assert len(cancel_prior_calls) == 1, (
        "Handler must cancel any prior active user_subscriptions row "
        "before inserting the new one (one-active-row-per-user "
        "invariant)."
    )
    assert cancel_prior_calls[0][1]["uid"] == psitta_user_id


@pytest.mark.asyncio
async def test_handle_subscription_deleted_cancels_user_subscription():
    """When Stripe sends customer.subscription.deleted, both
    subscriptions AND user_subscriptions must be marked cancelled.
    Without the second UPDATE, the quota enforcer would keep the
    customer on Pro after cancellation."""
    psitta_user_id = "33333333-3333-3333-3333-333333333333"
    stripe_sub_id = "sub_test_deleted"

    fake_db = RecordingSession(
        {
            "FROM subscriptions s": _FakeResult(
                mapping={
                    "id": "row-id-1",
                    "user_id": psitta_user_id,
                },
            )
        },
    )

    event = {
        "id": "evt_test_deleted",
        "data": {"object": {"id": stripe_sub_id}},
    }

    with patch.object(
        billing_handlers.audit_service,
        "log_event",
        new=AsyncMock(return_value=None),
    ):
        await handle_subscription_deleted(event, fake_db)

    user_subs_cancel_calls = [
        (sql, params)
        for sql, params in fake_db.calls
        if "UPDATE user_subscriptions" in sql
        and "status = 'cancelled'" in sql
        and "WHERE stripe_subscription_id" in sql
    ]
    assert len(user_subs_cancel_calls) == 1, (
        "Expected user_subscriptions cancellation UPDATE matching by "
        f"stripe_subscription_id. All calls: {fake_db.calls}"
    )
    assert user_subs_cancel_calls[0][1]["sub_id"] == stripe_sub_id
