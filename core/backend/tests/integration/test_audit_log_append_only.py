"""SOC 2 CC7.2 evidence — audit_log append-only enforcement.

These tests exercise the real Postgres database (they cannot run against a
mock) and verify that the 011 migration's three-layer tamper-evidence
actually blocks UPDATE, DELETE, and TRUNCATE against audit_log.

Run order matters: each test inserts a fresh sentinel row (INSERT must still
work), then asserts the mutation raises, then confirms the row is still
present and unchanged. The final assertion — that the row survives — is the
actual SOC 2 evidence; the raised exception alone is not sufficient, because
a partial write followed by rollback would also raise but leave damage
behind in a different failure mode.

Marked `integration` — pytest must be invoked against a DB with migration
011 applied. In CI this runs after `alembic upgrade head` in the test
service container.
"""

from __future__ import annotations

from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from psitta.config import get_settings


pytestmark = pytest.mark.integration


EXPECTED_MESSAGE = "audit_log is append-only"


@pytest_asyncio.fixture
async def db() -> AsyncSession:
    """Async session bound to the real test DB, as the app role (`psitta`).

    We deliberately connect as the application role — not as a superuser —
    because the first layer of defense (REVOKE UPDATE, DELETE) only applies
    to that role. Testing as postgres/superuser would falsely pass the
    privilege check while still exercising the triggers.
    """
    settings = get_settings()
    engine = create_async_engine(settings.database_url, future=True)
    Session = async_sessionmaker(engine, expire_on_commit=False)
    async with Session() as session:
        yield session
    await engine.dispose()


async def _insert_sentinel(db: AsyncSession) -> str:
    """Insert a throwaway audit row and return its id.

    INSERT must still succeed — if this fails the migration is broken and
    every subsequent assertion is meaningless.
    """
    row_id = str(uuid4())
    await db.execute(
        text(
            """
            INSERT INTO audit_log (id, user_id, action, resource_type, resource_id, ip_address)
            VALUES (:id, NULL, 'test.soc2_evidence', 'test', NULL, '127.0.0.1')
            """
        ),
        {"id": row_id},
    )
    await db.commit()
    return row_id


async def _row_exists(db: AsyncSession, row_id: str) -> bool:
    result = await db.execute(
        text("SELECT 1 FROM audit_log WHERE id = :id"),
        {"id": row_id},
    )
    return result.scalar() is not None


class TestAuditLogAppendOnly:
    """SOC 2 CC7.2 — audit_log is append-only at the database layer."""

    @pytest.mark.asyncio
    async def test_insert_still_works(self, db: AsyncSession):
        """INSERT must remain functional — the app writes audit records."""
        row_id = await _insert_sentinel(db)
        assert await _row_exists(db, row_id)

    @pytest.mark.asyncio
    async def test_update_is_blocked(self, db: AsyncSession):
        """UPDATE must raise and leave the target row byte-identical."""
        row_id = await _insert_sentinel(db)

        with pytest.raises(DBAPIError) as excinfo:
            await db.execute(
                text("UPDATE audit_log SET action = 'tampered' WHERE id = :id"),
                {"id": row_id},
            )
            await db.commit()
        await db.rollback()

        assert EXPECTED_MESSAGE in str(excinfo.value)

        result = await db.execute(
            text("SELECT action FROM audit_log WHERE id = :id"),
            {"id": row_id},
        )
        assert result.scalar() == "test.soc2_evidence"

    @pytest.mark.asyncio
    async def test_delete_is_blocked(self, db: AsyncSession):
        """DELETE must raise and leave the target row in place."""
        row_id = await _insert_sentinel(db)

        with pytest.raises(DBAPIError) as excinfo:
            await db.execute(
                text("DELETE FROM audit_log WHERE id = :id"),
                {"id": row_id},
            )
            await db.commit()
        await db.rollback()

        assert EXPECTED_MESSAGE in str(excinfo.value)
        assert await _row_exists(db, row_id)

    @pytest.mark.asyncio
    async def test_truncate_is_blocked(self, db: AsyncSession):
        """TRUNCATE must raise and leave every row in place.

        Row-level triggers do NOT fire on TRUNCATE — this test is the
        evidence for layer 3 (the BEFORE TRUNCATE FOR EACH STATEMENT
        trigger). Without it, TRUNCATE would silently wipe the table.
        """
        row_id = await _insert_sentinel(db)

        with pytest.raises(DBAPIError) as excinfo:
            await db.execute(text("TRUNCATE TABLE audit_log"))
            await db.commit()
        await db.rollback()

        assert EXPECTED_MESSAGE in str(excinfo.value)
        assert await _row_exists(db, row_id)

    @pytest.mark.asyncio
    async def test_privilege_revocation_is_in_place(self, db: AsyncSession):
        """Layer-1 evidence — the app role has no UPDATE/DELETE grants.

        This queries information_schema directly so a SOC 2 auditor can
        see the grant state as a standalone assertion, not just as a
        side-effect of the trigger tests.
        """
        result = await db.execute(
            text(
                """
                SELECT privilege_type
                FROM information_schema.role_table_grants
                WHERE grantee = 'psitta'
                  AND table_name = 'audit_log'
                ORDER BY privilege_type
                """
            )
        )
        grants = {row[0] for row in result.all()}
        assert "UPDATE" not in grants
        assert "DELETE" not in grants
        assert "INSERT" in grants  # still required for log_event()
        assert "SELECT" in grants  # still required for audit reads
