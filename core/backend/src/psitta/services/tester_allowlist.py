"""services/tester_allowlist.py — Internal Alpha tester entitlement (Item 11).

Backend allowlist that grants Reading Nook Pro entitlement to opted-in
alpha testers without creating a Stripe customer or subscription.
Lookup is by lowercased email — no FK to users.email — so a tester can
be allowlisted before they sign up.

Email normalization is lowercase only. Per Apr 30 Key Learning, plus
suffix stripping is deferred (gmail-style alias collapsing creates
edge cases that aren't worth solving for the alpha cohort).

Module is dormant on T11.1 — no callers yet. T11.2 wires the resolver
into /billing/status + subscription_service. T11.3 adds the admin CLI
and desktop UI affordances.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Constants ────────────────────────────────────────────────────────────

DEFAULT_PLAN_ID = "reading_nook_pro"
DEFAULT_GRANT_DAYS = 30


# ── Models ───────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class AllowlistEntry:
    """An active tester allowlist entry.

    expires_at is the entitlement sunset; the resolver in T11.2 surfaces
    this as current_period_end so the desktop UI can show "Alpha tester
    · expires <date>".
    """

    email: str
    plan_id: str
    granted_at: datetime
    expires_at: datetime
    granted_by: str
    notes: str | None
    revoked_at: datetime | None


def _normalize_email(email: str) -> str:
    """Lowercase + strip whitespace. No plus-suffix stripping."""
    return email.strip().lower()


# ── Read API ─────────────────────────────────────────────────────────────


async def check_allowlist_entitlement(
    db: AsyncSession, email: str
) -> AllowlistEntry | None:
    """Return the active allowlist entry for ``email``, or None.

    Active = revoked_at IS NULL AND expires_at > NOW(). The lookup is
    case-insensitive (email lowercased before SELECT). Returns None for
    expired, revoked, or unknown emails.
    """
    if not email:
        return None
    normalized = _normalize_email(email)

    row = await db.execute(
        text(
            """
            SELECT email, plan_id, granted_at, expires_at, granted_by,
                   notes, revoked_at
            FROM tester_allowlist
            WHERE email = :email
              AND revoked_at IS NULL
              AND expires_at > NOW()
            """
        ),
        {"email": normalized},
    )
    result = row.mappings().first()
    if result is None:
        return None

    return AllowlistEntry(
        email=result["email"],
        plan_id=result["plan_id"],
        granted_at=result["granted_at"],
        expires_at=result["expires_at"],
        granted_by=result["granted_by"],
        notes=result["notes"],
        revoked_at=result["revoked_at"],
    )


# ── Write API (used by scripts/grant_tester.py in T11.3) ─────────────────


async def add_allowlist(  # noqa: PLR0913 -- 6 grant attributes (email, granted_by, days, plan_id, notes plus session) — collapsing to a TypedDict adds friction without clarifying intent at the call site
    db: AsyncSession,
    email: str,
    granted_by: str,
    days: int = DEFAULT_GRANT_DAYS,
    plan_id: str = DEFAULT_PLAN_ID,
    notes: str | None = None,
) -> AllowlistEntry:
    """Insert or extend an allowlist entry idempotently.

    On conflict (email already present), extends expires_at to
    NOW() + days, clears revoked_at, and refreshes granted_by + notes.
    Re-running the same grant repeatedly is a no-op apart from sliding
    expiry forward — the intended behaviour for alpha cohort top-ups.
    """
    if days <= 0:
        raise ValueError(f"days must be positive, got {days}")
    normalized = _normalize_email(email)
    expires_at = datetime.now(UTC) + timedelta(days=days)

    await db.execute(
        text(
            """
            INSERT INTO tester_allowlist
                (email, plan_id, granted_at, expires_at, granted_by,
                 notes, created_at, updated_at)
            VALUES
                (:email, :plan_id, NOW(), :expires_at, :granted_by,
                 :notes, NOW(), NOW())
            ON CONFLICT (email) DO UPDATE SET
                plan_id = EXCLUDED.plan_id,
                expires_at = EXCLUDED.expires_at,
                granted_by = EXCLUDED.granted_by,
                notes = EXCLUDED.notes,
                revoked_at = NULL,
                updated_at = NOW()
            """
        ),
        {
            "email": normalized,
            "plan_id": plan_id,
            "expires_at": expires_at,
            "granted_by": granted_by,
            "notes": notes,
        },
    )
    await db.commit()

    logger.info(
        "tester.allowlist_granted",
        email=normalized,
        plan_id=plan_id,
        expires_at=expires_at.isoformat(),
        granted_by=granted_by,
    )

    entry = await _fetch_entry(db, normalized)
    if entry is None:
        raise RuntimeError(
            f"add_allowlist: row for {normalized!r} missing after upsert"
        )
    return entry


async def revoke_allowlist(db: AsyncSession, email: str) -> bool:
    """Soft-revoke an allowlist entry. Returns True if a row was revoked.

    Idempotent: revoking an already-revoked or non-existent row returns
    False without raising. The row is preserved for audit; only
    revoked_at is set so check_allowlist_entitlement excludes it.
    """
    normalized = _normalize_email(email)
    result = await db.execute(
        text(
            """
            UPDATE tester_allowlist
            SET revoked_at = NOW(), updated_at = NOW()
            WHERE email = :email AND revoked_at IS NULL
            """
        ),
        {"email": normalized},
    )
    await db.commit()

    revoked = result.rowcount == 1
    if revoked:
        logger.info("tester.allowlist_revoked", email=normalized)
    return revoked


async def list_allowlist(
    db: AsyncSession, active_only: bool = True
) -> list[AllowlistEntry]:
    """Return all allowlist entries, ordered by granted_at DESC.

    active_only=True (default) excludes revoked AND expired rows.
    active_only=False returns everything for forensic / audit purposes.
    """
    if active_only:
        sql = """
            SELECT email, plan_id, granted_at, expires_at, granted_by,
                   notes, revoked_at
            FROM tester_allowlist
            WHERE revoked_at IS NULL AND expires_at > NOW()
            ORDER BY granted_at DESC
        """
    else:
        sql = """
            SELECT email, plan_id, granted_at, expires_at, granted_by,
                   notes, revoked_at
            FROM tester_allowlist
            ORDER BY granted_at DESC
        """
    row = await db.execute(text(sql))
    return [
        AllowlistEntry(
            email=r["email"],
            plan_id=r["plan_id"],
            granted_at=r["granted_at"],
            expires_at=r["expires_at"],
            granted_by=r["granted_by"],
            notes=r["notes"],
            revoked_at=r["revoked_at"],
        )
        for r in row.mappings().all()
    ]


# ── Internal helpers ─────────────────────────────────────────────────────


async def _fetch_entry(
    db: AsyncSession, normalized_email: str
) -> AllowlistEntry | None:
    """Fetch a single entry by already-normalized email, ignoring active state.

    Used by add_allowlist after upsert to return the canonical row
    (including any DB-applied defaults). Distinct from the public
    check_allowlist_entitlement which gates on revoked_at + expires_at.
    """
    row = await db.execute(
        text(
            """
            SELECT email, plan_id, granted_at, expires_at, granted_by,
                   notes, revoked_at
            FROM tester_allowlist
            WHERE email = :email
            """
        ),
        {"email": normalized_email},
    )
    result = row.mappings().first()
    if result is None:
        return None
    return AllowlistEntry(
        email=result["email"],
        plan_id=result["plan_id"],
        granted_at=result["granted_at"],
        expires_at=result["expires_at"],
        granted_by=result["granted_by"],
        notes=result["notes"],
        revoked_at=result["revoked_at"],
    )
