"""audit_log append-only enforcement (SOC 2 CC7.2).

Tamper-evidence for the audit_log table, enforced at three layers:

1. Privilege revocation — the application role (`psitta`) loses UPDATE and
   DELETE on audit_log. INSERT and SELECT remain, so the app can still write
   and read audit records.
2. Row-level trigger guard — a BEFORE UPDATE OR DELETE FOR EACH ROW trigger
   raises an exception on any mutation attempt, regardless of the role
   performing it. Catches superuser sessions, future roles, and privilege
   drift that would otherwise silently re-enable mutations.
3. Statement-level TRUNCATE guard — a BEFORE TRUNCATE FOR EACH STATEMENT
   trigger blocks bulk erasure. TRUNCATE is not a grantable PostgreSQL
   privilege (only table owners / superusers can issue it), so the trigger
   is the only portable defense.

Defense in depth: any single layer alone leaves a hole. Row-level without
truncate guard → bypassable by `TRUNCATE audit_log`. Privilege revoke
without triggers → bypassable by a superuser or future role. All three
are required for SOC 2 CC7.2 evidence.

Revision ID: 011
Revises: 010
Create Date: 2026-04-15
"""

from __future__ import annotations

from alembic import op

# revision identifiers, used by Alembic.
revision = "011"
down_revision = "010"
branch_labels = None
depends_on = None


APP_ROLE = "psitta"


def upgrade() -> None:
    # ── 1. Revoke mutation privileges from the application role ───────────
    # INSERT and SELECT remain so audit_service.log_event() keeps working
    # and read-side audit queries (admin UI, SOC 2 evidence export) still
    # function. UPDATE and DELETE are gone.
    op.execute(f"REVOKE UPDATE, DELETE ON TABLE audit_log FROM {APP_ROLE}")

    # ── 2. Trigger function — raises on any UPDATE/DELETE/TRUNCATE ────────
    # SECURITY DEFINER is intentionally NOT used: we want the trigger to
    # run as the invoking role so pg_audit / log_statement captures the
    # offending session. RAISE EXCEPTION aborts the enclosing transaction,
    # so a batched mutation cannot partially succeed.
    op.execute(
        """
        CREATE OR REPLACE FUNCTION audit_log_no_mutations()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
            RAISE EXCEPTION 'audit_log is append-only — modifications are not permitted'
                USING ERRCODE = 'insufficient_privilege';
        END;
        $$;
        """
    )

    # ── 3. Row-level trigger — blocks UPDATE and DELETE ───────────────────
    # BEFORE UPDATE OR DELETE FOR EACH ROW — fires once per targeted row
    # and blocks the operation before any write hits the heap or WAL.
    op.execute(
        """
        CREATE TRIGGER audit_log_block_mutations
        BEFORE UPDATE OR DELETE ON audit_log
        FOR EACH ROW
        EXECUTE FUNCTION audit_log_no_mutations();
        """
    )

    # ── 4. Statement-level trigger — blocks TRUNCATE ──────────────────────
    # TRUNCATE does not fire row-level triggers (no OLD/NEW rows exist),
    # so a separate statement-level trigger is required. This fires once
    # per TRUNCATE statement and aborts it before any rows are removed.
    op.execute(
        """
        CREATE TRIGGER audit_log_block_truncate
        BEFORE TRUNCATE ON audit_log
        FOR EACH STATEMENT
        EXECUTE FUNCTION audit_log_no_mutations();
        """
    )


def downgrade() -> None:
    # Reverse order: drop triggers first (depend on the function), then the
    # function, then restore privileges. Each step is IF EXISTS so a
    # partially-applied upgrade can still be rolled back cleanly.
    op.execute("DROP TRIGGER IF EXISTS audit_log_block_truncate ON audit_log")
    op.execute("DROP TRIGGER IF EXISTS audit_log_block_mutations ON audit_log")
    op.execute("DROP FUNCTION IF EXISTS audit_log_no_mutations()")
    op.execute(f"GRANT UPDATE, DELETE ON TABLE audit_log TO {APP_ROLE}")
