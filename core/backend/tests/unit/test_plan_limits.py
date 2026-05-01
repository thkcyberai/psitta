"""Unit tests for services/plan_limits.py.

Locks in the get_plan_limits() resolver behavior:
  * Canonical PLAN_LIMITS keys ('free', 'reading_nook_pro',
    'creative_nook_pro') resolve directly.
  * Legacy Postgres plan_id ENUM values ('pro_monthly', 'pro_annual')
    written by the Stripe webhook handler resolve to the matching
    Reading Nook Pro PlanLimits — paying customers must NOT silently
    downgrade to Free.
  * Forward-compat 'creative_pro_monthly' / 'creative_pro_annual'
    values resolve to Creative Nook Pro.
  * The legacy 'creativity_nook_pro' prefix (preserved on the Stripe
    side) resolves to the canonical 'creative_nook_pro'.
  * Whitespace and case are normalized.
  * Unknown values emit a structured warning AND fall back to free
    rather than raising or silently downgrading without observability.

Background: CLAUDE.md Key Learning 2026-04-23 (dual-table tech debt)
and 2026-04-27 (predictable failure mode of dual-table architecture).
"""

from __future__ import annotations

import structlog

from psitta.services.plan_limits import (
    PLAN_LIMITS,
    _normalize_plan_id,
    get_plan_limits,
)


class TestCanonicalKeys:
    """Direct lookup of PLAN_LIMITS keys must return the exact dict
    entries — these are the public API."""

    def test_canonical_free(self):
        assert get_plan_limits("free") is PLAN_LIMITS["free"]

    def test_canonical_reading_nook_pro(self):
        assert (
            get_plan_limits("reading_nook_pro") is PLAN_LIMITS["reading_nook_pro"]
        )

    def test_canonical_creative_nook_pro(self):
        assert (
            get_plan_limits("creative_nook_pro") is PLAN_LIMITS["creative_nook_pro"]
        )


class TestLegacyEnumAliases:
    """Postgres user_subscriptions.plan_id is an ENUM
    (free|pro_monthly|pro_annual). The webhook handler writes
    'pro_monthly' or 'pro_annual'. Both must resolve to Reading Nook
    Pro PlanLimits — without this, Item C (per-user EL quota
    tracking) would silently downgrade every paying customer."""

    def test_legacy_pro_monthly_maps_to_reading_nook_pro(self):
        assert get_plan_limits("pro_monthly") is PLAN_LIMITS["reading_nook_pro"]

    def test_legacy_pro_annual_maps_to_reading_nook_pro(self):
        assert get_plan_limits("pro_annual") is PLAN_LIMITS["reading_nook_pro"]


class TestCreativeAliases:
    """Forward-compat for the Creative Nook period split, plus the
    legacy 'creativity' Stripe prefix."""

    def test_creative_pro_monthly_maps_to_creative_nook_pro(self):
        assert (
            get_plan_limits("creative_pro_monthly")
            is PLAN_LIMITS["creative_nook_pro"]
        )

    def test_creative_pro_annual_maps_to_creative_nook_pro(self):
        assert (
            get_plan_limits("creative_pro_annual")
            is PLAN_LIMITS["creative_nook_pro"]
        )

    def test_creativity_nook_pro_alias_maps_to_creative_nook_pro(self):
        assert (
            get_plan_limits("creativity_nook_pro")
            is PLAN_LIMITS["creative_nook_pro"]
        )


class TestNormalization:
    def test_whitespace_and_case_normalization(self):
        # Resolver must absorb upstream string drift (hand-typed
        # overrides, accidental casing) without surfacing it as a miss.
        assert get_plan_limits(" Pro_Monthly ") is PLAN_LIMITS["reading_nook_pro"]
        assert _normalize_plan_id(" Pro_Monthly ") == "reading_nook_pro"


class TestUnknownPlanId:
    def test_unknown_plan_id_returns_free_with_warning_log(self):
        # structlog.testing.capture_logs intercepts events emitted via
        # the structlog logger without depending on the global
        # configure() chain — works regardless of whether stdlib
        # logging is wired up in this test session.
        with structlog.testing.capture_logs() as captured:
            result = get_plan_limits("future_plan_xyz")

        assert result is PLAN_LIMITS["free"]
        warnings = [
            e for e in captured if e.get("event") == "plan_limits.unknown_plan_id"
        ]
        assert len(warnings) == 1
        assert warnings[0]["log_level"] == "warning"
        assert warnings[0]["plan"] == "future_plan_xyz"
        assert warnings[0]["normalized"] == "future_plan_xyz"
