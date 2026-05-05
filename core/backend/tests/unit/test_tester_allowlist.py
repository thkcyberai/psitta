"""Unit tests for services/tester_allowlist.py.

Covers:
  * Email normalization (lowercase, strip whitespace; no plus-suffix
    stripping per Apr 30 Key Learning)
  * check_allowlist_entitlement returns AllowlistEntry on active row,
    None on expired/revoked/missing
  * add_allowlist issues an UPSERT with NOW() + days for expires_at
  * revoke_allowlist issues a soft-revoke UPDATE
  * list_allowlist with active_only filter

DB I/O is exercised through a recording fake AsyncSession (no live
Postgres) — same pattern as tests/unit/test_billing_handlers.py. The
real migration is verified by running it against ECS in PART G.
"""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import AsyncMock

import pytest

from psitta.services.tester_allowlist import (
    DEFAULT_GRANT_DAYS,
    DEFAULT_PLAN_ID,
    AllowlistEntry,
    _normalize_email,
    add_allowlist,
    check_allowlist_entitlement,
    list_allowlist,
    revoke_allowlist,
)

# ── Fake DB scaffolding ──────────────────────────────────────────────────


class _FakeResult:
    """Stand-in for SQLAlchemy Result. Supports the access patterns
    used by the service: .mappings().first(), .mappings().all(), and
    the .rowcount attribute consumed by revoke_allowlist."""

    def __init__(
        self,
        mapping: dict | None = None,
        mappings: list[dict] | None = None,
        rowcount: int = 0,
    ):
        self._mapping = mapping
        self._mappings = mappings or []
        self.rowcount = rowcount

    def mappings(self):
        return self

    def first(self):
        return self._mapping

    def all(self):
        return self._mappings


class RecordingSession:
    """AsyncSession stand-in that records every execute() call and
    optionally returns a canned result based on a SQL substring match.
    """

    def __init__(self, result_map: dict[str, _FakeResult] | None = None):
        self._result_map = result_map or {}
        self.calls: list[tuple[str, dict]] = []
        self.commit = AsyncMock()

    async def execute(self, stmt: Any, params: Any = None):
        sql = str(stmt)
        self.calls.append((sql, dict(params or {})))
        for key, result in self._result_map.items():
            if key in sql:
                return result
        return _FakeResult(mapping=None, mappings=[], rowcount=0)


def _now() -> datetime:
    return datetime.now(UTC)


def _entry_row(
    email: str = "alice@example.com",
    plan_id: str = "reading_nook_pro",
    expires_at: datetime | None = None,
    revoked_at: datetime | None = None,
) -> dict:
    """Build a row mapping shaped like SELECT … FROM tester_allowlist."""
    return {
        "email": email,
        "plan_id": plan_id,
        "granted_at": _now() - timedelta(days=1),
        "expires_at": expires_at if expires_at is not None else _now() + timedelta(days=29),
        "granted_by": "test@psitta.ai",
        "notes": None,
        "revoked_at": revoked_at,
    }


# ── _normalize_email ─────────────────────────────────────────────────────


class TestNormalize:
    def test_lowercases(self):
        assert _normalize_email("Alice@Example.COM") == "alice@example.com"

    def test_strips_whitespace(self):
        assert _normalize_email("  bob@example.com  ") == "bob@example.com"

    def test_does_not_strip_plus_suffix(self):
        # Per Apr 30 Key Learning — defer plus-suffix stripping.
        assert (
            _normalize_email("user+alpha@example.com")
            == "user+alpha@example.com"
        )

    def test_empty_string(self):
        assert _normalize_email("") == ""


# ── check_allowlist_entitlement ──────────────────────────────────────────


@pytest.mark.asyncio
class TestCheckEntitlement:
    async def test_returns_entry_for_active_row(self):
        row = _entry_row()
        db = RecordingSession({"FROM tester_allowlist": _FakeResult(mapping=row)})

        entry = await check_allowlist_entitlement(db, "Alice@Example.com")

        assert isinstance(entry, AllowlistEntry)
        assert entry.email == "alice@example.com"
        assert entry.plan_id == "reading_nook_pro"
        # The query must filter on revoked_at IS NULL AND expires_at > NOW()
        sql, params = db.calls[0]
        assert "revoked_at IS NULL" in sql
        assert "expires_at > NOW()" in sql
        assert params == {"email": "alice@example.com"}

    async def test_returns_none_when_not_found(self):
        # Default fake returns mapping=None on no match.
        db = RecordingSession()
        entry = await check_allowlist_entitlement(db, "missing@example.com")
        assert entry is None

    async def test_lowercases_lookup(self):
        db = RecordingSession()
        await check_allowlist_entitlement(db, "Alice@Example.com")
        _, params = db.calls[0]
        assert params["email"] == "alice@example.com"

    async def test_empty_email_returns_none_without_query(self):
        db = RecordingSession()
        entry = await check_allowlist_entitlement(db, "")
        assert entry is None
        assert db.calls == []

    async def test_expired_or_revoked_filtered_at_query_level(self):
        # The fake returns nothing when WHERE clause excludes the row.
        # We rely on the SQL filter; assert it's present, not the
        # filtered behaviour itself (that's a Postgres concern, covered
        # by integration tests in T11.2 verification).
        db = RecordingSession()
        await check_allowlist_entitlement(db, "expired@example.com")
        sql, _ = db.calls[0]
        assert "revoked_at IS NULL" in sql
        assert "expires_at > NOW()" in sql


# ── add_allowlist ────────────────────────────────────────────────────────


@pytest.mark.asyncio
class TestAddAllowlist:
    async def test_inserts_with_lowercased_email(self):
        # First call is the INSERT; second is _fetch_entry (returns row).
        db = RecordingSession({
            "FROM tester_allowlist\n            WHERE email = :email\n            ":
                _FakeResult(mapping=_entry_row(email="alice@example.com")),
        })

        entry = await add_allowlist(
            db,
            email="Alice@Example.com",
            granted_by="luis@psitta.ai",
        )

        insert_sql, insert_params = db.calls[0]
        assert "INSERT INTO tester_allowlist" in insert_sql
        assert "ON CONFLICT (email) DO UPDATE" in insert_sql
        assert insert_params["email"] == "alice@example.com"
        assert insert_params["plan_id"] == DEFAULT_PLAN_ID
        assert insert_params["granted_by"] == "luis@psitta.ai"
        # expires_at must be ~30 days from now
        delta = insert_params["expires_at"] - _now()
        assert (
            timedelta(days=DEFAULT_GRANT_DAYS - 1)
            < delta
            <= timedelta(days=DEFAULT_GRANT_DAYS, seconds=5)
        )
        assert isinstance(entry, AllowlistEntry)
        db.commit.assert_awaited()

    async def test_custom_days_param(self):
        db = RecordingSession({
            "FROM tester_allowlist\n            WHERE email = :email\n            ":
                _FakeResult(mapping=_entry_row()),
        })
        await add_allowlist(
            db, "alice@example.com", granted_by="luis", days=60
        )
        _, params = db.calls[0]
        delta = params["expires_at"] - _now()
        assert timedelta(days=59) < delta <= timedelta(days=60, seconds=5)

    async def test_negative_days_rejected(self):
        db = RecordingSession()
        with pytest.raises(ValueError, match="days must be positive"):
            await add_allowlist(db, "alice@example.com", "luis", days=0)
        assert db.calls == []

    async def test_clears_revoked_at_on_conflict(self):
        # Verify the ON CONFLICT clause sets revoked_at = NULL — key for
        # idempotent re-grants of previously revoked testers.
        db = RecordingSession({
            "FROM tester_allowlist\n            WHERE email = :email\n            ":
                _FakeResult(mapping=_entry_row()),
        })
        await add_allowlist(db, "alice@example.com", "luis")
        sql, _ = db.calls[0]
        assert "revoked_at = NULL" in sql


# ── revoke_allowlist ─────────────────────────────────────────────────────


@pytest.mark.asyncio
class TestRevokeAllowlist:
    async def test_returns_true_on_active_revoke(self):
        db = RecordingSession({"UPDATE tester_allowlist": _FakeResult(rowcount=1)})
        revoked = await revoke_allowlist(db, "Alice@Example.com")
        assert revoked is True
        sql, params = db.calls[0]
        assert "UPDATE tester_allowlist" in sql
        assert "SET revoked_at = NOW()" in sql
        assert "WHERE email = :email AND revoked_at IS NULL" in sql
        assert params == {"email": "alice@example.com"}
        db.commit.assert_awaited()

    async def test_returns_false_when_no_row_affected(self):
        db = RecordingSession({"UPDATE tester_allowlist": _FakeResult(rowcount=0)})
        revoked = await revoke_allowlist(db, "missing@example.com")
        assert revoked is False


# ── list_allowlist ──────────────────────────────────────────────────────


@pytest.mark.asyncio
class TestListAllowlist:
    async def test_active_only_filters_at_query_level(self):
        db = RecordingSession({
            "FROM tester_allowlist": _FakeResult(mappings=[_entry_row()]),
        })
        entries = await list_allowlist(db, active_only=True)
        sql, _ = db.calls[0]
        assert "revoked_at IS NULL AND expires_at > NOW()" in sql
        assert len(entries) == 1
        assert entries[0].email == "alice@example.com"

    async def test_active_only_false_no_filter(self):
        db = RecordingSession({
            "FROM tester_allowlist": _FakeResult(mappings=[
                _entry_row(),
                _entry_row(email="bob@example.com", revoked_at=_now()),
            ]),
        })
        entries = await list_allowlist(db, active_only=False)
        sql, _ = db.calls[0]
        assert "revoked_at IS NULL" not in sql
        assert len(entries) == 2
