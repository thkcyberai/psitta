"""A4 product-consolidation catalog contract (api/v1/billing.py).

Writing Nook is the only purchasable product. These import-level pins
guard the launch catalog:
  * VALID_LOOKUP_KEYS contains exactly the two Writing Nook SKUs —
    a Reading or Creative key reappearing here would silently reopen
    checkout for a discontinued / unshipped product.
  * TRIAL_PERIOD_DAYS is 14 — the code-level trial length that every
    Checkout session carries via subscription_data (deterministic,
    reviewable, independent of Stripe Dashboard per-price config).
  * The parse boundary grandfathers historical Reading lookup_keys
    upward to writing_nook_pro (DP-2).
  * The signup-time reverse trial defaults OFF — the Stripe Checkout
    trial is the single trial source of truth; both on would stack
    14 signup days on top of 14 checkout days.
"""

from __future__ import annotations

from psitta.api.v1.billing import (
    TRIAL_PERIOD_DAYS,
    VALID_LOOKUP_KEYS,
    _parse_lookup_key,
)
from psitta.config import Settings


class TestLaunchCatalog:
    def test_valid_lookup_keys_are_writing_only(self):
        expected = frozenset({
            "writing_nook_pro_monthly",
            "writing_nook_pro_annual",
        })
        assert expected == VALID_LOOKUP_KEYS

    def test_reading_and_creative_keys_are_not_purchasable(self):
        for retired in (
            "reading_nook_pro_monthly",
            "reading_nook_pro_annual",
            "creativity_nook_pro_monthly",
            "creativity_nook_pro_annual",
        ):
            assert retired not in VALID_LOOKUP_KEYS

    def test_trial_period_is_14_days(self):
        assert TRIAL_PERIOD_DAYS == 14


class TestParseBoundaryGrandfathering:
    def test_reading_monthly_parses_to_writing(self):
        assert _parse_lookup_key("reading_nook_pro_monthly") == (
            "writing_nook_pro",
            "monthly",
        )

    def test_reading_annual_parses_to_writing(self):
        assert _parse_lookup_key("reading_nook_pro_annual") == (
            "writing_nook_pro",
            "annual",
        )

    def test_writing_keys_parse_unchanged(self):
        assert _parse_lookup_key("writing_nook_pro_monthly") == (
            "writing_nook_pro",
            "monthly",
        )
        assert _parse_lookup_key("writing_nook_pro_annual") == (
            "writing_nook_pro",
            "annual",
        )

    def test_creativity_prefix_still_normalizes(self):
        assert _parse_lookup_key("creativity_nook_pro_annual") == (
            "creative_nook_pro",
            "annual",
        )


class TestOneTrialSourceOfTruth:
    def test_reverse_trial_default_is_disabled(self):
        # Field default, checked without instantiating Settings (which
        # would read the real environment / .env file).
        assert Settings.model_fields["REVERSE_TRIAL_ENABLED"].default is False
