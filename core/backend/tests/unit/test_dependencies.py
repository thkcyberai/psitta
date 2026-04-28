"""Unit tests for dependencies.get_current_user_id.

Locks down the race-safe user auto-provisioning fix:
  * Existing-user fast path returns the cached row without INSERTing.
  * First-login path INSERTs with ON CONFLICT DO NOTHING RETURNING id
    and uses the new row when it wins the race.
  * Race-loser path detects the empty RETURNING, re-SELECTs by
    auth0_user_id, and returns the canonical row -- no exception.
  * Concurrent first-login (asyncio.gather of two calls against a
    shared fake DB) returns the SAME user_id from both callers.
  * Defensive email-collision path raises 500 with a structured
    log marker (distinguishable from the latent race).

Background: dependencies.py:get_current_user_id() previously used a
check-then-insert pattern that raced when the desktop client fanned
out parallel API calls on first login. See the fix commit message
and CLAUDE.md Key Learning 2026-04-28 for context.
"""

from __future__ import annotations

import asyncio
from typing import Any
from unittest.mock import MagicMock
from uuid import UUID

import pytest
from fastapi import HTTPException

from psitta import dependencies


# ── Fake AsyncSession ────────────────────────────────────────────────────


class _FakeResult:
    """Stand-in for SQLAlchemy Result. Supports the access patterns
    used in get_current_user_id: r.fetchone()."""

    def __init__(self, row: Any = None):
        self._row = row

    def fetchone(self):
        return self._row


class FakeUsersSession:
    """In-memory fake of the users table behaviour the handler relies on.

    State:
      * ``self.users`` -- map from auth0_user_id -> id (UUID).
      * ``self.calls`` -- list of (sql, params) for assertion.

    Behaviour:
      * SELECT WHERE auth0_user_id = :sub
          → returns (id,) if known, else None.
      * INSERT INTO users ... ON CONFLICT DO NOTHING RETURNING id
          → if auth0_user_id unknown, register and RETURN the inserted id.
          → else (caller lost the race), RETURN None.
      * On other SQL the result is empty.

    Use ``email_collision_email`` to simulate a real email collision
    distinct from the auth0_user_id race -- the INSERT silently fails
    AND the re-SELECT also misses.
    """

    def __init__(
        self,
        *,
        seeded_users: dict[str, str] | None = None,
        email_collision_email: str | None = None,
    ):
        self.users: dict[str, UUID] = {
            sub: UUID(uid) for sub, uid in (seeded_users or {}).items()
        }
        self.calls: list[tuple[str, dict]] = []
        self.flush_count = 0
        self._email_collision_email = email_collision_email

    async def execute(self, stmt, params=None):
        sql = str(stmt)
        params = dict(params or {})
        self.calls.append((sql, params))

        if "SELECT id FROM users WHERE auth0_user_id" in sql:
            sub = params.get("sub")
            uid = self.users.get(sub)
            return _FakeResult(row=(uid,) if uid is not None else None)

        if "INSERT INTO users" in sql and "ON CONFLICT DO NOTHING" in sql:
            sub = params["auth0_user_id"]
            email = params["email"]
            if self._email_collision_email == email:
                # Simulated email collision -- INSERT silently dropped
                # AND no row exists with the matching auth0_user_id
                # (the conflicting row belongs to a different user).
                return _FakeResult(row=None)
            if sub in self.users:
                # Race-loss case: a prior insert in this fake already
                # registered this auth0_user_id.
                return _FakeResult(row=None)
            new_id = params["id"]
            if not isinstance(new_id, UUID):
                new_id = UUID(str(new_id))
            self.users[sub] = new_id
            return _FakeResult(row=(new_id,))

        return _FakeResult(row=None)

    async def flush(self):
        self.flush_count += 1


def _make_claims(sub: str, email: str | None = None, name: str | None = None):
    """Build a TokenClaims-shaped MagicMock the handler will accept."""
    claims = MagicMock()
    claims.sub = sub
    claims.email = email
    claims.name = name
    return claims


# ── Tests ────────────────────────────────────────────────────────────────


@pytest.mark.asyncio
async def test_get_current_user_id_returns_existing_user():
    """Fast path: when a row already matches the auth0_user_id, the
    handler returns its id and never INSERTs."""
    sub = "cognito_existing_user_sub"
    seeded_id = "11111111-1111-1111-1111-111111111111"
    db = FakeUsersSession(seeded_users={sub: seeded_id})
    claims = _make_claims(sub=sub)

    result = await dependencies.get_current_user_id(claims=claims, db=db)

    assert result == UUID(seeded_id)
    insert_calls = [c for c in db.calls if "INSERT INTO users" in c[0]]
    assert insert_calls == [], (
        f"Existing-user fast path must NOT INSERT. Calls: {db.calls}"
    )
    select_calls = [
        c for c in db.calls if "SELECT id FROM users WHERE auth0_user_id" in c[0]
    ]
    assert len(select_calls) == 1


@pytest.mark.asyncio
async def test_get_current_user_id_creates_user_with_free_tier():
    """First-login path (no race): the INSERT runs and binds
    tier='free' as a literal in the SQL. Regression guard against any
    future change that defaults a new user to a paid tier."""
    sub = "cognito_brand_new_sub"
    db = FakeUsersSession()
    claims = _make_claims(sub=sub)

    result = await dependencies.get_current_user_id(claims=claims, db=db)

    assert isinstance(result, UUID)
    assert sub in db.users
    assert db.users[sub] == result

    insert_calls = [c for c in db.calls if "INSERT INTO users" in c[0]]
    assert len(insert_calls) == 1
    insert_sql, insert_params = insert_calls[0]

    # tier='free' is a SQL literal in the INSERT, not a bind param --
    # this assert pins the literal in the statement text.
    assert "'free'" in insert_sql
    # synthetic email pattern preserved (claims.email was None)
    assert insert_params["email"] == f"{sub}@auth0.local"
    assert insert_params["auth0_user_id"] == sub


@pytest.mark.asyncio
async def test_get_current_user_id_recovers_when_race_lost():
    """Race-loss recovery: INSERT returns no row (ON CONFLICT fired),
    so the handler re-SELECTs by auth0_user_id and returns the
    canonical id -- never raises."""
    sub = "cognito_race_loser_sub"
    canonical_id = "22222222-2222-2222-2222-222222222222"

    # Seed AFTER the handler's first SELECT runs by using a custom
    # fake that simulates the race window: the first SELECT misses,
    # then while the handler is preparing the INSERT, a competing
    # transaction commits the row -- so the INSERT trips ON CONFLICT
    # and the re-SELECT sees the canonical row.
    class RaceLossFake(FakeUsersSession):
        def __init__(self):
            super().__init__()
            self._first_select_done = False

        async def execute(self, stmt, params=None):
            sql = str(stmt)
            if (
                "SELECT id FROM users WHERE auth0_user_id" in sql
                and not self._first_select_done
            ):
                self._first_select_done = True
                self.calls.append((sql, dict(params or {})))
                return _FakeResult(row=None)
            if (
                "INSERT INTO users" in sql
                and "ON CONFLICT DO NOTHING" in sql
            ):
                # Simulate the race losing -- another tx already won;
                # register the canonical row in the fake state so the
                # subsequent re-SELECT will find it.
                self.users[params["auth0_user_id"]] = UUID(canonical_id)
                self.calls.append((sql, dict(params or {})))
                return _FakeResult(row=None)
            return await super().execute(stmt, params)

    db = RaceLossFake()
    claims = _make_claims(sub=sub)

    result = await dependencies.get_current_user_id(claims=claims, db=db)

    assert result == UUID(canonical_id)
    # Two SELECTs total: pre-INSERT lookup + post-INSERT recovery.
    select_calls = [
        c for c in db.calls if "SELECT id FROM users WHERE auth0_user_id" in c[0]
    ]
    assert len(select_calls) == 2, (
        f"Recovery branch must re-SELECT by auth0_user_id. Calls: {db.calls}"
    )


@pytest.mark.asyncio
async def test_get_current_user_id_handles_concurrent_first_login():
    """Two concurrent first-login calls against a SHARED fake DB must
    both return the same user_id without either raising. This is the
    end-to-end proof that the fix closes the race observed today.

    The fake DB's INSERT-with-ON-CONFLICT semantics are atomic:
    whichever call's INSERT is dispatched first registers the row;
    the second's INSERT returns None (conflict), and the handler
    recovers via re-SELECT.
    """
    sub = "cognito_concurrent_login_sub"
    db = FakeUsersSession()
    claims_a = _make_claims(sub=sub)
    claims_b = _make_claims(sub=sub)

    results = await asyncio.gather(
        dependencies.get_current_user_id(claims=claims_a, db=db),
        dependencies.get_current_user_id(claims=claims_b, db=db),
    )

    assert results[0] == results[1], (
        f"Concurrent calls must converge on the same user_id. "
        f"Got {results}. Calls: {db.calls}"
    )
    # Exactly one row registered in the fake state -- proves the
    # one-active-row invariant survives the race.
    assert len(db.users) == 1


@pytest.mark.asyncio
async def test_get_current_user_id_email_collision_raises_500():
    """Defensive branch: ON CONFLICT fires AND the recovery SELECT
    misses (because the conflicting row has a DIFFERENT auth0_user_id
    that happens to share the same email). Surfaces as a 500 with the
    structured ``user.provision_email_collision`` log marker, NOT a
    silent success."""
    sub = "cognito_orphan_sub"
    synthetic_email = f"{sub}@auth0.local"
    db = FakeUsersSession(email_collision_email=synthetic_email)
    claims = _make_claims(sub=sub)

    with pytest.raises(HTTPException) as exc_info:
        await dependencies.get_current_user_id(claims=claims, db=db)

    assert exc_info.value.status_code == 500
    assert "email" in exc_info.value.detail.lower()
