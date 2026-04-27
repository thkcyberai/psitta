"""
One-off backfill for users who paid via Stripe before Bug #1 was fixed.

Generated 2026-04-27. After this script has been run successfully in
production, it should be moved to core/backend/scripts/archive/ in a
future commit (do not delete -- keep as audit trail).

Background:
  Before fix(billing): webhook handlers now write user_subscriptions
  table (commit ce0ea14), the Stripe webhook handler only wrote rows
  to the subscriptions table. The quota enforcer reads from
  user_subscriptions, so every Stripe-paid customer was silently
  treated as Free for upload-limit purposes (CLAUDE.md Key Learning
  2026-04-23).

  This script reconciles the two tables by walking every active row
  in subscriptions and -- when no matching user_subscriptions row
  exists -- inserting one. Mirrors the in-handler logic exactly so
  the post-backfill state is functionally identical to "what would
  have happened if Bug #1 were fixed before they paid."

Idempotency:
  Re-running the script after a successful run produces zero net
  changes. The skip path triggers when an active user_subscriptions
  row already has the matching stripe_subscription_id.

Safety:
  --dry-run shows the exact INSERTs / UPDATEs that would be issued,
  rolls the transaction back, and exits 0.

Run modes:
  Local with DATABASE_URL or POSTGRES_* env vars:
      python scripts/backfill_user_subscriptions.py --dry-run

  ECS one-off task (production):
      aws ecs run-task ... --overrides '{...
          command: [
              "python",
              "scripts/backfill_user_subscriptions.py",
              "--dry-run"
          ]
      ...}'

  Production hosts inject Postgres credentials via the APP_SECRETS
  env var (a single JSON blob from Secrets Manager); local hosts
  typically use individual POSTGRES_* env vars. The script reads
  whichever is present.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any

# Mappers live in the production handler module so this script can't
# drift from the in-handler semantics.
from psitta.services.billing_handlers import _lookup_key_to_plan_id

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("backfill")


def _resolve_pg_config() -> dict[str, Any]:
    """Resolve Postgres connection params from env or APP_SECRETS blob.

    Returns a dict suitable for ``asyncpg.connect(**...)``.
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
    return {
        "host": host,
        "port": int(cfg("POSTGRES_PORT", 5432)),
        "user": cfg("POSTGRES_USER"),
        "password": cfg("POSTGRES_PASSWORD"),
        "database": cfg("POSTGRES_DB"),
    }


async def _fetch_active_subscriptions(conn: Any) -> list[dict[str, Any]]:
    """Return active rows from the Stripe-fed subscriptions table.

    Joins through stripe_customers to resolve the Psitta user_id --
    Stripe events don't carry it on the subscription resource, so we
    look it up via the customer link.
    """
    rows = await conn.fetch(
        """
        SELECT
            sc.user_id            AS user_id,
            sc.stripe_customer_id AS stripe_customer_id,
            s.stripe_subscription_id,
            s.lookup_key,
            s.status,
            s.current_period_start,
            s.current_period_end
        FROM subscriptions s
        JOIN stripe_customers sc ON sc.id = s.stripe_customer_id
        WHERE s.status = 'active'
        ORDER BY s.created_at
        """
    )
    return [dict(r) for r in rows]


async def _has_matching_user_sub(
    conn: Any,
    user_id: str,
    stripe_subscription_id: str,
) -> bool:
    """True if user_subscriptions already has an active row linked to
    this exact Stripe subscription.

    This is the idempotency check: a second run of the backfill must
    skip rows that the first run already inserted.
    """
    row = await conn.fetchrow(
        """
        SELECT id
        FROM user_subscriptions
        WHERE user_id = $1::uuid
          AND status = 'active'
          AND stripe_subscription_id = $2
        LIMIT 1
        """,
        str(user_id),
        stripe_subscription_id,
    )
    return row is not None


async def _cancel_prior_active(conn: Any, user_id: str) -> int:
    """Cancel any active user_subscriptions rows for this user that
    aren't linked to a Stripe subscription (typically dev-override
    rows). Returns row count.

    Mirrors the in-handler logic in
    handle_checkout_session_completed: one user, one active row.
    """
    result = await conn.execute(
        """
        UPDATE user_subscriptions SET
            status = 'cancelled',
            cancelled_at = NOW(),
            updated_at = NOW()
        WHERE user_id = $1::uuid AND status = 'active'
        """,
        str(user_id),
    )
    # asyncpg returns 'UPDATE N' as the result tag.
    try:
        return int(result.split()[-1])
    except Exception:
        return 0


async def _insert_user_sub(
    conn: Any,
    user_id: str,
    plan_id: str,
    stripe_subscription_id: str,
    stripe_customer_id: str,
    period_start: datetime | None,
    period_end: datetime | None,
) -> None:
    """Insert a fresh active user_subscriptions row mirroring the
    Stripe subscription. Same shape as
    handle_checkout_session_completed."""
    await conn.execute(
        """
        INSERT INTO user_subscriptions
            (user_id, plan_id, status, started_at,
             current_period_start, current_period_end,
             stripe_subscription_id, stripe_customer_id)
        VALUES
            ($1::uuid, $2, 'active', NOW(),
             $3, $4, $5, $6)
        """,
        str(user_id),
        plan_id,
        period_start,
        period_end,
        stripe_subscription_id,
        stripe_customer_id,
    )


async def run(*, dry_run: bool) -> int:
    """Backfill main loop. Returns process exit code."""
    import asyncpg  # imported lazily so --help works without the dep

    cfg = _resolve_pg_config()
    log.info(
        "Connecting to Postgres host=%s db=%s user=%s",
        cfg["host"],
        cfg["database"],
        cfg["user"],
    )
    conn = await asyncpg.connect(**cfg)

    counters = {"insert": 0, "skip": 0, "error": 0, "no_plan_map": 0}

    try:
        # Single-transaction guard: dry-run rolls everything back, real
        # run commits at the end. Using an explicit txn instead of
        # autocommit means a partial failure leaves the DB untouched.
        tx = conn.transaction()
        await tx.start()

        try:
            rows = await _fetch_active_subscriptions(conn)
            log.info("Found %d active subscriptions to inspect", len(rows))

            for r in rows:
                user_id = str(r["user_id"])
                stripe_sub_id = r["stripe_subscription_id"]
                lookup_key = r["lookup_key"]
                stripe_customer_id = r["stripe_customer_id"]

                plan_id = _lookup_key_to_plan_id(lookup_key)
                if plan_id is None:
                    log.warning(
                        "no_plan_map  user_id=%s  stripe_sub=%s  "
                        "lookup_key=%s -- skipping (mapping required)",
                        user_id,
                        stripe_sub_id,
                        lookup_key,
                    )
                    counters["no_plan_map"] += 1
                    continue

                already = await _has_matching_user_sub(
                    conn, user_id, stripe_sub_id
                )
                if already:
                    log.info(
                        "skip        user_id=%s  stripe_sub=%s  "
                        "(already mirrored)",
                        user_id,
                        stripe_sub_id,
                    )
                    counters["skip"] += 1
                    continue

                cancelled = await _cancel_prior_active(conn, user_id)
                await _insert_user_sub(
                    conn,
                    user_id=user_id,
                    plan_id=plan_id,
                    stripe_subscription_id=stripe_sub_id,
                    stripe_customer_id=stripe_customer_id,
                    period_start=r["current_period_start"],
                    period_end=r["current_period_end"],
                )
                log.info(
                    "insert      user_id=%s  stripe_sub=%s  "
                    "plan_id=%s  cancelled_prior=%d",
                    user_id,
                    stripe_sub_id,
                    plan_id,
                    cancelled,
                )
                counters["insert"] += 1
        except Exception:
            await tx.rollback()
            raise

        if dry_run:
            await tx.rollback()
            log.info("DRY RUN -- transaction rolled back, no changes committed")
        else:
            await tx.commit()
            log.info("COMMIT -- backfill applied")

    finally:
        await conn.close()

    log.info(
        "Summary: insert=%d  skip=%d  no_plan_map=%d  error=%d",
        counters["insert"],
        counters["skip"],
        counters["no_plan_map"],
        counters["error"],
    )
    return 0 if counters["error"] == 0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Backfill user_subscriptions rows for Stripe customers "
            "who paid before the Bug #1 fix landed."
        )
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Show the INSERTs / UPDATEs that would be issued, then "
            "roll back the transaction. Use this first."
        ),
    )
    args = parser.parse_args(argv)
    return asyncio.run(run(dry_run=args.dry_run))


if __name__ == "__main__":
    sys.exit(main())
