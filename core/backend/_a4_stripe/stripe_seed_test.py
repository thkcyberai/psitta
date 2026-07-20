"""A4 test-mode seeding — create the Writing Nook catalog in TEST mode.

Approved scope (decision 2, 2026-07-20): Stripe TEST mode is empty; the
A4 checkout-matrix validation needs the launch catalog to exist there.
Creates, in TEST mode only:

  * Product  "Psitta Writing Nook"
  * Price    $17.99 / month  · lookup_key writing_nook_pro_monthly
  * Price    $183.00 / year  · lookup_key writing_nook_pro_annual

Matching the approved launch pricing exactly. Idempotent: existing
lookup keys are detected and reused, so re-running never duplicates.
HARD GUARD: refuses to run with a live key — this script can never
touch live mode.

Usage:
    .venv/Scripts/python _a4_stripe/stripe_seed_test.py --key-file _a4_stripe/key.txt

Webhooks note: no webhook endpoint is created. For local checkout
validation use Stripe CLI forwarding
(`stripe listen --forward-to localhost:8000/api/v1/billing/webhook`),
which supplies its own signing secret for the local backend.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import stripe

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_util import load_stripe_key  # noqa: E402

OUT_ROOT = Path(__file__).resolve().parent / "out"

PRODUCT_NAME = "Psitta Writing Nook"
PRICES = [
    {"lookup_key": "writing_nook_pro_monthly", "unit_amount": 1799,
     "interval": "month", "label": "$17.99/month"},
    {"lookup_key": "writing_nook_pro_annual", "unit_amount": 18300,
     "interval": "year", "label": "$183.00/year"},
]


def as_dict(obj) -> dict:
    """StripeObject → plain dict (json round-trip); see stripe_audit.py."""
    return json.loads(str(obj))


def main() -> None:
    key, mode = load_stripe_key()
    if mode != "test":
        print("ERROR: this script seeds TEST mode only — a live key was "
              "provided. Refusing.")
        sys.exit(1)

    stripe.api_key = key
    stripe.max_network_retries = 2

    print("Seeding Stripe TEST mode with the Writing Nook launch catalog...")

    # Existing lookup keys (idempotency)
    existing = {}
    for pr_raw in stripe.Price.list(limit=100, active=None).auto_paging_iter():
        pr = as_dict(pr_raw)
        if pr.get("lookup_key"):
            existing[pr["lookup_key"]] = pr

    # Product: reuse an active one with the exact name, else create.
    product_id = None
    for p_raw in stripe.Product.list(limit=100, active=None).auto_paging_iter():
        p = as_dict(p_raw)
        if p.get("name") == PRODUCT_NAME and p.get("active"):
            product_id = p["id"]
            print(f"product exists: {product_id} · {PRODUCT_NAME}")
            break
    if product_id is None:
        prod = as_dict(stripe.Product.create(
            name=PRODUCT_NAME,
            metadata={"psitta_seed": "a4_test_catalog"},
        ))
        product_id = prod["id"]
        print(f"created product: {product_id} · {PRODUCT_NAME}")

    created = []
    for spec in PRICES:
        lk = spec["lookup_key"]
        if lk in existing:
            print(f"price exists: {existing[lk]['id']} · {lk}")
            continue
        price = as_dict(stripe.Price.create(
            product=product_id,
            currency="usd",
            unit_amount=spec["unit_amount"],
            recurring={"interval": spec["interval"]},
            lookup_key=lk,
            metadata={"psitta_seed": "a4_test_catalog"},
        ))
        created.append({"id": price["id"], "lookup_key": lk})
        print(f"created price: {price['id']} · {lk} · {spec['label']}")

    out_dir = OUT_ROOT / "test"
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "seed_log.json").write_text(
        json.dumps({"product_id": product_id, "created_prices": created},
                   indent=2),
        encoding="utf-8",
    )
    print(f"Seed log → {out_dir / 'seed_log.json'}")
    print("Done. TEST mode only; live mode untouched.")


if __name__ == "__main__":
    main()
