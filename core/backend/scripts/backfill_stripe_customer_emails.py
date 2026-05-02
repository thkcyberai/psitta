"""
One-off backfill for Stripe Customer records whose `email` field
diverges from the user's current email in our `users` table (Bug B).

Generated 2026-05-02. After this script has been run successfully in
production, it should be moved to core/backend/scripts/archive/ in a
future commit (do not delete -- keep as audit trail).

Background:
  Before the forward fix, api/v1/billing.py only set the Stripe Customer
  email at creation time (stripe.Customer.create on the user's first
  /billing/checkout-session call). If the user subsequently changed
  their email in Cognito, the Stripe-side record stayed stuck on the
  original address. Stripe Dashboard, billing portal, and receipt
  emails all displayed the stale value.

  The forward fix in billing.py step 4a calls stripe.Customer.modify on
  every checkout-session creation, so any future address change is
  picked up the next time the user starts a checkout. This script
  reconciles records that were already stale at the moment of the fix.

  For each row in stripe_customers:
    1. Resolve the user's current email from the users table.
    2. Retrieve the Stripe Customer and read its email.
    3. If they differ AND the user's email is non-empty, call
       stripe.Customer.modify(cust_id, email=user_email).

Idempotency:
  A second run after a successful first run produces zero `updated`
  rows (every row falls into `skipped_match`). Safe to re-run if
  interrupted.

Safety:
  --dry-run still calls Stripe (cheap reads) so the output reflects
  the exact values that WOULD be written. The modify is skipped per
  row.
  --limit N processes only the first N rows; useful for smoke-testing
  a single row before letting the script loose on the full set.

Run modes:
  Local with DATABASE_URL or POSTGRES_* env vars:
      python scripts/backfill_stripe_customer_emails.py --dry-run --limit 1

  ECS one-off task (production):
      aws ecs run-task ... --overrides '{...
          command: [
              "python",
              "scripts/backfill_stripe_customer_emails.py",
              "--dry-run", "--limit", "1"
          ]
      ...}'

  Production hosts inject Postgres credentials and Stripe secret key
  via the APP_SECRETS env var (a single JSON blob from Secrets
  Manager); local hosts typically use individual env vars. The script
  reads whichever is present.

Exit codes:
  0  -- completed, no row-level errors
  1  -- completed, one or more rows hit recoverable errors (404,
        rate-limit-after-retries, other Stripe / DB error). Other rows
        still committed.
  2  -- systemic failure (DB connection, missing config). Aborted.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
from typing import Any

import stripe
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("backfill_emails")


def _resolve_secrets() -> dict[str, Any]:
    """Resolve Postgres + Stripe config from env or APP_SECRETS blob.

    Returns a dict with keys: pg (asyncpg.connect kwargs) and
    stripe_key (the secret value to assign to stripe.api_key).
    """
    secrets: dict[str, Any] = {}
    raw = os.environ.get("APP_SECRETS")
    if raw:
        try:
            secrets = json.loads(raw)
        except json.JSONDecodeError:
            log.warning("APP_SECRETS is set but is not valid JSON; ignoring")

    def cfg(key: str, default: Any = None) -> Any:
        return os.environ.get(key) or secrets.get(key) or default

    host = cfg("POSTGRES_HOST")
    if not host:
        raise SystemExit(
            "ERROR: no Postgres host -- set POSTGRES_HOST or APP_SECRETS"
        )

    stripe_key = cfg("STRIPE_SECRET_KEY_TEST")
    if not stripe_key:
        raise SystemExit(
            "ERROR: no Stripe key -- set STRIPE_SECRET_KEY_TEST or APP_SECRETS"
        )

    return {
        "pg": {
            "host": host,
            "port": int(cfg("POSTGRES_PORT", 5432)),
            "user": cfg("POSTGRES_USER"),
            "password": cfg("POSTGRES_PASSWORD"),
            "database": cfg("POSTGRES_DB"),
        },
        "stripe_key": stripe_key,
    }


async def _fetch_customer_rows(
    conn: Any, limit: int | None
) -> list[dict[str, Any]]:
    """Return stripe_customers rows joined with the user's current email."""
    query = """
        SELECT sc.stripe_customer_id, u.email AS user_email
        FROM stripe_customers sc
        JOIN users u ON u.id = sc.user_id
        ORDER BY sc.created_at
    """
    if limit is not None:
        query += f"\n        LIMIT {int(limit)}"
    rows = await conn.fetch(query)
    return [dict(r) for r in rows]


# Retry on RateLimitError up to 3 attempts with exponential backoff
# (1s, 2s waits between attempts). Other StripeErrors propagate
# immediately so the per-row handler can classify and skip.
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=4),
    retry=retry_if_exception_type(stripe.RateLimitError),
    reraise=True,
)
def _fetch_stripe_customer(cust_id: str) -> Any:
    """Fetch a Stripe Customer for email comparison."""
    return stripe.Customer.retrieve(cust_id)


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=4),
    retry=retry_if_exception_type(stripe.RateLimitError),
    reraise=True,
)
def _modify_stripe_customer(cust_id: str, email: str) -> None:
    """Update the Stripe Customer's email field."""
    stripe.Customer.modify(cust_id, email=email)


async def _process_row(
    row: dict[str, Any],
    *,
    dry_run: bool,
) -> str:
    """Process one row. Returns the counter bucket name to increment.

    Buckets: updated, skipped_match, skipped_no_user_email,
    error_404, error_rate_limit, error_other.
    """
    cust_id = row["stripe_customer_id"]
    user_email = (row["user_email"] or "").strip()

    if not user_email:
        log.warning(
            "skipped_no_user_email  customer=%s  "
            "(users.email is empty — refusing to wipe Stripe)",
            cust_id,
        )
        return "skipped_no_user_email"

    bucket = "error_other"

    try:
        sc = _fetch_stripe_customer(cust_id)
    except stripe.InvalidRequestError as exc:
        # 404 / resource_missing — Stripe Customer was deleted.
        log.error(
            "error_404         customer=%s  message=%s",
            cust_id,
            getattr(exc, "user_message", str(exc)),
        )
        bucket = "error_404"
    except stripe.RateLimitError as exc:
        log.error(
            "error_rate_limit  customer=%s  message=%s "
            "(retries exhausted)",
            cust_id,
            str(exc),
        )
        bucket = "error_rate_limit"
    except stripe.StripeError as exc:
        log.error(
            "error_other       customer=%s  type=%s  message=%s",
            cust_id,
            type(exc).__name__,
            str(exc),
        )
        bucket = "error_other"
    else:
        stripe_email = (getattr(sc, "email", None) or "").strip()

        if stripe_email == user_email:
            log.info(
                "skipped_match     customer=%s  email=%s",
                cust_id,
                user_email,
            )
            bucket = "skipped_match"
        elif dry_run:
            log.info(
                "DRY RUN           customer=%s  would_update old=%s  new=%s",
                cust_id,
                stripe_email or "<empty>",
                user_email,
            )
            bucket = "updated"
        else:
            try:
                _modify_stripe_customer(cust_id, user_email)
            except stripe.RateLimitError as exc:
                log.error(
                    "error_rate_limit  customer=%s  message=%s "
                    "(modify, retries exhausted)",
                    cust_id,
                    str(exc),
                )
                bucket = "error_rate_limit"
            except stripe.StripeError as exc:
                log.error(
                    "error_other       customer=%s  type=%s  message=%s",
                    cust_id,
                    type(exc).__name__,
                    str(exc),
                )
                bucket = "error_other"
            else:
                log.info(
                    "updated           customer=%s  old=%s  new=%s",
                    cust_id,
                    stripe_email or "<empty>",
                    user_email,
                )
                bucket = "updated"

    return bucket


async def run(*, dry_run: bool, limit: int | None) -> int:
    """Backfill main loop. Returns process exit code."""
    import asyncpg  # noqa: PLC0415 -- lazy so DB driver isn't required for --help

    config = _resolve_secrets()
    stripe.api_key = config["stripe_key"]

    pg_cfg = config["pg"]
    log.info(
        "Connecting to Postgres host=%s db=%s user=%s",
        pg_cfg["host"],
        pg_cfg["database"],
        pg_cfg["user"],
    )
    try:
        conn = await asyncpg.connect(**pg_cfg)
    except Exception as exc:
        log.error("Postgres connection failed: %s", exc)
        return 2

    counters = {
        "updated": 0,
        "skipped_match": 0,
        "skipped_no_user_email": 0,
        "error_404": 0,
        "error_rate_limit": 0,
        "error_other": 0,
    }

    try:
        rows = await _fetch_customer_rows(conn, limit)
        log.info(
            "Found %d stripe_customers row(s) to inspect%s",
            len(rows),
            f" (limit={limit})" if limit is not None else "",
        )

        for r in rows:
            try:
                bucket = await _process_row(r, dry_run=dry_run)
                counters[bucket] += 1
            except Exception as exc:
                # Catch-all for any per-row exception not mapped above.
                # Log + count as error_other; do NOT abort the loop.
                log.error(
                    "error_other       customer=%s  type=%s  message=%s",
                    r.get("stripe_customer_id"),
                    type(exc).__name__,
                    str(exc),
                )
                counters["error_other"] += 1
    finally:
        await conn.close()

    log.info(
        "Summary: updated=%d  skipped_match=%d  "
        "skipped_no_user_email=%d  "
        "error_404=%d  error_rate_limit=%d  error_other=%d",
        counters["updated"],
        counters["skipped_match"],
        counters["skipped_no_user_email"],
        counters["error_404"],
        counters["error_rate_limit"],
        counters["error_other"],
    )

    error_total = (
        counters["error_404"]
        + counters["error_rate_limit"]
        + counters["error_other"]
    )
    return 0 if error_total == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Backfill Stripe Customer email to match users.email "
            "for records whose email diverged before the Bug B fix."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Call Stripe to fetch values, log what WOULD be written, "
            "but skip the modify. Use this first."
        ),
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        metavar="N",
        help=(
            "Process only the first N rows (ordered by created_at). "
            "Useful for smoke-testing a single row before running on "
            "the full set."
        ),
    )
    args = parser.parse_args(argv)
    return asyncio.run(run(dry_run=args.dry_run, limit=args.limit))


if __name__ == "__main__":
    sys.exit(main())
