"""
One-time cleanup of pre-cutover (sandbox) Stripe subscriptions rows
that shadow live entitlement via the resolver's stripe-precedence layer
(KL 2026-05-22a, KL 2026-05-22b).

After this script runs, each of the 4 affected accounts resolves via
the dev_override layer (user_subscriptions) instead of the stale stripe
row, and the "Manage Subscription" portal call stops 502'ing on
"No such customer" because the resolver no longer hands the gate a
dead sandbox sub_/cus_ ID.

Targets (hard-coded from Section 1 of diagnose_subscription_details.py,
N=4, all pre-cutover):

  luisaao@gmail.com  sub_1TPPfXRIUojeXsTBHSQc7Pab  reading_nook_pro_monthly  2026-04-23
  test1@facti.ai     sub_1TQpoeRIUojeXsTBD4jgakBs  reading_nook_pro_monthly  2026-04-27
  test2@facti.ai     sub_1TPbLFRIUojeXsTB5j0YPSBy  reading_nook_pro_monthly  2026-04-24
  test3@facti.ai     sub_1TSLODRIUojeXsTBZ4bcaviy  reading_nook_pro_annual   2026-05-01

The 3 already-canceled extras (test1 x2, test3 x1) are NOT in this set
and are left untouched.

Run modes:
  --dry-run    Open a transaction, run all pre-flight assertions, run
               the UPDATE, run all post-flight assertions, log every
               step in detail, then ROLLBACK. Exits 0 if everything
               would have succeeded, exits 1 on any assertion failure.

  no flag      Same as --dry-run but COMMITs at the end instead of
               rolling back. Idempotent: a second live run finds 0
               TARGET rows in pre-flight #1, asserts EXPECTED_N=0,
               exits 0 with "no-op" status.

Safety net (KL 2026-04-24 surgical-write pattern):

  Pre-flight (3 assertions, rollback on failure):
    P1. SELECT COUNT WHERE stripe_subscription_id IN (4 ids)
                       AND status = 'active'   ==  EXPECTED_N (4 or 0)
    P2. Every matched row has created_at < 2026-05-19 UTC (cutover guard)
    P3. Every matched user has an active user_subscriptions row whose
        plan_id matches their EXPECTED_DEV_PLAN_ID

  UPDATE with rowcount guard:
    UPDATE subscriptions SET status='canceled', updated_at=NOW()
    WHERE stripe_subscription_id IN (...) AND status = 'active'
    --> rowcount must equal pre-flight match count

  Post-flight (4 assertions, rollback on failure):
    F1. Re-SELECT TARGET predicate returns 0 rows
    F2. For each of 4 users: get_effective_plan(...).source == 'dev_override'
    F3. COUNT subscriptions WHERE updated_at >= start_ts == match count
    F4. COUNT audit_log WHERE created_at >= start_ts == match count

  One audit_log row per cancelled subscription via audit_service.log_event:
    action       = 'subscription.stale_sandbox_canceled'
    resource_type= 'subscription'
    resource_id  = subscriptions.id (UUID, per KL 2026-04-17)
    details      = {sub_id, cus_id, user_email, prior_status, new_status,
                    reason, cutover_date}

  Single transaction wraps everything; any RuntimeError rolls back.

Run (production):
    # Dry-run first (recommended):
    aws ecs run-task --cluster psitta-cluster \\
        --task-definition psitta-api --launch-type FARGATE \\
        --network-configuration '...' \\
        --overrides '{"containerOverrides":[{"name":"psitta-api", \\
            "command":["python","scripts/cleanup_stale_sandbox_subscriptions.py",
                       "--dry-run"]}]}'

    # Live (only after dry-run review):
    aws ecs run-task ... --overrides '...command:[python,
                          scripts/cleanup_stale_sandbox_subscriptions.py]...'
"""

from __future__ import annotations

import argparse
import asyncio
import logging
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import text

from psitta.db.session import async_session_factory
from psitta.services.audit_service import log_event
from psitta.services.subscription_service import get_effective_plan

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("cleanup-stale-sub")


# ─── TARGETS ────────────────────────────────────────────────────────────
# 4 active rows to cancel, from Section 1 of diagnose_subscription_details.
# All pre-cutover (sub_created_at < 2026-05-19 UTC) per the diagnostic.
TARGETS: list[dict[str, str]] = [
    {
        "email": "luisaao@gmail.com",
        "sub_id": "sub_1TPPfXRIUojeXsTBHSQc7Pab",
        "cus_id": "cus_UM2ueQs7WTvA3L",
        "lookup_key": "reading_nook_pro_monthly",
        "expected_dev_plan_id": "pro_monthly",
    },
    {
        "email": "test1@facti.ai",
        "sub_id": "sub_1TQpoeRIUojeXsTBD4jgakBs",
        "cus_id": "cus_UM5AEZs7blIjXJ",
        "lookup_key": "reading_nook_pro_monthly",
        "expected_dev_plan_id": "pro_monthly",
    },
    {
        "email": "test2@facti.ai",
        "sub_id": "sub_1TPbLFRIUojeXsTB5j0YPSBy",
        "cus_id": "cus_UMPiEOsg10x61W",
        "lookup_key": "reading_nook_pro_monthly",
        "expected_dev_plan_id": "pro_monthly",
    },
    {
        "email": "test3@facti.ai",
        "sub_id": "sub_1TSLODRIUojeXsTBZ4bcaviy",
        "cus_id": "cus_URDoEty7dKKdxC",
        "lookup_key": "reading_nook_pro_annual",
        "expected_dev_plan_id": "pro_annual",
    },
]
EXPECTED_N_FIRST_RUN = 4  # 0 on idempotent re-run
CUTOVER_UTC = datetime(2026, 5, 19, tzinfo=UTC)
SUB_IDS = [t["sub_id"] for t in TARGETS]


class AssertionFailureError(RuntimeError):
    """Raised when any pre- or post-flight assertion fails; rolls back."""


async def _preflight_p1(db) -> tuple[int, list[dict]]:
    """P1: SELECT matching rows; return (count, rows-with-pk-and-user)."""
    rows = (
        await db.execute(
            text(
                """
                SELECT s.id              AS sub_pk,
                       s.stripe_subscription_id AS sub_id,
                       s.status,
                       s.created_at,
                       sc.user_id        AS user_id,
                       u.email           AS email
                FROM subscriptions s
                JOIN stripe_customers sc ON sc.id = s.stripe_customer_id
                JOIN users u ON u.id = sc.user_id
                WHERE s.stripe_subscription_id = ANY(:sub_ids)
                  AND s.status = 'active'
                ORDER BY u.email
                """
            ),
            {"sub_ids": SUB_IDS},
        )
    ).mappings().all()
    matches = [dict(r) for r in rows]
    n = len(matches)
    log.info("P1: %d active row(s) match target sub_ids "
             "(EXPECTED_N_FIRST_RUN=%d, or 0 if idempotent re-run)",
             n, EXPECTED_N_FIRST_RUN)
    if n not in (0, EXPECTED_N_FIRST_RUN):
        raise AssertionFailureError(
            f"P1 failed: expected 0 or {EXPECTED_N_FIRST_RUN} rows, "
            f"found {n}. Aborting."
        )
    return n, matches


def _preflight_p2(matches: list[dict]) -> None:
    """P2: every matched row created_at < cutover (sandbox safety net)."""
    for m in matches:
        created_at = m["created_at"]
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=UTC)
        if created_at >= CUTOVER_UTC:
            raise AssertionFailureError(
                f"P2 failed: sub_id={m['sub_id']} created_at={created_at} "
                f">= cutover {CUTOVER_UTC}. Post-cutover rows are likely "
                f"LIVE Stripe subscriptions and must not be touched by "
                f"this script. Aborting."
            )
    log.info("P2: all %d matched rows are pre-cutover "
             "(created_at < %s)", len(matches), CUTOVER_UTC.isoformat())


async def _preflight_p3(db, matches: list[dict]) -> None:
    """P3: every matched user has an active user_subscriptions row whose
    plan_id matches their target's expected_dev_plan_id."""
    expected_by_email = {t["email"]: t["expected_dev_plan_id"]
                         for t in TARGETS}
    for m in matches:
        email = m["email"]
        expected = expected_by_email.get(email)
        if expected is None:
            raise AssertionFailureError(
                f"P3 failed: matched row for {email} but that email is "
                f"not in TARGETS. Aborting."
            )
        row = (
            await db.execute(
                text(
                    """
                    SELECT plan_id, status
                    FROM user_subscriptions
                    WHERE user_id = :uid AND status = 'active'
                    ORDER BY created_at DESC LIMIT 1
                    """
                ),
                {"uid": str(m["user_id"])},
            )
        ).mappings().first()
        if row is None:
            raise AssertionFailureError(
                f"P3 failed: {email} has no active user_subscriptions row "
                f"-- cancelling the stripe row would downgrade them to "
                f"Free. Aborting."
            )
        if row["plan_id"] != expected:
            raise AssertionFailureError(
                f"P3 failed: {email} dev_override plan_id is "
                f"{row['plan_id']!r}, expected {expected!r}. Aborting."
            )
    log.info("P3: all %d users have an active dev_override row "
             "matching expected plan_id", len(matches))


async def _apply_update(db, n_expected: int) -> int:
    """Run the UPDATE and assert rowcount == expected."""
    result = await db.execute(
        text(
            """
            UPDATE subscriptions
            SET status = 'canceled', updated_at = NOW()
            WHERE stripe_subscription_id = ANY(:sub_ids)
              AND status = 'active'
            """
        ),
        {"sub_ids": SUB_IDS},
    )
    n_updated = result.rowcount
    log.info("UPDATE: rowcount=%d (expected=%d)", n_updated, n_expected)
    if n_updated != n_expected:
        raise AssertionFailureError(
            f"UPDATE rowcount {n_updated} != expected {n_expected}. "
            f"Aborting."
        )
    return n_updated


async def _write_audit_rows(db, matches: list[dict]) -> None:
    """One audit_log row per cancelled subscription."""
    for m in matches:
        target = next(t for t in TARGETS if t["sub_id"] == m["sub_id"])
        await log_event(
            db,
            action="subscription.stale_sandbox_canceled",
            resource_type="subscription",
            user_id=str(m["user_id"]),
            resource_id=str(m["sub_pk"]),
            details={
                "stripe_subscription_id": m["sub_id"],
                "stripe_customer_id": target["cus_id"],
                "user_email": m["email"],
                "prior_status": "active",
                "new_status": "canceled",
                "lookup_key": target["lookup_key"],
                "reason": (
                    "pre-cutover sandbox subscription, dead in live "
                    "Stripe per KL 2026-05-22a; resolver was shadowing "
                    "dev_override entitlement and causing Customer "
                    "Portal 502 (KL 2026-05-22b)"
                ),
                "cutover_date": "2026-05-19",
                "script": "cleanup_stale_sandbox_subscriptions.py",
            },
        )
    log.info("AUDIT: wrote %d audit_log rows", len(matches))


async def _postflight_f1(db) -> None:
    """F1: re-SELECT TARGET returns 0 active rows."""
    rows = (
        await db.execute(
            text(
                """
                SELECT COUNT(*) AS n
                FROM subscriptions
                WHERE stripe_subscription_id = ANY(:sub_ids)
                  AND status = 'active'
                """
            ),
            {"sub_ids": SUB_IDS},
        )
    ).scalar_one()
    log.info("F1: re-SELECT TARGET active count=%d (expected=0)", rows)
    if rows != 0:
        raise AssertionFailureError(
            f"F1 failed: {rows} rows still match TARGET after UPDATE. "
            f"Aborting."
        )


async def _postflight_f2(db, matches: list[dict]) -> None:
    """F2: for each affected user, resolver now returns dev_override."""
    for m in matches:
        plan = await get_effective_plan(db, UUID(str(m["user_id"])),
                                        m["email"])
        if plan.source != "dev_override":
            raise AssertionFailureError(
                f"F2 failed: {m['email']} resolver source is "
                f"{plan.source!r} after UPDATE, expected 'dev_override'. "
                f"Aborting."
            )
    log.info("F2: all %d users resolve to source='dev_override' "
             "post-update", len(matches))


async def _postflight_f3(db, start_ts: datetime, n_expected: int) -> None:
    """F3: no collateral subscriptions.updated_at changes."""
    n = (
        await db.execute(
            text(
                "SELECT COUNT(*) FROM subscriptions "
                "WHERE updated_at >= :ts"
            ),
            {"ts": start_ts},
        )
    ).scalar_one()
    log.info("F3: subscriptions touched since start_ts=%d "
             "(expected=%d)", n, n_expected)
    if n != n_expected:
        raise AssertionFailureError(
            f"F3 failed: {n} subscriptions rows touched since "
            f"start, expected {n_expected}. Collateral change "
            f"detected. Aborting."
        )


async def _postflight_f4(db, start_ts: datetime, n_expected: int) -> None:
    """F4: exactly n_expected audit_log rows written by this script."""
    n = (
        await db.execute(
            text(
                "SELECT COUNT(*) FROM audit_log "
                "WHERE created_at >= :ts "
                "AND action = 'subscription.stale_sandbox_canceled'"
            ),
            {"ts": start_ts},
        )
    ).scalar_one()
    log.info("F4: audit_log rows for this action since start_ts=%d "
             "(expected=%d)", n, n_expected)
    if n != n_expected:
        raise AssertionFailureError(
            f"F4 failed: {n} audit_log rows since start, expected "
            f"{n_expected}. Aborting."
        )


async def _run(dry_run: bool) -> int:
    mode = "DRY-RUN" if dry_run else "LIVE"
    log.info("=" * 70)
    log.info("cleanup_stale_sandbox_subscriptions.py  mode=%s", mode)
    log.info("=" * 70)
    log.info("Target sub_ids (%d):", len(SUB_IDS))
    for t in TARGETS:
        log.info("  %s  %s  (cus=%s, plan=%s, dev=%s)",
                 t["email"], t["sub_id"], t["cus_id"],
                 t["lookup_key"], t["expected_dev_plan_id"])

    start_ts = datetime.now(tz=UTC)

    async with async_session_factory() as db:
        try:
            # ─── PRE-FLIGHT ─────────────────────────────────────────
            n, matches = await _preflight_p1(db)
            if n == 0:
                log.info("Idempotent no-op: 0 TARGET rows match (already "
                         "cleaned). Nothing to do.")
                await db.rollback()
                return 0
            _preflight_p2(matches)
            await _preflight_p3(db, matches)

            # ─── UPDATE + AUDIT ─────────────────────────────────────
            n_updated = await _apply_update(db, n_expected=n)
            await _write_audit_rows(db, matches)

            # ─── POST-FLIGHT ────────────────────────────────────────
            await _postflight_f1(db)
            await _postflight_f2(db, matches)
            await _postflight_f3(db, start_ts, n_expected=n_updated)
            await _postflight_f4(db, start_ts, n_expected=n_updated)

            # ─── COMMIT OR ROLLBACK ─────────────────────────────────
            if dry_run:
                await db.rollback()
                log.info("DRY-RUN complete: transaction rolled back, "
                         "no changes persisted")
            else:
                await db.commit()
                log.info("LIVE complete: transaction committed, "
                         "%d row(s) canceled, %d audit row(s) written",
                         n_updated, n_updated)
            return 0

        except AssertionFailureError as e:
            await db.rollback()
            log.error("ASSERTION FAILURE: %s", e)
            log.error("Transaction rolled back.")
            return 1
        except Exception:
            await db.rollback()
            log.exception("Unexpected error; transaction rolled back.")
            return 1


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=(
            "Cancel 4 pre-cutover sandbox Stripe subscriptions rows so "
            "the resolver falls through to the dev_override layer for "
            "test1/test2/test3@facti.ai and luisaao@gmail.com."
        ),
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Run all assertions and the UPDATE inside a transaction, "
            "then ROLLBACK. No changes persisted. Recommended for the "
            "first run."
        ),
    )
    return p.parse_args()


if __name__ == "__main__":
    args = _parse_args()
    raise SystemExit(asyncio.run(_run(dry_run=args.dry_run)))
