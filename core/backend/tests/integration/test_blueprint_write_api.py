"""Integration tests for the Blueprint write path (2C).

Exercises clone-on-use, blueprint create/update/delete, and the system-template
write guard against the real seeded Postgres. Uses the shared ``client`` +
``auth_override`` fixtures.

A file-local autouse fixture (a) seeds the fake user row so the ``user_id`` FK
on writes is satisfiable, and (b) deletes all user-owned blueprints after each
test (parts cascade) via its own short-lived NullPool session, restoring the
"system-templates-only" invariant the 2B read tests depend on.
"""

from __future__ import annotations

from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.pool import NullPool

from psitta.config import get_settings
from psitta.dependencies import get_current_user_id

pytestmark = pytest.mark.integration

_FAKE_USER_ID = UUID("00000000-0000-0000-0000-000000000001")
_NOVEL_ID = "5eed0001-0000-4000-8000-000000000001"


def _collect_ids(nodes) -> set:
    ids: set = set()
    for n in nodes:
        ids.add(n["id"])
        ids |= _collect_ids(n["children"])
    return ids


def _count_nodes(nodes) -> int:
    return sum(1 + _count_nodes(n["children"]) for n in nodes)


def _find(nodes, name):
    for n in nodes:
        if n["name"] == name:
            return n
    return None


@pytest_asyncio.fixture(autouse=True)
async def _fake_user_and_cleanup():
    """Seed the fake user (FK target for writes) and purge user blueprints after.

    Own NullPool engine, disposed on the test loop. The fake user row is left in
    place (harmless, reusable); only user-owned blueprints are removed so the
    seeded system templates remain the only blueprints between tests.
    """
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO users (id, external_id, email) "
                    "VALUES (:id, :ext, :email) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": _FAKE_USER_ID,
                    "ext": "itest-blueprint-user",
                    "email": "itest-blueprint@test.local",
                },
            )
        yield
    finally:
        async with engine.begin() as conn:
            await conn.execute(
                text("DELETE FROM blueprints WHERE user_id IS NOT NULL")
            )
        await engine.dispose()


class TestCloneBlueprint:
    @pytest.mark.asyncio
    async def test_clone_novel_template(self, client, auth_override):
        source = (await client.get(f"/api/v1/blueprints/{_NOVEL_ID}")).json()
        source_ids = _collect_ids(source["parts"])

        resp = await client.post(f"/api/v1/blueprints/{_NOVEL_ID}/clone/")
        assert resp.status_code == 201
        body = resp.json()

        assert body["id"] != _NOVEL_ID
        assert body["is_system"] is False
        assert body["source_template_id"] == _NOVEL_ID
        assert body["status"] == "Draft"

        parts = body["parts"]
        assert len(parts) == 5
        assert _count_nodes(parts) == 9
        front = _find(parts, "Front Matter")
        back = _find(parts, "Back Matter")
        assert front is not None and len(front["children"]) == 2
        assert back is not None and len(back["children"]) == 2

        # Deep copy: no cloned part id collides with a source part id.
        assert _collect_ids(parts).isdisjoint(source_ids)


class TestCreateUpdateDelete:
    @pytest.mark.asyncio
    async def test_create_empty_blueprint(self, client, auth_override):
        resp = await client.post(
            "/api/v1/blueprints/", json={"name": "My Book", "genre": "Novel"}
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["is_system"] is False

        got = await client.get(f"/api/v1/blueprints/{body['id']}")
        assert got.status_code == 200
        assert got.json()["parts"] == []

    @pytest.mark.asyncio
    async def test_update_name(self, client, auth_override):
        created = await client.post(
            "/api/v1/blueprints/", json={"name": "Before", "genre": "Memoir"}
        )
        bid = created.json()["id"]

        patched = await client.patch(
            f"/api/v1/blueprints/{bid}", json={"name": "After"}
        )
        assert patched.status_code == 200
        assert patched.json()["name"] == "After"

        got = await client.get(f"/api/v1/blueprints/{bid}")
        assert got.json()["name"] == "After"

    @pytest.mark.asyncio
    async def test_delete(self, client, auth_override):
        created = await client.post(
            "/api/v1/blueprints/", json={"name": "Doomed", "genre": "Biography"}
        )
        bid = created.json()["id"]

        deleted = await client.delete(f"/api/v1/blueprints/{bid}")
        assert deleted.status_code == 204

        got = await client.get(f"/api/v1/blueprints/{bid}")
        assert got.status_code == 404


class TestSystemTemplateGuard:
    @pytest.mark.asyncio
    async def test_patch_system_template_is_403(self, client, auth_override):
        resp = await client.patch(
            f"/api/v1/blueprints/{_NOVEL_ID}", json={"name": "hijack"}
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_delete_system_template_is_403(self, client, auth_override):
        resp = await client.delete(f"/api/v1/blueprints/{_NOVEL_ID}")
        assert resp.status_code == 403


class TestOwnershipIsolation:
    @pytest.mark.asyncio
    async def test_other_users_blueprint_is_404(self, app, client, auth_override):
        created = await client.post(
            "/api/v1/blueprints/", json={"name": "Mine", "genre": "Novel"}
        )
        assert created.status_code == 201
        bid = created.json()["id"]

        # Act as a different user; the blueprint must now be invisible (404).
        other = uuid4()
        app.dependency_overrides[get_current_user_id] = lambda: other

        patched = await client.patch(
            f"/api/v1/blueprints/{bid}", json={"name": "stolen"}
        )
        assert patched.status_code == 404

        deleted = await client.delete(f"/api/v1/blueprints/{bid}")
        assert deleted.status_code == 404
