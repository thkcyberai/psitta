"""A4 Stripe account audit — READ-ONLY inventory (no mutations).

Usage (run from core/backend with the repo .venv):
    set STRIPE_API_KEY=sk_test_...        (or sk_live_...)
    .venv\\Scripts\\python _a4_stripe\\stripe_audit.py

The key is read from the STRIPE_API_KEY environment variable only —
never from a file, never echoed, never written to any output. Mode
(test/live) is detected from the key prefix and the results land in
    _a4_stripe/out/<mode>/inventory.json
    _a4_stripe/out/<mode>/inventory.md

Collected: account id, products (incl. archived), prices (with
lookup_keys and any price-level trial_period_days — which would STACK
with the code-level 14-day trial in billing.py and must be 0/None),
subscriptions grouped by product/status (reading/writing/creative
breakdown), webhook endpoints, and Customer Portal configurations.
"""

from __future__ import annotations

import json
import sys
from collections import Counter
from datetime import UTC, datetime
from pathlib import Path

import stripe

sys.path.insert(0, str(Path(__file__).resolve().parent))
from key_util import load_stripe_key  # noqa: E402

OUT_ROOT = Path(__file__).resolve().parent / "out"


def as_dict(obj) -> dict:
    """Convert a StripeObject tree to plain dicts (json round-trip).

    Mirrors psitta.services.billing_handlers.stripe_obj_to_dict — the
    Stripe SDK's StripeObject.__getattr__ raises AttributeError for
    missing keys, so a routine ``obj.get("x")`` can blow up with
    ``AttributeError: get``. StripeObject.__str__ emits the full JSON
    dump, so json.loads(str(obj)) is the canonical deep conversion;
    every fetched object is converted ONCE, immediately, and all
    downstream access uses standard mapping operations.
    """
    return json.loads(str(obj))


def die(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)


def classify(lookup_key: str | None, product_name: str | None) -> str:
    text = f"{lookup_key or ''} {product_name or ''}".lower()
    if "reading" in text:
        return "reading"
    if "writing" in text:
        return "writing"
    if "creativ" in text:  # creative / creativity
        return "creative"
    return "other"


def main() -> None:
    key, mode = load_stripe_key()

    stripe.api_key = key
    stripe.max_network_retries = 2

    print(f"Auditing Stripe account in {mode.upper()} mode (read-only)...")

    account = as_dict(stripe.Account.retrieve())

    products = []
    for p_raw in stripe.Product.list(limit=100, active=None).auto_paging_iter():
        p = as_dict(p_raw)
        products.append({
            "id": p.get("id"),
            "name": p.get("name"),
            "active": p.get("active"),
            "default_price": p.get("default_price"),
            "created": p.get("created"),
            "metadata": dict(p.get("metadata") or {}),
        })
    prod_name = {p["id"]: p["name"] for p in products}

    prices = []
    for pr_raw in stripe.Price.list(limit=100, active=None).auto_paging_iter():
        pr = as_dict(pr_raw)
        rec = pr.get("recurring") or {}
        prices.append({
            "id": pr.get("id"),
            "lookup_key": pr.get("lookup_key"),
            "product": pr.get("product"),
            "product_name": prod_name.get(pr.get("product")),
            "active": pr.get("active"),
            "currency": pr.get("currency"),
            "unit_amount": pr.get("unit_amount"),
            "interval": rec.get("interval"),
            "price_level_trial_period_days": rec.get("trial_period_days"),
            "family": classify(pr.get("lookup_key"), prod_name.get(pr.get("product"))),
        })

    subs = []
    for s_raw in stripe.Subscription.list(
        limit=100, status="all"
    ).auto_paging_iter():
        s = as_dict(s_raw)
        items = (s.get("items") or {}).get("data") or []
        price = (items[0].get("price") or {}) if items else {}
        lk = price.get("lookup_key")
        pname = prod_name.get(price.get("product"))
        cust = s.get("customer")
        email = None
        try:
            c = as_dict(stripe.Customer.retrieve(cust))
            email = c.get("email")
        except Exception:
            pass
        subs.append({
            "id": s.get("id"),
            "status": s.get("status"),
            "customer": cust,
            "customer_email": email,
            "lookup_key": lk,
            "product_name": pname,
            "family": classify(lk, pname),
            "cancel_at_period_end": s.get("cancel_at_period_end"),
            "canceled_at": s.get("canceled_at"),
            "trial_end": s.get("trial_end"),
            "created": s.get("created"),
        })

    webhooks = []
    for w_raw in stripe.WebhookEndpoint.list(limit=100).auto_paging_iter():
        w = as_dict(w_raw)
        webhooks.append({
            "id": w.get("id"),
            "url": w.get("url"),
            "status": w.get("status"),
            "api_version": w.get("api_version"),
            "enabled_events": list(w.get("enabled_events") or []),
        })

    portals = []
    try:
        for cfg_raw in stripe.billing_portal.Configuration.list(
            limit=100
        ).auto_paging_iter():
            cfg = as_dict(cfg_raw)
            feats = cfg.get("features") or {}
            sub_upd = feats.get("subscription_update") or {}
            portals.append({
                "id": cfg.get("id"),
                "is_default": cfg.get("is_default"),
                "active": cfg.get("active"),
                "cancel_enabled": (feats.get("subscription_cancel") or {}).get("enabled"),
                "payment_method_update": (feats.get("payment_method_update") or {}).get("enabled"),
                "subscription_update_enabled": sub_upd.get("enabled"),
                "subscription_update_products": sub_upd.get("products"),
            })
    except Exception as exc:  # portal API may be unconfigured
        portals = [{"error": str(exc)}]

    live_states = ("active", "trialing", "past_due")
    sub_counts = Counter((s["family"], s["status"]) for s in subs)
    inventory = {
        "generated_at": datetime.now(UTC).isoformat(),
        "mode": mode,
        "account_id": account.get("id"),
        "products": products,
        "prices": prices,
        "subscriptions": subs,
        "subscription_counts": {
            f"{fam}/{st}": n for (fam, st), n in sorted(sub_counts.items())
        },
        "webhook_endpoints": webhooks,
        "portal_configurations": portals,
    }

    out_dir = OUT_ROOT / mode
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "inventory.json").write_text(
        json.dumps(inventory, indent=2, default=str), encoding="utf-8"
    )

    lines = [
        f"# Stripe {mode.upper()} inventory — {inventory['generated_at']}",
        f"Account: {inventory['account_id']}",
        "",
        "## Products",
    ]
    for p in products:
        lines.append(
            f"- {p['id']} · {p['name']} · "
            f"{'ACTIVE' if p['active'] else 'archived'}"
        )
    lines.append("\n## Prices")
    for pr in prices:
        lines.append(
            f"- {pr['id']} · lookup={pr['lookup_key']} · {pr['family']} · "
            f"{pr['interval']} · {pr['unit_amount']} {pr['currency']} · "
            f"{'ACTIVE' if pr['active'] else 'archived'} · "
            f"price-level trial={pr['price_level_trial_period_days']}"
        )
    lines.append("\n## Subscriptions (family/status → count)")
    for k, n in inventory["subscription_counts"].items():
        lines.append(f"- {k}: {n}")
    live_reading = [
        s for s in subs if s["family"] == "reading" and s["status"] in live_states
    ]
    lines.append(
        f"\n## LIVE Reading Nook subscriptions (grandfather set): {len(live_reading)}"
    )
    for s in live_reading:
        lines.append(
            f"- {s['id']} · {s['status']} · {s['customer']} · "
            f"{s['customer_email']} · {s['lookup_key']}"
        )
    lines.append("\n## Webhook endpoints")
    for w in webhooks:
        lines.append(
            f"- {w['id']} · {w['url']} · {w['status']} · api {w['api_version']}"
        )
        lines.append(f"  events: {', '.join(w['enabled_events'])}")
    lines.append("\n## Customer Portal configurations")
    for c in portals:
        lines.append(f"- {json.dumps(c, default=str)}")
    stacking = [
        pr for pr in prices
        if pr["active"] and (pr["price_level_trial_period_days"] or 0) > 0
    ]
    lines.append("\n## Trial stacking check (must be empty)")
    lines.append(
        "OK — no active price carries a price-level trial_period_days"
        if not stacking
        else "⚠ ACTIVE prices with price-level trials (would STACK with the "
        "code-level 14-day trial): "
        + ", ".join(p["id"] for p in stacking)
    )
    (out_dir / "inventory.md").write_text("\n".join(lines), encoding="utf-8")

    print(f"OK — wrote {out_dir / 'inventory.json'}")
    print(f"OK — wrote {out_dir / 'inventory.md'}")
    print("No mutations were made.")


if __name__ == "__main__":
    main()
