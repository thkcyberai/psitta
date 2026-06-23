#!/usr/bin/env python3
"""Create / reconcile Psitta subscription prices in Stripe (idempotent).

Ensures one Product per tier (Reading / Writing / Creative Nook) and the
six recurring Prices the backend resolves by ``lookup_key``. Safe to re-run:
a price that already exists with the right amount + interval is left alone;
a price whose amount changed (e.g. Reading annual $99 -> $152) is replaced by
a new price that *transfers* the lookup_key, and the old price is archived.
Existing subscriptions are NOT touched — Stripe keeps them on their original
price; only NEW checkouts pick up the transferred key.

Lookup keys (must match billing.py VALID_LOOKUP_KEYS / billing_handlers
_LOOKUP_KEY_TO_PLAN_ID — note Creative uses the legacy 'creativity_' spelling):
    reading_nook_pro_monthly      $14.99 / month
    reading_nook_pro_annual       $152   / year   (transfer from old $99)
    writing_nook_pro_monthly      $17.99 / month
    writing_nook_pro_annual       $183   / year
    creativity_nook_pro_monthly   $29.99 / month
    creativity_nook_pro_annual    $305   / year

Usage (the secret key comes from your environment and is NEVER printed):
    export STRIPE_SECRET_KEY=sk_test_...        # test mode
    python setup_stripe_prices.py               # DRY RUN (default) — prints plan
    python setup_stripe_prices.py --apply        # actually create/replace
    python setup_stripe_prices.py --mode live --apply   # live (guarded)

Safety: --mode test refuses a non-test key; --mode live refuses a test key.
"""
from __future__ import annotations

import argparse
import os
import sys

import stripe

PRODUCTS: dict[str, str] = {
    "reading": "Psitta Reading Nook",
    "writing": "Psitta Writing Nook",
    "creative": "Psitta Creative Nook",
}

# (tier, lookup_key, unit_amount_cents, interval)
PRICES: list[tuple[str, str, int, str]] = [
    ("reading", "reading_nook_pro_monthly", 1499, "month"),
    ("reading", "reading_nook_pro_annual", 15200, "year"),
    ("writing", "writing_nook_pro_monthly", 1799, "month"),
    ("writing", "writing_nook_pro_annual", 18300, "year"),
    ("creative", "creativity_nook_pro_monthly", 2999, "month"),
    ("creative", "creativity_nook_pro_annual", 30500, "year"),
]


def _money(cents: int) -> str:
    return f"${cents / 100:.2f}"


def find_product(tier: str):
    try:
        res = stripe.Product.search(query=f"metadata['psitta_tier']:'{tier}'")
        if res.data:
            return res.data[0]
    except Exception:  # search not enabled — fall back to a list scan
        for p in stripe.Product.list(limit=100).auto_paging_iter():
            if p.metadata.get("psitta_tier") == tier:
                return p
    return None


def find_price(lookup_key: str):
    res = stripe.Price.list(lookup_keys=[lookup_key], active=True, limit=1)
    return res.data[0] if res.data else None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true",
                    help="Actually create (default: dry run).")
    ap.add_argument("--mode", choices=["test", "live"], default="test")
    ap.add_argument("--reprice", action="store_true",
                    help="Also replace an EXISTING price whose amount changed "
                         "(e.g. Reading annual $99 -> $152). Off by default so "
                         "working prices are never touched.")
    args = ap.parse_args()

    key = os.environ.get("STRIPE_SECRET_KEY", "")
    if not key:
        print("ERROR: STRIPE_SECRET_KEY not set in environment.", file=sys.stderr)
        return 2
    is_test = key.startswith(("sk_test_", "rk_test_"))
    if args.mode == "test" and not is_test:
        print("REFUSING: --mode test but STRIPE_SECRET_KEY is not a test key.",
              file=sys.stderr)
        return 2
    if args.mode == "live" and is_test:
        print("REFUSING: --mode live but STRIPE_SECRET_KEY is a test key.",
              file=sys.stderr)
        return 2
    stripe.api_key = key

    apply = args.apply
    banner = "APPLY" if apply else "DRY RUN"
    print(f"=== Psitta Stripe price setup [{args.mode.upper()} / {banner}] ===\n")

    # 1. Products
    product_ids: dict[str, str | None] = {}
    for tier, name in PRODUCTS.items():
        prod = find_product(tier)
        if prod:
            product_ids[tier] = prod.id
            print(f"product OK      : {name}  ({prod.id})")
        elif apply:
            prod = stripe.Product.create(
                name=name, metadata={"psitta_tier": tier})
            product_ids[tier] = prod.id
            print(f"product CREATED : {name}  ({prod.id})")
        else:
            product_ids[tier] = None
            print(f"product CREATE? : {name}")
    print()

    # 2. Prices
    for tier, lookup_key, amount, interval in PRICES:
        existing = find_price(lookup_key)
        if (existing and existing.unit_amount == amount
                and existing.recurring
                and existing.recurring.interval == interval):
            print(f"price OK        : {lookup_key}  {_money(amount)}/{interval}")
            continue
        if existing and not args.reprice:
            print(f"price KEEP      : {lookup_key}  exists at "
                  f"{_money(existing.unit_amount)} (target {_money(amount)}) "
                  f"— left untouched; pass --reprice to change")
            continue
        if existing:
            print(f"price REPLACE   : {lookup_key}  {_money(amount)}/{interval}"
                  f"  (was {_money(existing.unit_amount)})")
        else:
            print(f"price CREATE    : {lookup_key}  {_money(amount)}/{interval}")
        if not apply:
            continue
        new_price = stripe.Price.create(
            product=product_ids[tier],
            unit_amount=amount,
            currency="usd",
            recurring={"interval": interval},
            lookup_key=lookup_key,
            transfer_lookup_key=True,
        )
        print(f"   -> created {new_price.id}")
        if existing:
            stripe.Price.update(existing.id, active=False)
            print(f"   -> archived old {existing.id}")

    print(f"\nDone ({banner}).")
    if not apply:
        print("Re-run with --apply to make these changes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
