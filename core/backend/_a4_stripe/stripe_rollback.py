"""A4 Stripe migration rollback v2 — full restore from the merged log.

Restores everything the migration changed, in the exact inverse order:
  1. Re-activate archived PRODUCTS (a price can't be un-archived or
     re-set as default while its product is archived).
  2. Re-activate archived PRICES.
  3. Restore original default_price pointers (must come last — Stripe
     may reject setting an archived price as a product default).

Record sources (first match wins):
  1. --record <path> — an explicit rollback record, e.g. the tracked,
     sanitized record committed to the repo:
       _a4_stripe/rollback_records/live_catalog_migration_2026-07-20.json
  2. out/<mode>/migration_log.json — the MERGED runtime log that
     accumulates across every apply run (v2 migration never overwrites
     it). This directory is git-ignored (runtime data).

Both formats share the same fields ("archived", "default_price_changes")
so either restores the full pre-migration state. Handles the
crash-safety convention: an entry recorded but never executed rolls
back as a harmless no-op (re-activating an active object / restoring
an unchanged default succeeds idempotently).

Subscriptions, customers and invoices were never touched in either
direction. Objects archived OUTSIDE these migration runs (e.g. the
pre-existing archived legacy price) are not in the record and are
correctly left untouched.

Usage:
    .venv/Scripts/python _a4_stripe/stripe_rollback.py --key-file _a4_stripe/key.txt
    .venv/Scripts/python _a4_stripe/stripe_rollback.py --key-file _a4_stripe/key.txt \
        --record _a4_stripe/rollback_records/live_catalog_migration_2026-07-20.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import stripe

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_util import load_stripe_key  # noqa: E402

OUT_ROOT = Path(__file__).resolve().parent / "out"


def die(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)


def main() -> None:
    key, mode = load_stripe_key()

    # Explicit tracked record takes precedence over the runtime log.
    if "--record" in sys.argv:
        idx = sys.argv.index("--record")
        if idx + 1 >= len(sys.argv):
            die("--record requires a path argument.")
        log_path = Path(sys.argv[idx + 1])
        if not log_path.exists():
            die(f"rollback record not found: {log_path}")
    else:
        log_path = OUT_ROOT / mode / "migration_log.json"
        if not log_path.exists():
            die(f"no migration log at {log_path} — nothing to roll back. "
                f"(A tracked record can be supplied with --record <path>.)")

    log = json.loads(log_path.read_text(encoding="utf-8"))
    record_mode = log.get("mode")
    if record_mode and record_mode != mode:
        die(f"record is for {record_mode.upper()} mode but the key is "
            f"{mode.upper()} — refusing.")
    print(f"Using rollback record: {log_path}")
    archived = log.get("archived") or []
    default_changes = log.get("default_price_changes") or []
    if not archived and not default_changes:
        die("migration log contains no recorded mutations.")

    stripe.api_key = key
    stripe.max_network_retries = 2

    products = [e for e in archived if e["kind"] == "product"]
    prices = [e for e in archived if e["kind"] == "price"]

    print(f"Rolling back in {mode.upper()} mode: "
          f"{len(products)} product(s), {len(prices)} price(s), "
          f"{len(default_changes)} default-price pointer(s)...")

    # 1 — products first
    for e in products:
        stripe.Product.modify(e["id"], active=True)
        print(f"re-activated product {e['id']}  {e.get('label')}")

    # 2 — prices
    for e in prices:
        stripe.Price.modify(e["id"], active=True)
        print(f"re-activated price {e['id']}  {e.get('label')}")

    # 3 — default_price pointers last
    for e in default_changes:
        stripe.Product.modify(
            e["product"], default_price=e["previous_default_price"]
        )
        print(f"restored default_price on {e['product']} → "
              f"{e['previous_default_price']}")

    print("Rollback complete — catalog restored to its pre-migration state.")


if __name__ == "__main__":
    main()
