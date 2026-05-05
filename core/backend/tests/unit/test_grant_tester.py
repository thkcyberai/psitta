"""Unit tests for scripts/grant_tester.py.

Covers:
  * add_allowlist_row issues an UPSERT with normalized email, returns
    was_new based on xmax sentinel (true=insert, false=update)
  * revoke_allowlist_row sets revoked_at and reports whether a row
    was actually affected (idempotent on missing/already-revoked)
  * _normalize_email lowercases + strips, no plus-suffix stripping
    (matches services/tester_allowlist for resolver consistency)
  * parse_csv handles blank lines, # comments, header row, and the
    optional notes second column
  * Dry-run path rolls back the transaction (no write)

The script uses raw asyncpg, not SQLAlchemy. Tests pass a fake
connection object that records every execute / fetchrow / fetch call
and returns canned results — same shape pattern as the
RecordingSession used in test_resolver.py and test_tester_allowlist.py
but adapted to asyncpg's positional-args API.

scripts/ isn't on the package import path, so tests load the script
via importlib.util to access its symbols.
"""

from __future__ import annotations

import importlib.util
import json
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from unittest.mock import AsyncMock

import pytest

# Load grant_tester as a module without it being a package member.
_SCRIPT_PATH = (
    Path(__file__).resolve().parents[2]
    / "scripts"
    / "grant_tester.py"
)
_spec = importlib.util.spec_from_file_location("grant_tester", _SCRIPT_PATH)
assert _spec is not None and _spec.loader is not None
grant_tester = importlib.util.module_from_spec(_spec)
sys.modules["grant_tester"] = grant_tester
_spec.loader.exec_module(grant_tester)


# ── Fake asyncpg connection ─────────────────────────────────────────────


class FakeRow(dict):
    """asyncpg Record stand-in: dict access + ``.get()`` already work."""


class FakeTxn:
    def __init__(self):
        self.started = False
        self.committed = False
        self.rolled_back = False

    async def start(self):
        self.started = True

    async def commit(self):
        self.committed = True

    async def rollback(self):
        self.rolled_back = True


class FakeConn:
    """asyncpg.Connection stand-in.

    ``execute_returns`` keys are SQL substrings; the first match wins
    and provides the result tag string for ``execute()`` calls.
    ``fetchrow_returns`` is the canned single-row response for
    ``fetchrow()`` calls. ``fetch_returns`` is the canned list-of-rows
    for ``fetch()``. Tests inspect ``self.calls`` to assert on the
    issued SQL and bound positional parameters.
    """

    def __init__(
        self,
        execute_returns: dict[str, str] | None = None,
        fetchrow_returns: FakeRow | None = None,
        fetch_returns: list[FakeRow] | None = None,
    ):
        self._exec = execute_returns or {}
        self._row = fetchrow_returns
        self._rows = fetch_returns or []
        self.calls: list[tuple[str, str, tuple]] = []  # (kind, sql, args)
        self.txn = FakeTxn()

    async def execute(self, sql: str, *args: Any) -> str:
        self.calls.append(("execute", sql, args))
        for key, tag in self._exec.items():
            if key in sql:
                return tag
        return "UPDATE 0"

    async def fetchrow(self, sql: str, *args: Any) -> FakeRow | None:
        self.calls.append(("fetchrow", sql, args))
        return self._row

    async def fetch(self, sql: str, *args: Any) -> list[FakeRow]:
        self.calls.append(("fetch", sql, args))
        return self._rows

    def transaction(self) -> FakeTxn:
        return self.txn

    async def close(self) -> None:
        pass


# ── _normalize_email ────────────────────────────────────────────────────


class TestNormalize:
    def test_lowercases(self):
        assert grant_tester._normalize_email("Alice@Example.COM") == "alice@example.com"

    def test_strips_whitespace(self):
        assert grant_tester._normalize_email("  bob@example.com  ") == "bob@example.com"

    def test_does_not_strip_plus_suffix(self):
        # Per Apr 30 KL — defer plus-suffix stripping. Must match
        # services/tester_allowlist convention exactly so CLI-written
        # rows are findable by the resolver.
        assert (
            grant_tester._normalize_email("user+alpha@example.com")
            == "user+alpha@example.com"
        )


# ── add_allowlist_row ───────────────────────────────────────────────────


@pytest.mark.asyncio
class TestAddAllowlistRow:
    async def test_inserts_with_lowercased_email(self):
        expires = datetime.now(UTC) + timedelta(days=30)
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=expires,
                was_new=True,
            )
        )

        result = await grant_tester.add_allowlist_row(
            conn,
            email="Alice@Example.COM",
            granted_by="luis@psitta.ai",
            days=30,
            notes="batch 1",
        )

        assert result["was_new"] is True
        assert result["email"] == "alice@example.com"

        # 1 fetchrow (upsert) + 1 execute (audit_log INSERT)
        kinds = [c[0] for c in conn.calls]
        assert kinds == ["fetchrow", "execute"]
        sql, args = conn.calls[0][1], conn.calls[0][2]
        assert "INSERT INTO tester_allowlist" in sql
        assert "ON CONFLICT (email) DO UPDATE" in sql
        assert "revoked_at = NULL" in sql
        assert args[0] == "alice@example.com"  # email lowercased
        assert args[1] == "reading_nook_pro"   # default plan
        assert args[2] == "30"                  # days as str (interval cast)
        assert args[3] == "luis@psitta.ai"     # granted_by
        assert args[4] == "batch 1"             # notes

    async def test_update_path_returns_was_new_false(self):
        expires = datetime.now(UTC) + timedelta(days=30)
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=expires,
                was_new=False,  # ON CONFLICT branch ran
            )
        )

        result = await grant_tester.add_allowlist_row(
            conn,
            email="alice@example.com",
            granted_by="luis@psitta.ai",
        )

        assert result["was_new"] is False

    async def test_negative_days_rejected(self):
        conn = FakeConn()
        with pytest.raises(ValueError, match="days must be positive"):
            await grant_tester.add_allowlist_row(
                conn,
                email="alice@example.com",
                granted_by="luis",
                days=0,
            )
        assert conn.calls == []  # no DB I/O attempted

    async def test_revoked_at_cleared_in_upsert_clause(self):
        # The ON CONFLICT clause MUST set revoked_at = NULL — that's
        # how re-adding a previously revoked tester un-revokes them.
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=datetime.now(UTC) + timedelta(days=30),
                was_new=False,
            )
        )
        await grant_tester.add_allowlist_row(
            conn, email="alice@example.com", granted_by="luis"
        )
        sql = conn.calls[0][1]
        assert "revoked_at = NULL" in sql

    async def test_emits_audit_log_event(self):
        # Every successful add must INSERT into audit_log alongside
        # the upsert — table-level forensic trail (Apr 17 KL: resource_id
        # is UUID type, so email lives in details_json instead).
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=datetime.now(UTC) + timedelta(days=30),
                was_new=True,
            )
        )
        await grant_tester.add_allowlist_row(
            conn,
            email="alice@example.com",
            granted_by="luis@psitta.ai",
            days=30,
            notes="batch 1",
        )

        audit_calls = [c for c in conn.calls if "audit_log" in c[1]]
        assert len(audit_calls) == 1
        sql, args = audit_calls[0][1], audit_calls[0][2]
        assert "INSERT INTO audit_log" in sql
        # Parameter order: id, action, resource_type, details_json
        assert args[1] == "tester.allowlist_granted"
        assert args[2] == "tester_allowlist"
        details = json.loads(args[3])
        assert details["email"] == "alice@example.com"
        assert details["granted_by"] == "luis@psitta.ai"
        assert details["days"] == 30
        assert details["notes"] == "batch 1"
        assert details["was_new"] is True
        assert details["via"] == "cli"
        assert "expires_at" in details


# ── revoke_allowlist_row ────────────────────────────────────────────────


@pytest.mark.asyncio
class TestRevokeAllowlistRow:
    async def test_returns_true_when_row_affected(self):
        # FakeConn returns the same tag for every execute() that matches
        # the substring; both the UPDATE and the audit INSERT match.
        # Use a more specific key so the revoke UPDATE returns "UPDATE 1"
        # while the audit INSERT returns the default tag.
        conn = FakeConn(
            execute_returns={
                "UPDATE tester_allowlist\n        SET revoked_at": "UPDATE 1",
            }
        )
        revoked = await grant_tester.revoke_allowlist_row(conn, "Alice@Example.com")
        assert revoked is True
        # First call is the UPDATE
        sql, args = conn.calls[0][1], conn.calls[0][2]
        assert "UPDATE tester_allowlist" in sql
        assert "SET revoked_at = NOW()" in sql
        assert "WHERE email = $1 AND revoked_at IS NULL" in sql
        assert args[0] == "alice@example.com"

    async def test_returns_false_when_no_row_matched(self):
        conn = FakeConn(execute_returns={"UPDATE tester_allowlist": "UPDATE 0"})
        revoked = await grant_tester.revoke_allowlist_row(conn, "missing@example.com")
        assert revoked is False
        # No-op revoke must NOT emit an audit event (matches service-layer
        # convention: only state-changing operations are audited)
        audit_calls = [c for c in conn.calls if "audit_log" in c[1]]
        assert audit_calls == []

    async def test_emits_audit_log_event_on_successful_revoke(self):
        conn = FakeConn(
            execute_returns={
                "UPDATE tester_allowlist\n        SET revoked_at": "UPDATE 1",
            }
        )
        await grant_tester.revoke_allowlist_row(conn, "alice@example.com")

        audit_calls = [c for c in conn.calls if "audit_log" in c[1]]
        assert len(audit_calls) == 1
        sql, args = audit_calls[0][1], audit_calls[0][2]
        assert "INSERT INTO audit_log" in sql
        assert args[1] == "tester.allowlist_revoked"
        assert args[2] == "tester_allowlist"
        details = json.loads(args[3])
        assert details["email"] == "alice@example.com"
        assert details["revoked_by"] == "cli"
        assert details["via"] == "cli"


# ── parse_csv ───────────────────────────────────────────────────────────


class TestParseCsv:
    def _write(self, tmp_path: Path, content: str) -> str:
        p = tmp_path / "testers.csv"
        p.write_text(content, encoding="utf-8")
        return str(p)

    def test_email_only(self, tmp_path):
        path = self._write(tmp_path, "alice@example.com\nbob@example.com\n")
        rows = grant_tester.parse_csv(path)
        assert rows == [
            ("alice@example.com", None),
            ("bob@example.com", None),
        ]

    def test_email_with_notes(self, tmp_path):
        path = self._write(
            tmp_path,
            "alice@example.com,batch 1\n"
            "bob@example.com,design partner\n",
        )
        rows = grant_tester.parse_csv(path)
        assert rows == [
            ("alice@example.com", "batch 1"),
            ("bob@example.com", "design partner"),
        ]

    def test_skips_blank_and_comment_lines(self, tmp_path):
        path = self._write(
            tmp_path,
            "# Internal alpha — Q2 2026\n"
            "\n"
            "alice@example.com\n"
            "  \n"
            "# bob is on hold\n"
            "carol@example.com,early access\n",
        )
        rows = grant_tester.parse_csv(path)
        assert rows == [
            ("alice@example.com", None),
            ("carol@example.com", "early access"),
        ]

    def test_skips_header_row(self, tmp_path):
        path = self._write(
            tmp_path,
            "email,notes\n"
            "alice@example.com,first\n",
        )
        rows = grant_tester.parse_csv(path)
        assert rows == [("alice@example.com", "first")]

    def test_skips_header_case_insensitive(self, tmp_path):
        path = self._write(tmp_path, "EMAIL\nalice@example.com\n")
        rows = grant_tester.parse_csv(path)
        assert rows == [("alice@example.com", None)]

    def test_empty_notes_column_treated_as_none(self, tmp_path):
        path = self._write(tmp_path, "alice@example.com,   \n")
        rows = grant_tester.parse_csv(path)
        assert rows == [("alice@example.com", None)]


# ── run_add transaction discipline (dry-run rolls back) ─────────────────


@pytest.mark.asyncio
class TestRunAddDryRun:
    async def test_dry_run_rolls_back_transaction(self, monkeypatch):
        # Patch _connect to return our FakeConn, bypass asyncpg.
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=datetime.now(UTC) + timedelta(days=30),
                was_new=True,
            )
        )
        monkeypatch.setattr(grant_tester, "_connect", AsyncMock(return_value=conn))

        args = grant_tester.build_parser().parse_args([
            "add",
            "alice@example.com",
            "--granted-by", "luis@psitta.ai",
            "--days", "30",
            "--dry-run",
        ])
        rc = await grant_tester.run_add(args)

        assert rc == 0
        assert conn.txn.started is True
        assert conn.txn.rolled_back is True
        assert conn.txn.committed is False
        # Both the upsert AND the audit INSERT must have been issued
        # before the rollback — proving they're in the same transaction
        # and dry-run reverts them together.
        kinds_and_tables = [
            (kind, "tester_allowlist" in sql, "audit_log" in sql)
            for kind, sql, _ in conn.calls
        ]
        assert ("fetchrow", True, False) in kinds_and_tables  # upsert
        assert ("execute", False, True) in kinds_and_tables    # audit

    async def test_real_run_commits(self, monkeypatch):
        conn = FakeConn(
            fetchrow_returns=FakeRow(
                email="alice@example.com",
                expires_at=datetime.now(UTC) + timedelta(days=30),
                was_new=True,
            )
        )
        monkeypatch.setattr(grant_tester, "_connect", AsyncMock(return_value=conn))

        args = grant_tester.build_parser().parse_args([
            "add",
            "alice@example.com",
            "--granted-by", "luis@psitta.ai",
        ])
        rc = await grant_tester.run_add(args)

        assert rc == 0
        assert conn.txn.committed is True
        assert conn.txn.rolled_back is False


# ── run_list output shape ───────────────────────────────────────────────


@pytest.mark.asyncio
async def test_run_list_prints_rows(monkeypatch, capsys):
    expires = datetime.now(UTC) + timedelta(days=20)
    granted = datetime.now(UTC) - timedelta(days=10)
    conn = FakeConn(
        fetch_returns=[
            FakeRow(
                email="alice@example.com",
                plan_id="reading_nook_pro",
                granted_at=granted,
                expires_at=expires,
                granted_by="luis@psitta.ai",
                notes="batch 1",
                revoked_at=None,
            )
        ]
    )
    monkeypatch.setattr(grant_tester, "_connect", AsyncMock(return_value=conn))

    args = grant_tester.build_parser().parse_args(["list", "--active-only"])
    rc = await grant_tester.run_list(args)
    assert rc == 0

    out = capsys.readouterr().out
    assert "1 row(s):" in out
    assert "alice@example.com" in out
    assert "reading_nook_pro" in out
    assert "batch 1" in out
    # Active-only must filter at the SQL layer, not in Python
    sql = conn.calls[0][1]
    assert "revoked_at IS NULL" in sql
    assert "expires_at > NOW()" in sql
