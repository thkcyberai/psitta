"""
grant_tester.py — Admin CLI for the Internal Alpha tester allowlist
(Item 11 — Pattern 3).

Manages rows in the ``tester_allowlist`` table that the
``get_effective_plan`` resolver (T11.2) reads when no Stripe
subscription and no dev_override row exist for a user. An active row
grants 30 days of Reading Nook Pro entitlement keyed by lowercased
email — independent of any Stripe customer record.

Subcommands
-----------
  add EMAIL [--days 30] [--granted-by NAME] [--notes TEXT] [--dry-run]
      Single-email upsert. ON CONFLICT extends expires_at and clears
      revoked_at (re-running the same grant slides expiry forward and
      un-revokes a previously revoked tester).

  add --csv PATH [--days 30] [--granted-by NAME] [--dry-run]
      Bulk upsert from CSV. Format: email[,notes]. Blank lines and
      # comments are skipped. A literal "email" header row is
      tolerated. Each row is a separate upsert and emits its own
      structured log entry — the entire batch is wrapped in one
      transaction so a mid-batch error rolls all of them back.

  revoke EMAIL [--dry-run]
      Soft-revoke. Sets revoked_at = NOW(). Idempotent: revoking an
      unknown or already-revoked email returns 0 without error.

  list [--active-only]
      Tabular print to stdout. --active-only filters to rows with
      revoked_at IS NULL AND expires_at > NOW().

Run modes
---------
  Local with DATABASE_URL or POSTGRES_* env vars::

      python scripts/grant_tester.py add alice@example.com \\
          --granted-by luis@psitta.ai --days 30 --dry-run

  ECS one-off task (production)::

      aws ecs run-task --cluster psitta-cluster \\
          --task-definition psitta-api --profile psitta-prod \\
          --region us-east-1 \\
          --overrides '{"containerOverrides":[{"name":"psitta-api",
            "command":["python","scripts/grant_tester.py","add",
                       "alice@example.com","--granted-by",
                       "luis@psitta.ai","--days","30"]}]}'

Audit trail
-----------
  Each operation emits a structured log line at INFO with the
  ``event_name`` field set to ``tester.allowlist_granted`` or
  ``tester.allowlist_revoked``. CloudWatch is the operational audit
  surface for CLI invocations — the persistent ``granted_by`` column
  on ``tester_allowlist`` is the corresponding row-level record.
"""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import logging
import os
import sys
from typing import Any
from uuid import uuid4

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  event=%(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("grant_tester")


DEFAULT_PLAN_ID = "reading_nook_pro"
DEFAULT_DAYS = 30


# ── Email normalization ─────────────────────────────────────────────────


def _normalize_email(email: str) -> str:
    """Lowercase + strip whitespace. No plus-suffix stripping.

    Mirrors ``psitta.services.tester_allowlist._normalize_email`` so
    rows written by this CLI match rows looked up by the resolver.
    Per the Apr 30 Key Learning, deferring plus-suffix stripping
    avoids gmail-style alias edge cases that aren't worth solving for
    the alpha cohort.
    """
    return email.strip().lower()


# ── Postgres config resolution (matches backfill_user_subscriptions.py) ──


def _resolve_pg_config() -> dict[str, Any]:
    """Resolve Postgres connection params from env or APP_SECRETS blob.

    Production hosts inject all secrets via ``APP_SECRETS`` (one JSON
    blob from Secrets Manager); local hosts typically use individual
    ``POSTGRES_*`` env vars. Returns a dict suitable for
    ``asyncpg.connect(**...)``.
    """
    secrets: dict[str, Any] = {}
    raw = os.environ.get("APP_SECRETS")
    if raw:
        try:
            secrets = json.loads(raw)
        except json.JSONDecodeError:
            log.warning("app_secrets_invalid_json  ignoring")

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


# ── audit_log INSERT (matches services/audit_service shape) ─────────────


async def _insert_audit_event(
    conn: Any,
    *,
    action: str,
    resource_type: str,
    details: dict[str, Any],
) -> str:
    """Insert one row into audit_log. Returns the event UUID.

    Schema notes:
      * ``resource_id`` is UUID-typed (Apr 17 Key Learning) — cannot
        carry an email. Email + free-text identifiers belong in
        ``details_json``.
      * ``user_id`` NULL is correct for CLI invocations: no Cognito
        principal is involved. The ``granted_by`` operator name is
        captured in details.
      * Migration 011 makes the table append-only via REVOKE
        UPDATE/DELETE plus BEFORE UPDATE/DELETE/TRUNCATE triggers
        (Apr 15 KL). INSERT is permitted from the app role.

    Mirrors the SQL in ``psitta.services.audit_service.log_event``
    deliberately — service-layer uses SQLAlchemy AsyncSession,
    scripts use asyncpg, but both write the same row shape so
    forensic queries treat them identically.
    """
    event_id = str(uuid4())
    await conn.execute(
        """
        INSERT INTO audit_log
            (id, user_id, action, resource_type, resource_id,
             details_json, ip_address)
        VALUES
            ($1::uuid, NULL, $2, $3, NULL, $4::jsonb, NULL)
        """,
        event_id,
        action,
        resource_type,
        json.dumps(details),
    )
    return event_id


# ── Core operations (testable: accept a connection, no I/O elsewhere) ────


async def add_allowlist_row(  # noqa: PLR0913 -- 6 grant attributes (conn, email, granted_by, days, plan_id, notes); collapsing to a TypedDict adds friction without clarifying intent at the call site
    conn: Any,
    email: str,
    granted_by: str,
    days: int = DEFAULT_DAYS,
    plan_id: str = DEFAULT_PLAN_ID,
    notes: str | None = None,
) -> dict[str, Any]:
    """Upsert one allowlist row. Returns ``{email, was_new, expires_at}``.

    Idempotent: ON CONFLICT extends expires_at to NOW()+days and
    clears revoked_at, so re-running the same grant slides expiry
    forward and un-revokes. ``was_new`` is True when a fresh row was
    inserted (xmax = 0 means no prior row); False when an existing row
    was updated.
    """
    if days <= 0:
        raise ValueError(f"days must be positive, got {days}")
    normalized = _normalize_email(email)

    # xmax = 0 ⇒ this row was just inserted (no version touched it
    # before). xmax != 0 ⇒ the ON CONFLICT branch ran (an existing
    # row was updated). Lets the CLI report "added" vs "updated"
    # without a separate SELECT round-trip.
    row = await conn.fetchrow(
        """
        INSERT INTO tester_allowlist
            (email, plan_id, granted_at, expires_at, granted_by,
             notes, created_at, updated_at)
        VALUES
            ($1, $2, NOW(), NOW() + ($3 || ' days')::interval, $4,
             $5, NOW(), NOW())
        ON CONFLICT (email) DO UPDATE SET
            plan_id = EXCLUDED.plan_id,
            expires_at = EXCLUDED.expires_at,
            granted_by = EXCLUDED.granted_by,
            notes = EXCLUDED.notes,
            revoked_at = NULL,
            updated_at = NOW()
        RETURNING email, expires_at, (xmax = 0) AS was_new
        """,
        normalized,
        plan_id,
        str(days),
        granted_by,
        notes,
    )
    expires_at = row["expires_at"]
    was_new = bool(row["was_new"])

    # Audit row written in the same transaction as the upsert. Failure
    # rolls both back — strict consistency over partial-success drift.
    await _insert_audit_event(
        conn,
        action="tester.allowlist_granted",
        resource_type="tester_allowlist",
        details={
            "email": normalized,
            "plan_id": plan_id,
            "granted_by": granted_by,
            "days": days,
            "expires_at": expires_at.isoformat(),
            "notes": notes,
            "was_new": was_new,
            "via": "cli",
        },
    )

    return {
        "email": row["email"],
        "expires_at": expires_at,
        "was_new": was_new,
    }


async def revoke_allowlist_row(
    conn: Any, email: str
) -> bool:
    """Soft-revoke. Returns True if a row was actually revoked.

    Sets revoked_at = NOW() WHERE email AND revoked_at IS NULL — so
    revoking a non-existent or already-revoked email is a no-op that
    returns False without raising. The row is preserved for audit;
    only ``revoked_at`` changes. The audit event fires only on actual
    revocation (not on no-op calls), matching the service-layer
    convention for state-changing operations.
    """
    normalized = _normalize_email(email)
    result = await conn.execute(
        """
        UPDATE tester_allowlist
        SET revoked_at = NOW(), updated_at = NOW()
        WHERE email = $1 AND revoked_at IS NULL
        """,
        normalized,
    )
    # asyncpg returns 'UPDATE N' as the result tag.
    try:
        affected = int(result.split()[-1])
    except (ValueError, IndexError):
        affected = 0

    revoked = affected > 0
    if revoked:
        await _insert_audit_event(
            conn,
            action="tester.allowlist_revoked",
            resource_type="tester_allowlist",
            details={
                "email": normalized,
                "revoked_by": "cli",
                "via": "cli",
            },
        )
    return revoked


async def list_allowlist_rows(
    conn: Any, active_only: bool = True
) -> list[dict[str, Any]]:
    """Read-only SELECT. ``active_only`` filters revoked + expired."""
    if active_only:
        sql = """
            SELECT email, plan_id, granted_at, expires_at,
                   granted_by, notes, revoked_at
            FROM tester_allowlist
            WHERE revoked_at IS NULL AND expires_at > NOW()
            ORDER BY granted_at DESC
        """
    else:
        sql = """
            SELECT email, plan_id, granted_at, expires_at,
                   granted_by, notes, revoked_at
            FROM tester_allowlist
            ORDER BY granted_at DESC
        """
    rows = await conn.fetch(sql)
    return [dict(r) for r in rows]


# ── CSV parsing ─────────────────────────────────────────────────────────


def parse_csv(path: str) -> list[tuple[str, str | None]]:
    """Parse a CSV of ``email[,notes]`` rows.

    Skipped: blank lines, lines whose first cell starts with ``#``,
    and a literal header row whose first cell equals ``email`` (case-
    insensitive). Returns a list of ``(email, notes_or_none)`` with
    emails preserved verbatim — normalization happens later in
    ``add_allowlist_row`` so the same lowercase rules apply to CLI
    and CSV input identically.
    """
    from pathlib import Path  # noqa: PLC0415 -- local import keeps top fast

    rows: list[tuple[str, str | None]] = []
    with Path(path).open(encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            first = row[0].strip()
            if not first:
                continue
            if first.startswith("#"):
                continue
            if first.lower() == "email":
                # header row
                continue
            email = first
            notes = None
            if len(row) > 1:
                trimmed = row[1].strip()
                if trimmed:
                    notes = trimmed
            rows.append((email, notes))
    return rows


# ── CLI runners ─────────────────────────────────────────────────────────


async def _connect() -> Any:
    """Open an asyncpg connection. Imported lazily so ``--help``
    doesn't require the dependency."""
    import asyncpg  # noqa: PLC0415 -- lazy import keeps --help fast

    cfg = _resolve_pg_config()
    log.info(
        "pg_connect  host=%s db=%s user=%s",
        cfg["host"],
        cfg["database"],
        cfg["user"],
    )
    return await asyncpg.connect(**cfg)


async def run_add(args: argparse.Namespace) -> int:
    targets: list[tuple[str, str | None]]
    if args.csv:
        targets = parse_csv(args.csv)
        if not targets:
            log.warning("csv_empty  path=%s", args.csv)
            return 0
        log.info("csv_loaded  path=%s rows=%d", args.csv, len(targets))
    else:
        targets = [(args.email, args.notes)]

    conn = await _connect()
    counters = {"added": 0, "updated": 0, "error": 0}
    try:
        tx = conn.transaction()
        await tx.start()
        try:
            for email, notes in targets:
                try:
                    result = await add_allowlist_row(
                        conn,
                        email=email,
                        granted_by=args.granted_by,
                        days=args.days,
                        notes=notes,
                    )
                except Exception as exc:
                    log.error(
                        "tester.allowlist_grant_failed  email=%s error=%s",
                        email,
                        exc,
                    )
                    counters["error"] += 1
                    continue
                action = "added" if result["was_new"] else "updated"
                counters[action] += 1
                log.info(
                    "tester.allowlist_granted  email=%s expires_at=%s "
                    "granted_by=%s days=%d %s",
                    result["email"],
                    result["expires_at"].isoformat(),
                    args.granted_by,
                    args.days,
                    action,
                )
        except Exception:
            await tx.rollback()
            raise

        if args.dry_run:
            await tx.rollback()
            log.info("dry_run  rolled_back  no_changes_committed")
        elif counters["error"] > 0:
            await tx.rollback()
            log.error("error_count=%d  rolled_back", counters["error"])
        else:
            await tx.commit()
    finally:
        await conn.close()

    log.info(
        "summary  added=%d updated=%d error=%d",
        counters["added"],
        counters["updated"],
        counters["error"],
    )
    return 1 if counters["error"] > 0 else 0


async def run_revoke(args: argparse.Namespace) -> int:
    conn = await _connect()
    try:
        tx = conn.transaction()
        await tx.start()
        try:
            revoked = await revoke_allowlist_row(conn, args.email)
        except Exception:
            await tx.rollback()
            raise

        if args.dry_run:
            await tx.rollback()
            log.info(
                "dry_run  would_revoke=%s email=%s",
                revoked,
                _normalize_email(args.email),
            )
        elif revoked:
            await tx.commit()
            log.info(
                "tester.allowlist_revoked  email=%s",
                _normalize_email(args.email),
            )
        else:
            await tx.rollback()
            log.info(
                "tester.allowlist_revoke_noop  email=%s reason=not_found_or_already_revoked",
                _normalize_email(args.email),
            )
    finally:
        await conn.close()
    return 0


async def run_list(args: argparse.Namespace) -> int:
    conn = await _connect()
    try:
        rows = await list_allowlist_rows(conn, active_only=args.active_only)
    finally:
        await conn.close()

    if not rows:
        log.info(
            "list_empty  active_only=%s",
            args.active_only,
        )
        return 0

    # Column widths chosen for typical alpha-cohort data: emails
    # average ~25 chars, names ~20, notes ~30. CLI list output legitimately
    # writes to stdout (matches kubectl/gh list conventions); logger goes
    # to stderr-bound CloudWatch and is the wrong tool for tabular UX.
    print(f"{len(rows)} row(s):")  # noqa: T201
    print(  # noqa: T201
        f"{'email':32}  {'plan_id':18}  {'expires_at':25}  "
        f"{'granted_by':22}  {'revoked':7}  notes"
    )
    print("-" * 130)  # noqa: T201
    for r in rows:
        revoked_marker = "yes" if r.get("revoked_at") else ""
        print(  # noqa: T201
            f"{r['email']:32}  {r['plan_id']:18}  "
            f"{r['expires_at'].isoformat():25}  "
            f"{r['granted_by']:22}  {revoked_marker:7}  "
            f"{r.get('notes') or ''}"
        )
    return 0


# ── argparse plumbing ───────────────────────────────────────────────────


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Admin CLI for the Internal Alpha tester allowlist. Manages "
            "rows in the tester_allowlist table that grant 30-day "
            "Reading Nook Pro access without Stripe."
        ),
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    # add
    p_add = sub.add_parser("add", help="Add or extend an allowlist entry")
    add_target = p_add.add_mutually_exclusive_group(required=True)
    add_target.add_argument(
        "email",
        nargs="?",
        help="Single email to add. Mutually exclusive with --csv.",
    )
    add_target.add_argument(
        "--csv",
        help="CSV path with email[,notes] rows for bulk add.",
    )
    p_add.add_argument(
        "--days",
        type=int,
        default=DEFAULT_DAYS,
        help=f"Days of access (default: {DEFAULT_DAYS}).",
    )
    p_add.add_argument(
        "--granted-by",
        required=True,
        help="Operator name or email for audit trail.",
    )
    p_add.add_argument(
        "--notes",
        help="Optional notes column (single-add only; CSV uses its own).",
    )
    p_add.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be inserted, then roll back.",
    )

    # revoke
    p_rev = sub.add_parser("revoke", help="Soft-revoke an allowlist entry")
    p_rev.add_argument("email", help="Email to revoke (lowercased on lookup).")
    p_rev.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be revoked, then roll back.",
    )

    # list
    p_list = sub.add_parser("list", help="List allowlist entries")
    p_list.add_argument(
        "--active-only",
        action="store_true",
        help="Show only active rows (revoked_at IS NULL AND expires_at > NOW()).",
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "add":
        return asyncio.run(run_add(args))
    if args.cmd == "revoke":
        return asyncio.run(run_revoke(args))
    if args.cmd == "list":
        return asyncio.run(run_list(args))
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
