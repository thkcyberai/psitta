"""
One-off backfill for subscriptions rows with NULL current_period_start /
current_period_end after the Stripe Basil API regression.

Generated 2026-05-02. After this script has been run successfully in
production, it should be moved to core/backend/scripts/archive/ in a
future commit (do not delete -- keep as audit trail).

Background:
  Stripe API "Basil" (March 2025) moved current_period_start and
  current_period_end from the Subscription root onto each subscription
  item (items.data[N]). The webhook handlers in services/billing_handlers.py
  were reading from the (now-absent) root keys via sub.get(...), which
  silently returned None. Every subscription written between the SDK
  upgrade to v15.x and the fix in commit f47a84b (2026-05-02) has NULL
  period dates in the local subscriptions table.

  The handlers were patched in f47a84b to read from items.data[0]. This
  script reconciles the rows that were already corrupt at the moment of
  the fix. It walks every subscriptions row where current_period_end IS
  NULL OR current_period_start IS NULL, calls Stripe to fetch the
  current values from items.data[0], and UPDATEs the local row.

Idempotency:
  The query filter excludes rows already populated. A second run after
  a successful first run processes zero rows.

Safety:
  --dry-run still calls Stripe (cheap reads) so the output reflects the
  exact values that WOULD be written. The UPDATE is skipped per row.
  --limit N processes only the first N rows; useful for smoke-testing a
  single row before letting the script loose on the full set.

Run modes:
  Local with DATABASE_URL or POSTGRES_* env vars:
      python scripts/backfill_subscription_periods.py --dry-run --limit 1

  ECS one-off task (production):
      aws ecs run-task ... --overrides '{...
          command: [
              "python",
              "scripts/backfill_subscription_periods.py",
              "--dry-run", "--limit", "1"
          ]
      ...}'

  Production hosts inject Postgres credentials and Stripe secret key via
  the APP_SECRETS env var (a single JSON blob from Secrets Manager);
  local hosts typically use individual env vars. The script reads
  whichever is present.

Exit codes:
  0  -- completed, no row-level errors
  1  -- completed, one or more rows hit recoverable errors (404, empty
        items, rate-limit-after-retries). Other rows still committed.
  2  -- systemic failure (DB connection, missing config). Aborted.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
from datetime import UTC, datetime
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
log = logging.getLogger("backfill_periods")


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


async def _fetch_null_period_rows(conn: Any, limit: int | None) -> list[dict[str, Any]]:
    """Return subscriptions rows with NULL period_start OR period_end."""
    query = """
        SELECT id, stripe_subscription_id, status, lookup_key,
               current_period_start, current_period_end
        FROM subscriptions
        WHERE current_period_end IS NULL
           OR current_period_start IS NULL
        ORDER BY created_at
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
def _fetch_stripe_subscription(sub_id: str) -> Any:
    """Fetch a Stripe Subscription with item details expanded.

    Returned object is the raw stripe.Subscription -- callers should
    access .items.data[0].current_period_{start,end}.
    """
    return stripe.Subscription.retrieve(sub_id, expand=["items"])


def _ts_to_dt(ts: int | None) -> datetime | None:
    """Convert a Stripe Unix timestamp to an aware UTC datetime."""
    if ts is None:
        return None
    return datetime.fromtimestamp(int(ts), tz=UTC)


async def _update_periods(
    conn: Any,
    row_id: Any,
    period_start: datetime,
    period_end: datetime,
) -> None:
    """UPDATE the subscriptions row with the period values from Stripe.

    Each call is its own statement; transactions are managed per-row by
    the caller so a Stripe failure mid-loop preserves prior progress.
    """
    await conn.execute(
        """
        UPDATE subscriptions
        SET current_period_start = $1,
            current_period_end = $2,
            updated_at = NOW()
        WHERE id = $3::uuid
        """,
        period_start,
        period_end,
        str(row_id),
    )


async def _process_row(
    conn: Any,
    row: dict[str, Any],
    *,
    dry_run: bool,
) -> str:
    """Process one row. Returns the counter bucket name to increment.

    Buckets: updated, skipped_no_data, error_404, error_no_items,
    error_rate_limit, error_other.
    """
    sub_id = row["stripe_subscription_id"]
    row_id = row["id"]
    bucket = "error_other"

    try:
        sub = _fetch_stripe_subscription(sub_id)
    except stripe.InvalidRequestError as exc:
        # 404 / resource_missing — sub was deleted from Stripe entirely.
        log.error(
            "error_404         stripe_sub=%s  message=%s",
            sub_id,
            getattr(exc, "user_message", str(exc)),
        )
        return "error_404"
    except stripe.RateLimitError as exc:
        # Reraised from tenacity after retries exhausted.
        log.error(
            "error_rate_limit  stripe_sub=%s  message=%s "
            "(retries exhausted)",
            sub_id,
            str(exc),
        )
        return "error_rate_limit"
    except stripe.StripeError as exc:
        log.error(
            "error_other       stripe_sub=%s  type=%s  message=%s",
            sub_id,
            type(exc).__name__,
            str(exc),
        )
        return "error_other"

    items = getattr(sub, "items", None)
    items_data = getattr(items, "data", None) if items is not None else None
    if not items_data:
        log.warning(
            "error_no_items    stripe_sub=%s  (subscription has no items)",
            sub_id,
        )
        bucket = "error_no_items"
    else:
        item = items_data[0]
        period_start = _ts_to_dt(getattr(item, "current_period_start", None))
        period_end = _ts_to_dt(getattr(item, "current_period_end", None))

        if period_start is None or period_end is None:
            log.warning(
                "skipped_no_data   stripe_sub=%s  start=%s  end=%s "
                "(Stripe returned NULL — leaving row untouched)",
                sub_id,
                period_start,
                period_end,
            )
            bucket = "skipped_no_data"
        elif dry_run:
            log.info(
                "DRY RUN           stripe_sub=%s  would_set start=%s  end=%s",
                sub_id,
                period_start.isoformat(),
                period_end.isoformat(),
            )
            bucket = "updated"
        else:
            # Real run: row-by-row transaction so a later failure can't
            # rollback prior progress.
            async with conn.transaction():
                await _update_periods(conn, row_id, period_start, period_end)
            log.info(
                "updated           stripe_sub=%s  start=%s  end=%s",
                sub_id,
                period_start.isoformat(),
                period_end.isoformat(),
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
        "skipped_no_data": 0,
        "error_404": 0,
        "error_no_items": 0,
        "error_rate_limit": 0,
        "error_other": 0,
    }

    try:
        rows = await _fetch_null_period_rows(conn, limit)
        log.info(
            "Found %d subscriptions row(s) with NULL period dates%s",
            len(rows),
            f" (limit={limit})" if limit is not None else "",
        )

        for r in rows:
            try:
                bucket = await _process_row(conn, r, dry_run=dry_run)
                counters[bucket] += 1
            except Exception as exc:
                # Catch-all for any per-row exception not mapped above
                # (e.g. asyncpg DB-level error). Log + count as
                # error_other; do NOT abort the loop.
                log.error(
                    "error_other       stripe_sub=%s  type=%s  message=%s",
                    r.get("stripe_subscription_id"),
                    type(exc).__name__,
                    str(exc),
                )
                counters["error_other"] += 1
    finally:
        await conn.close()

    log.info(
        "Summary: updated=%d  skipped_no_data=%d  "
        "error_404=%d  error_no_items=%d  "
        "error_rate_limit=%d  error_other=%d",
        counters["updated"],
        counters["skipped_no_data"],
        counters["error_404"],
        counters["error_no_items"],
        counters["error_rate_limit"],
        counters["error_other"],
    )

    error_total = (
        counters["error_404"]
        + counters["error_no_items"]
        + counters["error_rate_limit"]
        + counters["error_other"]
    )
    return 0 if error_total == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Backfill subscriptions.current_period_{start,end} for "
            "rows that were written with NULL after the Stripe Basil "
            "API regression."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Call Stripe to fetch values, log what WOULD be written, "
            "but skip the UPDATE. Use this first."
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
