"""
Deeper read-only diagnostic for the §4 button-gating decision (sibling
of diagnose_subscription_sources.py).

Five sections, Postgres-only, no Stripe API calls, no writes:

  1. Full subscriptions ⋈ stripe_customers rows for the 4 target emails
     (every row, not just active — surfaces cancelled / past_due / etc).
  2. user_subscriptions rows (the dev_override fallback layer).
  3. tester_allowlist rows (the Item 11 fallback layer).
  4. Fallthrough simulation: for each user, prints
       current=stripe(plan) → if stripe inactive → <fallthrough>
     so the load-bearing question is answered at paste-time without
     manual reasoning.
  5. Sandbox/live cutover reminder: rows created before 2026-05-19 UTC
     are pre-live-cutover (KL 2026-05-22a — sandbox stripe_customers
     rows survive the live cutover). Definitive sub_/cus_ ID check is
     deferred to the Stripe live dashboard; not done here to keep this
     diagnostic decoupled from live billing state.

Safe to run any number of times. No INSERT/UPDATE/DELETE.

Run (production):
    aws ecs run-task --cluster psitta-cluster \\
        --task-definition psitta-api --launch-type FARGATE \\
        --network-configuration '...' \\
        --overrides '{"containerOverrides":[{"name":"psitta-api", \\
            "command":["python","scripts/diagnose_subscription_details.py"]}]}'
"""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime

from sqlalchemy import text

from psitta.db.session import async_session_factory

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("diagnose-details")

EMAILS: list[str] = [
    "test1@facti.ai",
    "test2@facti.ai",
    "test3@facti.ai",
    "luisaao@gmail.com",
]

CUTOVER_UTC = datetime(2026, 5, 19, tzinfo=UTC)


def _fmt_ts(ts) -> str:
    if ts is None:
        return "-"
    if isinstance(ts, datetime):
        return ts.astimezone(UTC).strftime("%Y-%m-%d %H:%M:%SZ")
    return str(ts)


def _cutover_flag(ts) -> str:
    """Return 'pre-cutover' / 'post-cutover' / '-' for a timestamp."""
    if ts is None:
        return "-"
    if isinstance(ts, datetime):
        ts_utc = ts.astimezone(UTC) if ts.tzinfo else ts.replace(tzinfo=UTC)
        return "pre-cutover " if ts_utc < CUTOVER_UTC else "post-cutover"
    return "-"


async def _section_1_subscriptions(db) -> None:
    print()  # noqa: T201
    print("=" * 130)  # noqa: T201
    print("SECTION 1 — All subscriptions ⋈ stripe_customers rows "  # noqa: T201
          "(every status, not just active)")
    print("=" * 130)  # noqa: T201
    rows = (
        await db.execute(
            text(
                """
                SELECT u.email,
                       u.id                       AS user_id,
                       sc.id                      AS stripe_customers_pk,
                       sc.stripe_customer_id      AS cus_id,
                       sc.created_at              AS cust_created_at,
                       s.id                       AS subscription_pk,
                       s.stripe_subscription_id   AS sub_id,
                       s.status                   AS status,
                       s.lookup_key               AS lookup_key,
                       s.current_period_start     AS period_start,
                       s.current_period_end       AS period_end,
                       s.cancel_at_period_end     AS cape,
                       s.created_at               AS sub_created_at
                FROM users u
                LEFT JOIN stripe_customers sc ON sc.user_id = u.id
                LEFT JOIN subscriptions    s  ON s.stripe_customer_id = sc.id
                WHERE u.email = ANY(:emails)
                ORDER BY u.email, s.created_at DESC NULLS LAST
                """
            ),
            {"emails": EMAILS},
        )
    ).mappings().all()

    if not rows:
        print("  (no rows — none of the 4 emails exist in users)")  # noqa: T201
        return

    print(  # noqa: T201
        f"  {'email':28}  {'cus_id':22}  {'sub_id':30}  "
        f"{'status':10}  {'lookup_key':28}  {'sub_created_at':22}  "
        f"{'cutover':13}  {'cape':5}"
    )
    print("  " + "-" * 168)  # noqa: T201
    for r in rows:
        print(  # noqa: T201
            f"  {r['email']:28}  "
            f"{(r['cus_id'] or '-'):22}  "
            f"{(r['sub_id'] or '-'):30}  "
            f"{(r['status'] or '-'):10}  "
            f"{(r['lookup_key'] or '-'):28}  "
            f"{_fmt_ts(r['sub_created_at']):22}  "
            f"{_cutover_flag(r['sub_created_at']):13}  "
            f"{('Y' if r['cape'] else 'N' if r['cape'] is False else '-'):5}"
        )


async def _section_2_user_subscriptions(db) -> None:
    print()  # noqa: T201
    print("=" * 130)  # noqa: T201
    print("SECTION 2 — user_subscriptions rows "  # noqa: T201
          "(dev_override fallback layer)")
    print("=" * 130)  # noqa: T201
    rows = (
        await db.execute(
            text(
                """
                SELECT u.email,
                       us.id                       AS us_pk,
                       us.plan_id                  AS plan_id,
                       us.status                   AS status,
                       us.stripe_subscription_id   AS linked_sub_id,
                       us.current_period_start     AS period_start,
                       us.current_period_end       AS period_end,
                       us.created_at               AS created_at,
                       us.cancelled_at             AS cancelled_at
                FROM users u
                LEFT JOIN user_subscriptions us ON us.user_id = u.id
                WHERE u.email = ANY(:emails)
                ORDER BY u.email, us.created_at DESC NULLS LAST
                """
            ),
            {"emails": EMAILS},
        )
    ).mappings().all()

    if not rows or all(r["us_pk"] is None for r in rows):
        print("  (no user_subscriptions rows for any of the 4 emails)")  # noqa: T201
        return

    print(  # noqa: T201
        f"  {'email':28}  {'plan_id':22}  {'status':10}  "
        f"{'linked_sub_id':30}  {'created_at':22}  {'cancelled_at':22}"
    )
    print("  " + "-" * 140)  # noqa: T201
    for r in rows:
        if r["us_pk"] is None:
            continue
        print(  # noqa: T201
            f"  {r['email']:28}  "
            f"{(r['plan_id'] or '-'):22}  "
            f"{(r['status'] or '-'):10}  "
            f"{(r['linked_sub_id'] or '-'):30}  "
            f"{_fmt_ts(r['created_at']):22}  "
            f"{_fmt_ts(r['cancelled_at']):22}"
        )


async def _section_3_allowlist(db) -> None:
    print()  # noqa: T201
    print("=" * 130)  # noqa: T201
    print("SECTION 3 — tester_allowlist rows "  # noqa: T201
          "(Item 11 fallback layer)")
    print("=" * 130)  # noqa: T201
    rows = (
        await db.execute(
            text(
                """
                SELECT email, plan_id, granted_at, expires_at, revoked_at,
                       (revoked_at IS NULL AND expires_at > NOW())
                            AS is_active
                FROM tester_allowlist
                WHERE email = ANY(:emails)
                ORDER BY email, granted_at DESC
                """
            ),
            {"emails": EMAILS},
        )
    ).mappings().all()

    if not rows:
        print("  (no tester_allowlist rows for any of the 4 emails)")  # noqa: T201
        return

    print(  # noqa: T201
        f"  {'email':28}  {'plan_id':22}  {'is_active':10}  "
        f"{'granted_at':22}  {'expires_at':22}  {'revoked_at':22}"
    )
    print("  " + "-" * 130)  # noqa: T201
    for r in rows:
        print(  # noqa: T201
            f"  {r['email']:28}  "
            f"{(r['plan_id'] or '-'):22}  "
            f"{('YES' if r['is_active'] else 'no'):10}  "
            f"{_fmt_ts(r['granted_at']):22}  "
            f"{_fmt_ts(r['expires_at']):22}  "
            f"{_fmt_ts(r['revoked_at']):22}"
        )


async def _section_4_fallthrough(db) -> None:
    """For each user, simulate the resolver with the stripe layer disabled.

    Mirrors get_effective_plan's precedence exactly:
      stripe  →  user_subscriptions (active)  →  tester_allowlist (active)
              →  free.
    Skipping the stripe step answers: "if we cleaned the stale stripe row,
    what would the resolver return?"
    """
    print()  # noqa: T201
    print("=" * 130)  # noqa: T201
    print("SECTION 4 — Fallthrough simulation "  # noqa: T201
          "(resolver precedence with the stripe layer hypothetically disabled)")
    print("=" * 130)  # noqa: T201

    for email in EMAILS:
        # Look up user_id + current stripe-active row
        urow = (
            await db.execute(
                text(
                    """
                    SELECT u.id AS user_id,
                           s.lookup_key AS current_stripe_lookup
                    FROM users u
                    LEFT JOIN stripe_customers sc ON sc.user_id = u.id
                    LEFT JOIN subscriptions    s  ON s.stripe_customer_id = sc.id
                                                  AND s.status = 'active'
                    WHERE u.email = :email
                    ORDER BY s.created_at DESC NULLS LAST
                    LIMIT 1
                    """
                ),
                {"email": email},
            )
        ).mappings().first()

        if not urow:
            print(f"  {email:28}  (no users row)")  # noqa: T201
            continue

        user_id = urow["user_id"]
        current_stripe = urow["current_stripe_lookup"]

        # Layer 2: user_subscriptions active
        dev = (
            await db.execute(
                text(
                    """
                    SELECT plan_id FROM user_subscriptions
                    WHERE user_id = :uid AND status = 'active'
                    ORDER BY created_at DESC LIMIT 1
                    """
                ),
                {"uid": str(user_id)},
            )
        ).mappings().first()

        # Layer 3: tester_allowlist active
        tl = (
            await db.execute(
                text(
                    """
                    SELECT plan_id FROM tester_allowlist
                    WHERE email = :email
                      AND revoked_at IS NULL
                      AND expires_at > NOW()
                    ORDER BY granted_at DESC LIMIT 1
                    """
                ),
                {"email": email},
            )
        ).mappings().first()

        if dev:
            fallthrough = f"dev_override({dev['plan_id']})"
            verdict = "SAFE TO CLEAN (dev_override catches)"
        elif tl:
            fallthrough = f"tester_allowlist({tl['plan_id']})"
            verdict = "SAFE TO CLEAN (allowlist catches)"
        else:
            fallthrough = "free"
            verdict = "LOAD-BEARING — do NOT clean without grant first"

        current = (
            f"stripe({current_stripe})" if current_stripe else "none/free"
        )
        print(  # noqa: T201
            f"  {email:28}  "
            f"current={current:38}  "
            f"→ if stripe inactive → {fallthrough:35}  "
            f"[{verdict}]"
        )


def _section_5_reminder() -> None:
    print()  # noqa: T201
    print("=" * 130)  # noqa: T201
    print("SECTION 5 — Sandbox/live cutover reminder")  # noqa: T201
    print("=" * 130)  # noqa: T201
    print(  # noqa: T201
        "  Rows with sub_created_at <  2026-05-19 UTC are PRE-cutover "
        "(suspected sandbox sub_/cus_ IDs;"
    )
    print(  # noqa: T201
        "    will 502 on any live Stripe API call — KL 2026-05-22a)."
    )
    print(  # noqa: T201
        "  Rows with sub_created_at >= 2026-05-19 UTC are POST-cutover "
        "(suspected live)."
    )
    print()  # noqa: T201
    print(  # noqa: T201
        "  Definitive verification of any specific sub_/cus_ ID: paste "
        "into the live Stripe dashboard."
    )
    print(  # noqa: T201
        "  Not done here to keep this diagnostic decoupled from live "
        "billing-state side effects."
    )


async def _run() -> None:
    async with async_session_factory() as db:
        await _section_1_subscriptions(db)
        await _section_2_user_subscriptions(db)
        await _section_3_allowlist(db)
        await _section_4_fallthrough(db)
        _section_5_reminder()
        print()  # noqa: T201


if __name__ == "__main__":
    asyncio.run(_run())
