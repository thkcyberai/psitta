"""
Cancel the active dev_override (user_subscriptions) row for luisaao@gmail.com
so the existing tester_allowlist creative_nook_pro grant wins instead.

Background (see CLAUDE.md KL 2026-06-11):
  luisaao@gmail.com has:
    - user_subscriptions: plan_id=pro_monthly, status=active  ← shadows everything
    - tester_allowlist:   plan_id=creative_nook_pro, active until 2027-06-10
  The dev_override layer (tier 2) outranks tester_allowlist (tier 3), so the
  account resolves as reading_nook_pro instead of creative_nook_pro.
  Cancelling the active user_subscriptions row lets tier 3 win.

Safety:
  1. Pre-flight: SELECT COUNT(*) of the target rows — aborts if != 1.
  2. UPDATE sets status='cancelled', cancelled_at=NOW().
  3. Post-flight: re-runs get_effective_plan and asserts plan == 'creative_nook_pro'
     and source == 'tester_allowlist'.
  4. Writes an audit_log entry.
  5. Aborts (raises RuntimeError, rolls back) if any assertion fails.

Reversibility:
  UPDATE user_subscriptions SET status='active', cancelled_at=NULL
  WHERE user_id = <luisaao_user_id> AND plan_id = 'pro_monthly'
    AND linked_stripe_subscription_id = 'sub_1TPPfXRIUojeXsTBHSQc7Pab';

Run (production):
    aws ecs run-task --cluster psitta-cluster \\
        --task-definition psitta-api --launch-type FARGATE \\
        --network-configuration '{"awsvpcConfiguration":{"subnets":[
            "subnet-0a143e23d5e240aa9","subnet-0653bdf3529d8bbe8"],
            "securityGroups":["sg-002cf129761af804f"],
            "assignPublicIp":"DISABLED"}}' \\
        --overrides '{"containerOverrides":[{"name":"psitta-api",
            "command":["python","scripts/revoke_dev_override_luisaao.py"]}]}' \\
        --profile psitta-prod
"""

from __future__ import annotations

import asyncio
import logging
import sys
import uuid

from sqlalchemy import text

from psitta.db.session import async_session_factory
from psitta.services import audit_service
from psitta.services.subscription_service import get_effective_plan

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("revoke-dev-override")

TARGET_EMAIL = "luisaao@gmail.com"
EXPECTED_PLAN_AFTER = "creative_nook_pro"
EXPECTED_SOURCE_AFTER = "tester_allowlist"


async def main() -> None:
    async with async_session_factory() as db:
        # ── Step 1: resolve user_id ─────────────────────────────────────────
        row = await db.execute(
            text("SELECT id, email FROM users WHERE email = :email"),
            {"email": TARGET_EMAIL},
        )
        user_row = row.one_or_none()
        if user_row is None:
            raise RuntimeError(f"No user found with email {TARGET_EMAIL!r}")
        user_id: uuid.UUID = user_row.id
        log.info("Resolved user_id=%s for %s", user_id, TARGET_EMAIL)

        # ── Step 2: pre-flight count ────────────────────────────────────────
        count_row = await db.execute(
            text(
                "SELECT COUNT(*) FROM user_subscriptions "
                "WHERE user_id = :uid AND status = 'active'"
            ),
            {"uid": user_id},
        )
        active_count: int = count_row.scalar_one()
        log.info("Pre-flight: %d active user_subscriptions row(s) for this user", active_count)

        if active_count == 0:
            log.warning("No active dev_override row found — nothing to cancel. Exiting.")
            return
        if active_count != 1:
            raise RuntimeError(
                f"SAFETY ABORT: expected exactly 1 active row, found {active_count}. "
                "Inspect manually before running."
            )

        # Show the exact UPDATE that will run
        log.info(
            "EXACT UPDATE: UPDATE user_subscriptions SET status='cancelled', "
            "cancelled_at=NOW() WHERE user_id='%s' AND status='active'  "
            "[targets exactly 1 row — verified above]",
            user_id,
        )

        # ── Step 3: apply the UPDATE ────────────────────────────────────────
        result = await db.execute(
            text(
                "UPDATE user_subscriptions "
                "SET status = 'cancelled', cancelled_at = NOW() "
                "WHERE user_id = :uid AND status = 'active'"
            ),
            {"uid": user_id},
        )
        rows_affected: int = result.rowcount
        log.info("UPDATE rowcount = %d", rows_affected)

        if rows_affected != 1:
            raise RuntimeError(
                f"SAFETY ABORT: UPDATE affected {rows_affected} rows (expected 1). "
                "Rolling back."
            )

        # ── Step 4: post-flight — verify resolver ───────────────────────────
        plan_info = await get_effective_plan(db, user_id)
        plan_id: str = plan_info.plan_id
        source: str = plan_info.source
        log.info("Post-update get_effective_plan → plan_id=%r  source=%r", plan_id, source)

        if plan_id != EXPECTED_PLAN_AFTER:
            raise RuntimeError(
                f"SAFETY ABORT: expected plan {EXPECTED_PLAN_AFTER!r}, got {plan_id!r}. "
                "Rolling back."
            )
        if source != EXPECTED_SOURCE_AFTER:
            raise RuntimeError(
                f"SAFETY ABORT: expected source {EXPECTED_SOURCE_AFTER!r}, got {source!r}. "
                "Rolling back."
            )

        # ── Step 5: audit log ───────────────────────────────────────────────
        await audit_service.log_event(
            db,
            action="admin.revoke_dev_override",
            resource_type="user_subscription",
            user_id=str(user_id),
            resource_id=str(user_id),
            details={
                "reason": "cancel dev_override so tester_allowlist creative_nook_pro wins",
                "script": "revoke_dev_override_luisaao.py",
                "from_plan": "pro_monthly",
                "to_effective_plan": "creative_nook_pro",
                "source": "tester_allowlist",
            },
        )

        await db.commit()
        log.info(
            "SUCCESS. rows_affected=%d  new_plan=%r  new_source=%r  audit_log=written",
            rows_affected,
            plan_id,
            source,
        )
        log.info(
            "REVERSIBILITY: UPDATE user_subscriptions SET status='active', cancelled_at=NULL "
            "WHERE user_id='%s' AND plan_id='pro_monthly' "
            "AND linked_stripe_subscription_id='sub_1TPPfXRIUojeXsTBHSQc7Pab';",
            user_id,
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except RuntimeError as exc:
        log.error("ABORTED: %s", exc)
        sys.exit(1)
