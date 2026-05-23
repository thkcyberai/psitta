"""
Read-only diagnostic for the §4 button-gating decision (KL 2026-05-22b).

For four hard-coded test/founder accounts, resolves the entitlement source
using the production ``get_effective_plan`` resolver and also prints the
raw Stripe binding from the §4 JOIN so a stale ``subscriptions`` row is
visible even when the resolver picks a higher-precedence path.

The script is intentionally read-only (no INSERT/UPDATE/DELETE, no
flags, no Flask app context, no Stripe API calls). Safe to run any
number of times from an ECS one-off task.

Run (production):
    aws ecs run-task --cluster psitta-cluster \\
        --task-definition psitta-api --launch-type FARGATE \\
        --network-configuration '...' \\
        --overrides '{"containerOverrides":[{"name":"psitta-api", \\
            "command":["python","scripts/diagnose_subscription_sources.py"]}]}'
"""

from __future__ import annotations

import asyncio
import logging
from uuid import UUID

from sqlalchemy import text

from psitta.db.session import async_session_factory
from psitta.services.subscription_service import get_effective_plan

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("diagnose")

EMAILS: list[str] = [
    "test1@facti.ai",
    "test2@facti.ai",
    "test3@facti.ai",
    "luisaao@gmail.com",
]


async def _run() -> None:
    async with async_session_factory() as db:
        # §4 query, exactly as specified — gives raw Stripe binding per
        # email regardless of which precedence layer the resolver lands on.
        raw_rows = (
            await db.execute(
                text(
                    """
                    SELECT u.email, u.id AS user_id,
                           s.status AS stripe_status,
                           s.lookup_key AS stripe_lookup_key,
                           s.stripe_subscription_id
                    FROM users u
                    LEFT JOIN stripe_customers sc ON sc.user_id = u.id
                    LEFT JOIN subscriptions s ON s.stripe_customer_id = sc.id
                    WHERE u.email = ANY(:emails)
                    ORDER BY u.email, s.created_at DESC NULLS LAST
                    """
                ),
                {"emails": EMAILS},
            )
        ).mappings().all()

        # Collapse multiple stripe rows per email — keep the first
        # (most-recent by created_at DESC) plus a count of others so
        # stale rows are still flagged.
        by_email: dict[str, dict] = {}
        extras: dict[str, int] = {}
        for r in raw_rows:
            e = r["email"]
            if e in by_email:
                extras[e] = extras.get(e, 0) + 1
            else:
                by_email[e] = dict(r)

        print()  # noqa: T201
        print(  # noqa: T201
            f"{'email':28}  {'source':17}  {'plan_id':22}  "
            f"{'stripe_status':14}  {'lookup_key':28}  extra_stripe_rows"
        )
        print("-" * 130)  # noqa: T201

        for email in EMAILS:
            row = by_email.get(email)
            if not row:
                print(  # noqa: T201
                    f"{email:28}  {'<no users row>':17}  {'-':22}  "
                    f"{'-':14}  {'-':28}  -"
                )
                continue

            user_id: UUID = row["user_id"]
            plan = await get_effective_plan(db, user_id, email)

            stripe_status = row["stripe_status"] or "-"
            stripe_lookup = row["stripe_lookup_key"] or "-"
            extra = extras.get(email, 0)

            print(  # noqa: T201
                f"{email:28}  {plan.source:17}  {plan.plan_id:22}  "
                f"{stripe_status:14}  {stripe_lookup:28}  "
                f"{extra if extra else '-'}"
            )

        print()  # noqa: T201
        print("Legend:")  # noqa: T201
        print(  # noqa: T201
            "  source        = resolved entitlement layer "
            "(stripe > dev_override > tester_allowlist > free)"
        )
        print(  # noqa: T201
            "  stripe_status = raw subscriptions.status for most-recent "
            "stripe_customers row (may differ from source)"
        )
        print(  # noqa: T201
            "  extra_stripe_rows = count of additional subscriptions rows "
            "for this email (stale-row indicator)"
        )


if __name__ == "__main__":
    asyncio.run(_run())
