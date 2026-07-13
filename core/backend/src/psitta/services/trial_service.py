"""services/trial_service.py — Reverse-trial entitlement (GTM Phase 1).

On genuine new-user signup, every writer is granted the full Writing
Nook for a fixed window (``REVERSE_TRIAL_DAYS``, default 14). The grant
is a single row in ``trial_grants`` keyed by user_id. Expiry is LAZY:
``get_effective_plan`` filters ``expires_at > NOW()`` at read time and
falls through to Free once it passes — no scheduler required. This
mirrors ``tester_allowlist`` exactly.

Two hard safety properties, because this touches the auth/provisioning
hot path:
  * ``grant_reverse_trial`` runs inside a SAVEPOINT and never raises —
    a failure (including a missing table before the migration runs)
    rolls back only the savepoint, leaving the outer user-provisioning
    transaction intact. New-user login can never be broken by this.
  * ``check_trial_entitlement`` swallows read errors and returns None,
    so the entitlement resolver degrades to "no trial" (→ allowlist →
    Free) if the table is absent, rather than 500-ing billing/quota
    reads. Once migration 031 is applied this path never errors.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Models ───────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class TrialGrant:
    """An active reverse-trial grant.

    ``expires_at`` is the entitlement sunset; the resolver surfaces it as
    ``current_period_end`` so the desktop UI can show "Writing Nook ·
    N days left" and the day-11 upgrade prompt (Phase 3).
    """

    user_id: UUID
    plan_id: str
    granted_at: datetime
    expires_at: datetime
    activated_at: datetime | None
    revoked_at: datetime | None


# ── Read API (called by subscription_service.get_effective_plan) ──────────


async def check_trial_entitlement(
    db: AsyncSession, user_id: UUID
) -> TrialGrant | None:
    """Return the active reverse-trial grant for ``user_id``, or None.

    Active = ``revoked_at IS NULL AND expires_at > NOW()``. Returns None
    for expired, revoked, or missing grants.

    Deploy-safe: any read error (most importantly ``trial_grants`` not
    existing before migration 031 is applied) is swallowed and returns
    None, so the resolver falls through to the next precedence rather
    than failing. Once the migration is applied this never triggers.
    """
    try:
        row = await db.execute(
            text(
                """
                SELECT user_id, plan_id, granted_at, expires_at,
                       activated_at, revoked_at
                FROM trial_grants
                WHERE user_id = :uid
                  AND revoked_at IS NULL
                  AND expires_at > NOW()
                """
            ),
            {"uid": str(user_id)},
        )
        result = row.mappings().first()
    except Exception as exc:  # fail-open to the next precedence step
        logger.warning(
            "trial.check_failed", user_id=str(user_id), error=str(exc)
        )
        return None

    if result is None:
        return None

    return TrialGrant(
        user_id=result["user_id"],
        plan_id=result["plan_id"],
        granted_at=result["granted_at"],
        expires_at=result["expires_at"],
        activated_at=result["activated_at"],
        revoked_at=result["revoked_at"],
    )


# ── Write API (called on new-user provisioning in dependencies.py) ────────


async def grant_reverse_trial(db: AsyncSession, user_id: UUID) -> bool:
    """Grant a reverse trial to a brand-new user. Best-effort, never raises.

    Called from the new-user branch of ``get_current_user_id``. Runs in a
    SAVEPOINT so a failure cannot poison the outer user-provisioning
    transaction (login must never break because of the trial). Does NOT
    commit — the request-scoped session commits at the end of the request.

    Idempotent via ``ON CONFLICT (user_id) DO NOTHING``: a writer cannot
    reset their trial by signing in again. Honours the
    ``REVERSE_TRIAL_ENABLED`` kill switch and ``REVERSE_TRIAL_DAYS`` /
    ``REVERSE_TRIAL_PLAN_ID`` config. Returns True if a grant row was
    written this call, False otherwise (disabled, conflict, or error).
    """
    settings = get_settings()
    if not settings.REVERSE_TRIAL_ENABLED:
        return False

    days = settings.REVERSE_TRIAL_DAYS
    if days <= 0:
        return False
    plan_id = settings.REVERSE_TRIAL_PLAN_ID
    expires_at = datetime.now(UTC) + timedelta(days=days)

    try:
        async with db.begin_nested():  # SAVEPOINT — isolates any failure
            result = await db.execute(
                text(
                    """
                    INSERT INTO trial_grants
                        (user_id, plan_id, granted_at, expires_at, source,
                         created_at, updated_at)
                    VALUES
                        (:uid, :plan_id, NOW(), :expires_at, 'signup',
                         NOW(), NOW())
                    ON CONFLICT (user_id) DO NOTHING
                    """
                ),
                {
                    "uid": str(user_id),
                    "plan_id": plan_id,
                    "expires_at": expires_at,
                },
            )
        granted = result.rowcount == 1
        if granted:
            logger.info(
                "trial.granted",
                user_id=str(user_id),
                plan_id=plan_id,
                expires_at=expires_at.isoformat(),
            )
        return granted
    except Exception as exc:  # must never break user provisioning
        logger.warning(
            "trial.grant_failed", user_id=str(user_id), error=str(exc)
        )
        return False
