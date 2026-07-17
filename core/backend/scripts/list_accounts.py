"""list_accounts.py — Read-only admin CLI: list every Psitta account and
its effective plan tier.

Every person who can access Psitta has a row in ``users``. Their *tier* is
resolved here exactly the way the app resolves it
(``services/subscription_service.get_effective_plan``), highest precedence
first:

  1. Stripe subscription   (subscriptions ⋈ stripe_customers, status=active)
  2. Dev/admin override     (user_subscriptions, status=active)
  3. Reverse-trial grant    (trial_grants, not revoked, not expired)
  4. Tester allowlist       (tester_allowlist by email, not revoked/expired)
  5. Free

READ-ONLY: issues SELECTs only, never writes. Safe to run against prod. A
source table that doesn't exist yet (e.g. ``trial_grants`` before migration
031) is skipped with a warning rather than failing the whole listing.

Run modes (mirrors scripts/grant_tester.py)
--------------------------------------------
  Production one-off ECS task::

      aws ecs run-task --cluster psitta-cluster \\
          --task-definition psitta-api --profile psitta-prod \\
          --region us-east-1 \\
          --overrides '{"containerOverrides":[{"name":"psitta-api",
            "command":["python","scripts/list_accounts.py"]}]}'

  Local (POSTGRES_* env vars or APP_SECRETS point at the target DB)::

      python scripts/list_accounts.py
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from typing import Any

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("list_accounts")


# ── Postgres config resolution (matches grant_tester.py) ────────────────
def _resolve_pg_config() -> dict[str, Any]:
    """Resolve Postgres connection params from env or APP_SECRETS blob."""
    secrets: dict[str, Any] = {}
    raw = os.environ.get("APP_SECRETS")
    if raw:
        try:
            secrets = json.loads(raw)
        except json.JSONDecodeError:
            log.warning("app_secrets_invalid_json  ignoring")

    def cfg(key: str, default: Any = None) -> Any:
        return os.environ.get(key) or secrets.get(key) or default

    host = cfg("POSTGRES_HOST")
    if not host:
        raise SystemExit(
            "ERROR: no Postgres host -- set POSTGRES_HOST or APP_SECRETS"
        )
    return {
        "host": host,
        "port": int(cfg("POSTGRES_PORT", 5432)),
        "user": cfg("POSTGRES_USER"),
        "password": cfg("POSTGRES_PASSWORD"),
        "database": cfg("POSTGRES_DB"),
    }


def _canonical(plan: str | None) -> str:
    """Map any stored plan id / Stripe lookup_key to a canonical tier
    (mirrors plan_limits._normalize_plan_id)."""
    if not plan:
        return "free"
    p = plan.lower()
    if p.startswith("reading_nook_pro") or p in ("pro_monthly", "pro_annual"):
        return "reading_nook_pro"
    if p.startswith("writing_nook_pro"):
        return "writing_nook_pro"
    if p.startswith("creativity_nook_pro") or p.startswith("creative"):
        return "creative_nook_pro"
    if p == "free":
        return "free"
    return p


async def _fetch_map(
    conn: Any, sql: str, keycol: str, valcol: str
) -> dict[Any, Any]:
    """Run ``sql``; return ``{key: val}``. Empty dict if the table is
    missing (e.g. trial_grants before migration 031)."""
    try:
        rows = await conn.fetch(sql)
    except Exception as exc:
        log.warning(
            "skip_source  error=%s", str(exc).splitlines()[0]
        )
        return {}
    return {r[keycol]: r[valcol] for r in rows}


async def run(emails: list[str] | None = None) -> int:
    import asyncpg  # noqa: PLC0415 -- lazy import keeps --help fast

    cfg = _resolve_pg_config()
    log.info(
        "pg_connect  host=%s db=%s user=%s",
        cfg["host"], cfg["database"], cfg["user"],
    )
    conn = await asyncpg.connect(**cfg)
    try:
        # Optional CLI args filter to specific emails (case-insensitive);
        # no args lists every account.
        if emails:
            users = await conn.fetch(
                "SELECT id, email, display_name, tier, created_at "
                "FROM users WHERE lower(email) = ANY($1::text[]) "
                "ORDER BY created_at",
                [e.strip().lower() for e in emails],
            )
        else:
            users = await conn.fetch(
                "SELECT id, email, display_name, tier, created_at "
                "FROM users ORDER BY created_at"
            )
        stripe = await _fetch_map(
            conn,
            "SELECT sc.user_id AS uid, s.lookup_key AS plan "
            "FROM subscriptions s "
            "JOIN stripe_customers sc ON sc.id = s.stripe_customer_id "
            "WHERE s.status = 'active'",
            "uid", "plan",
        )
        dev = await _fetch_map(
            conn,
            "SELECT user_id AS uid, plan_id AS plan "
            "FROM user_subscriptions WHERE status = 'active'",
            "uid", "plan",
        )
        trial = await _fetch_map(
            conn,
            "SELECT user_id AS uid, plan_id AS plan FROM trial_grants "
            "WHERE revoked_at IS NULL AND expires_at > NOW()",
            "uid", "plan",
        )
        allow = await _fetch_map(
            conn,
            "SELECT email, plan_id AS plan FROM tester_allowlist "
            "WHERE revoked_at IS NULL AND expires_at > NOW()",
            "email", "plan",
        )
    finally:
        await conn.close()

    counts: dict[str, int] = {}
    print(f"{len(users)} account(s):")  # noqa: T201
    print(  # noqa: T201
        f"{'email':34}  {'tier':18}  {'source':16}  created"
    )
    print("-" * 96)  # noqa: T201
    for u in users:
        uid = u["id"]
        email = (u["email"] or "").lower()
        if uid in stripe:
            tier, source = _canonical(stripe[uid]), "stripe"
        elif uid in dev:
            tier, source = _canonical(dev[uid]), "dev_override"
        elif uid in trial:
            tier, source = _canonical(trial[uid]), "reverse_trial"
        elif email in allow:
            tier, source = _canonical(allow[email]), "tester_allowlist"
        else:
            tier, source = "free", "free"
        counts[tier] = counts.get(tier, 0) + 1
        created = (
            u["created_at"].date().isoformat() if u["created_at"] else ""
        )
        print(  # noqa: T201
            f"{(u['email'] or ''):34}  {tier:18}  {source:16}  {created}"
        )

    print("-" * 96)  # noqa: T201
    print(  # noqa: T201
        "Totals: "
        + ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    )
    return 0


if __name__ == "__main__":
    # Optional positional emails filter the listing to just those accounts.
    _emails = [a for a in sys.argv[1:] if not a.startswith("-")]
    sys.exit(asyncio.run(run(_emails or None)))
