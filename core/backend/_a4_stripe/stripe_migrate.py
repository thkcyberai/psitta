"""A4 Stripe catalog migration — archive retired products/prices. v2

APPROVED SCOPE (Writing Nook Product Consolidation, package A4):
  * Writing Nook becomes the only sellable subscription.
  * Reading Nook + Creative Nook products and prices → ARCHIVED
    (active=false). Never deleted. Archived prices keep billing any
    existing subscriptions (Stripe guarantee).
  * Writing Nook products + prices → untouched, must remain active.
  * Subscriptions, customers, invoices, webhooks, portal → NEVER
    touched.

v2 (2026-07-20) — lessons from the partial 3/10 production run:
  * DEFAULT PRICES: Stripe refuses to archive a price that is its
    product's default ("This price cannot be archived because it is
    the default price of its product"). v2 clears the product's
    default_price pointer first (recording the original for rollback),
    then archives the price. Fallback: if clearing fails, the product
    is archived first and the price archive retried.
  * LOG MERGING: v1 overwrote migration_log.json on every run — a
    resumed run destroyed the previous run's rollback record. v2 MERGES:
    archived entries and default_price changes accumulate across runs;
    nothing is ever dropped.
  * RESUMABILITY: the action list is always computed from LIVE state,
    so already-archived objects are skipped automatically; re-running
    after a partial failure archives only what remains.
  * ORDERING: default-clears → prices → products (rollback runs the
    exact inverse).

Usage (run from core/backend with the repo .venv):
    .venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt            (DRY RUN)
    .venv/Scripts/python _a4_stripe/stripe_migrate.py --key-file _a4_stripe/key.txt --apply    (EXECUTE)
"""

from __future__ import annotations

import json
import sys
from datetime import UTC, datetime
from pathlib import Path

import stripe

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_util import load_stripe_key  # noqa: E402

OUT_ROOT = Path(__file__).resolve().parent / "out"
RETIRED_MARKERS = ("reading", "creativ")  # creative / creativity
PROTECTED_MARKER = "writing"


def as_dict(obj) -> dict:
    """StripeObject → plain dict (json round-trip); see stripe_audit.py."""
    return json.loads(str(obj))


def die(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)


def family_of(text: str) -> str:
    t = text.lower()
    if PROTECTED_MARKER in t:
        return "writing"
    for m in RETIRED_MARKERS:
        if m in t:
            return "retired"
    return "other"


def load_existing_log(path: Path) -> dict:
    """Load a previous migration log to merge into (never overwrite)."""
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            # Never lose an unreadable previous log — preserve it aside.
            backup = path.with_suffix(".corrupt.bak.json")
            backup.write_bytes(path.read_bytes())
            print(f"WARNING: previous log unreadable — preserved at {backup}")
    return {}


def main() -> None:
    apply = "--apply" in sys.argv
    key, mode = load_stripe_key()

    stripe.api_key = key
    stripe.max_network_retries = 2

    print(
        f"Stripe A4 migration v2 — {mode.upper()} mode — "
        f"{'APPLY' if apply else 'DRY RUN (no changes)'}"
    )

    products = [
        as_dict(p)
        for p in stripe.Product.list(limit=100, active=None).auto_paging_iter()
    ]
    prices = [
        as_dict(pr)
        for pr in stripe.Price.list(limit=100, active=None).auto_paging_iter()
    ]
    prod_by_id = {p["id"]: p for p in products}
    prod_name = {p["id"]: (p.get("name") or "") for p in products}

    def price_family(pr: dict) -> str:
        return family_of(
            f"{pr.get('lookup_key') or ''} {prod_name.get(pr.get('product'), '')}"
        )

    # ── Compute remaining work from LIVE state (resume-safe) ─────────────
    retired_prices = [
        pr for pr in prices if price_family(pr) == "retired" and pr.get("active")
    ]
    retired_products = [
        p for p in products
        if family_of(p.get("name") or "") == "retired" and p.get("active")
    ]
    already_archived_prices = [
        pr for pr in prices if price_family(pr) == "retired" and not pr.get("active")
    ]
    already_archived_products = [
        p for p in products
        if family_of(p.get("name") or "") == "retired" and not p.get("active")
    ]

    # Default-price clears needed: a retired ACTIVE product whose
    # default_price points at a price we are about to archive (or at any
    # retired price still active).
    retired_price_ids = {pr["id"] for pr in retired_prices}
    default_clears = []  # (product_id, original_default_price_id)
    for p in retired_products:
        dp = p.get("default_price")
        if dp and dp in retired_price_ids:
            default_clears.append((p["id"], dp))

    # ── Safety assertions ────────────────────────────────────────────────
    for pr in retired_prices:
        label = f"{pr.get('lookup_key') or pr['id']} ({prod_name.get(pr.get('product'), '?')})"
        if PROTECTED_MARKER in label.lower():
            die(f"safety: refusing — Writing object matched retire set: {label}")
    for p in retired_products:
        if PROTECTED_MARKER in (p.get("name") or "").lower():
            die(f"safety: refusing — Writing product matched retire set: {p.get('name')}")
    writing_active_prices = [
        pr for pr in prices if pr.get("active") and price_family(pr) == "writing"
    ]
    if not writing_active_prices:
        die(
            "safety: no ACTIVE Writing Nook price found in this mode — "
            "aborting (the only sellable product must exist before "
            "retiring the others)."
        )
    # Never clear/modify a default on a non-retired product.
    for pid, _ in default_clears:
        if family_of(prod_name.get(pid, "")) != "retired":
            die(f"safety: default-clear targeted a non-retired product: {pid}")

    # ── Report the plan ──────────────────────────────────────────────────
    print(f"\nActive Writing prices preserved: "
          f"{sorted(pr.get('lookup_key') or pr['id'] for pr in writing_active_prices)}")
    if already_archived_prices or already_archived_products:
        print(f"Already archived (skipped): "
              f"{[x['id'] for x in already_archived_prices + already_archived_products]}")
    print(f"\nStep 1 — clear default_price on {len(default_clears)} product(s):")
    for pid, dp in default_clears:
        print(f"  - {pid} ({prod_name.get(pid)}): default {dp} → (none)")
    print(f"Step 2 — archive {len(retired_prices)} price(s):")
    for pr in retired_prices:
        print(f"  - {pr['id']}  {pr.get('lookup_key') or '(no lookup key)'} "
              f"({prod_name.get(pr.get('product'), '?')})")
    print(f"Step 3 — archive {len(retired_products)} product(s):")
    for p in retired_products:
        print(f"  - {p['id']}  {p.get('name')}")
    total = len(retired_prices) + len(retired_products)
    if total == 0 and not default_clears:
        print("\nNothing to do — catalog already consolidated.")

    out_dir = OUT_ROOT / mode
    out_dir.mkdir(parents=True, exist_ok=True)
    log_path = out_dir / "migration_log.json"

    if not apply:
        plan = {
            "generated_at": datetime.now(UTC).isoformat(),
            "mode": mode,
            "applied": False,
            "default_clears": [
                {"product": pid, "previous_default_price": dp}
                for pid, dp in default_clears
            ],
            "prices_to_archive": [pr["id"] for pr in retired_prices],
            "products_to_archive": [p["id"] for p in retired_products],
            "writing_prices_preserved": [
                {"id": pr["id"], "lookup_key": pr.get("lookup_key")}
                for pr in writing_active_prices
            ],
        }
        (out_dir / "migration_dryrun.json").write_text(
            json.dumps(plan, indent=2), encoding="utf-8"
        )
        print(f"\nDRY RUN complete — plan → {out_dir / 'migration_dryrun.json'}. "
              f"Re-run with --apply.")
        return

    # ── APPLY — merge-safe logging ───────────────────────────────────────
    log = load_existing_log(log_path)
    log.setdefault("mode", mode)
    log["applied"] = True
    log.setdefault("archived", [])
    log.setdefault("default_price_changes", [])
    log.setdefault("runs", [])
    run_record = {"started_at": datetime.now(UTC).isoformat(), "actions": []}
    log["runs"].append(run_record)
    logged_archived_ids = {e["id"] for e in log["archived"]}
    logged_default_products = {e["product"] for e in log["default_price_changes"]}

    def save_log():
        log["updated_at"] = datetime.now(UTC).isoformat()
        log_path.write_text(json.dumps(log, indent=2), encoding="utf-8")

    def record_archive(kind: str, obj_id: str, label: str):
        run_record["actions"].append({"kind": kind, "id": obj_id})
        if obj_id not in logged_archived_ids:
            log["archived"].append(
                {"kind": kind, "id": obj_id, "label": label, "previous_active": True}
            )
            logged_archived_ids.add(obj_id)
        save_log()

    def record_default_clear(product_id: str, previous: str):
        run_record["actions"].append(
            {"kind": "default_clear", "product": product_id}
        )
        if product_id not in logged_default_products:
            log["default_price_changes"].append(
                {"product": product_id, "previous_default_price": previous}
            )
            logged_default_products.add(product_id)
        save_log()

    try:
        # Step 1 — clear defaults (recorded BEFORE the API call so a
        # crash can never leave an unrecorded mutation).
        for pid, dp in default_clears:
            record_default_clear(pid, dp)
            stripe.Product.modify(pid, default_price="")
            print(f"cleared default_price on {pid} (was {dp})")

        # Step 2 — archive prices (record BEFORE each mutation: a crash
        # can leave a recorded-but-unexecuted action, which rollback
        # handles as a harmless no-op — never an unrecorded mutation).
        for pr in retired_prices:
            label = (f"{pr.get('lookup_key') or pr['id']} "
                     f"({prod_name.get(pr.get('product'), '?')})")
            record_archive("price", pr["id"], label)
            try:
                stripe.Price.modify(pr["id"], active=False)
            except stripe.StripeError as exc:
                if "default price" in str(exc).lower():
                    # Fallback: archive the owning product first, retry.
                    owner = pr.get("product")
                    owner_prod = prod_by_id.get(owner, {})
                    if family_of(owner_prod.get("name") or "") != "retired":
                        raise  # never touch a non-retired product
                    record_archive("product", owner, owner_prod.get("name") or owner)
                    stripe.Product.modify(owner, active=False)
                    print(f"archived product {owner} (fallback for default price)")
                    stripe.Price.modify(pr["id"], active=False)
                else:
                    raise
            print(f"archived price {pr['id']}  {label}")

        # Step 3 — archive products (skip any archived by the fallback)
        for p in retired_products:
            if p["id"] in logged_archived_ids:
                continue
            record_archive("product", p["id"], p.get("name") or p["id"])
            stripe.Product.modify(p["id"], active=False)
            print(f"archived product {p['id']}  {p.get('name')}")
    finally:
        run_record["finished_at"] = datetime.now(UTC).isoformat()
        save_log()
        print(f"\nMigration log (merged, never overwritten) → {log_path}")

    print("Done. Nothing was deleted; subscriptions/customers untouched.")


if __name__ == "__main__":
    main()
