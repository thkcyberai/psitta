"""Integration tests for the project ↔ blueprint adoption path (2E).

Exercises adopt (auto-primary on first), non-primary second adopt, adopt-as-
primary swap, PATCH change/clear primary, un-adopt (plain link removal, no auto-
promotion), and the full auth/validation matrix (duplicate 409, system 400,
foreign blueprint 404, absent blueprint 404, project not owned 404, non-adopted
PATCH/DELETE 404) against the real seeded Postgres via the shared ``client`` +
``auth_override`` fixtures.

A file-local autouse fixture seeds the fake user AND a project owned by that
user (the adopt target), then deletes all user-owned blueprints (project_blueprints
cascade) and the test project after each test — restoring the system-templates-
only invariant the 2B read tests depend on. Mirrors ``test_blueprint_write_api``.
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
_OTHER_USER_ID = UUID("00000000-0000-0000-0000-0000000000ff")
_PROJECT_ID = "9b1d0001-0000-4000-8000-000000000001"
_NOVEL_ID = "5eed0001-0000-4000-8000-000000000001"


@pytest_asyncio.fixture(autouse=True)
async def _fake_user_project_and_cleanup():
    """Seed the fake user + an owned project; purge user blueprints + the project
    afterwards. Own NullPool engine, disposed on the test loop."""
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
                    "ext": "itest-proj-bp-user",
                    "email": "itest-proj-bp@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO projects (id, user_id, name) "
                    "VALUES (:id, :uid, :name) ON CONFLICT (id) DO NOTHING"
                ),
                {"id": _PROJECT_ID, "uid": _FAKE_USER_ID, "name": "2E Project"},
            )
        yield
    finally:
        async with engine.begin() as conn:
            # Deleting user blueprints cascades their project_blueprints rows;
            # deleting the project cascades any remaining adoptions.
            await conn.execute(
                text("DELETE FROM blueprints WHERE user_id IS NOT NULL")
            )
            await conn.execute(
                text("DELETE FROM projects WHERE id = :id"), {"id": _PROJECT_ID}
            )
        await engine.dispose()


async def _new_blueprint(client, name="BP", genre="Novel") -> str:
    resp = await client.post(
        "/api/v1/blueprints/", json={"name": name, "genre": genre}
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _adopt(client, bid, is_primary=None):
    body: dict = {"blueprint_id": bid}
    if is_primary is not None:
        body["is_primary"] = is_primary
    return await client.post(
        f"/api/v1/projects/{_PROJECT_ID}/blueprints/", json=body
    )


async def _list(client) -> list[dict]:
    resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/blueprints/")
    assert resp.status_code == 200
    return resp.json()


async def _seed_foreign_blueprint() -> str:
    """Insert a blueprint owned by a DIFFERENT user (for the foreign 404 case)."""
    bid = str(uuid4())
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO users (id, external_id, email) "
                    "VALUES (:id, :ext, :email) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": _OTHER_USER_ID,
                    "ext": "itest-proj-bp-other",
                    "email": "itest-proj-bp-other@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO blueprints "
                    "(id, user_id, is_system, name, genre, status) "
                    "VALUES (:id, :uid, false, 'Foreign', 'Novel', 'Draft')"
                ),
                {"id": bid, "uid": _OTHER_USER_ID},
            )
    finally:
        await engine.dispose()
    return bid


class TestAdoptAndPrimary:
    @pytest.mark.asyncio
    async def test_first_adopt_is_primary(self, client, auth_override):
        bid = await _new_blueprint(client, name="Solo")
        resp = await _adopt(client, bid)
        assert resp.status_code == 201
        assert resp.json()["is_primary"] is True
        assert resp.json()["id"] == bid

        items = await _list(client)
        assert [i["id"] for i in items] == [bid]
        assert items[0]["is_primary"] is True

    @pytest.mark.asyncio
    async def test_second_adopt_is_not_primary(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        b2 = await _new_blueprint(client, name="Two")
        assert (await _adopt(client, b1)).json()["is_primary"] is True
        assert (await _adopt(client, b2)).json()["is_primary"] is False

        items = await _list(client)
        # Primary first, then by adoption time.
        assert [i["id"] for i in items] == [b1, b2]
        assert items[0]["is_primary"] is True
        assert items[1]["is_primary"] is False

    @pytest.mark.asyncio
    async def test_adopt_as_primary_swaps(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        b2 = await _new_blueprint(client, name="Two")
        await _adopt(client, b1)  # auto-primary
        resp = await _adopt(client, b2, is_primary=True)
        assert resp.status_code == 201
        assert resp.json()["is_primary"] is True

        by_id = {i["id"]: i for i in await _list(client)}
        assert by_id[b2]["is_primary"] is True
        assert by_id[b1]["is_primary"] is False

    @pytest.mark.asyncio
    async def test_patch_change_primary_swaps(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        b2 = await _new_blueprint(client, name="Two")
        await _adopt(client, b1)  # primary
        await _adopt(client, b2)  # not primary

        resp = await client.patch(
            f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b2}",
            json={"is_primary": True},
        )
        assert resp.status_code == 200
        assert resp.json()["is_primary"] is True

        by_id = {i["id"]: i for i in await _list(client)}
        assert by_id[b2]["is_primary"] is True
        assert by_id[b1]["is_primary"] is False

    @pytest.mark.asyncio
    async def test_patch_clear_primary(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        await _adopt(client, b1)  # primary

        resp = await client.patch(
            f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}",
            json={"is_primary": False},
        )
        assert resp.status_code == 200
        assert resp.json()["is_primary"] is False

        items = await _list(client)
        assert all(i["is_primary"] is False for i in items)


class TestUnadopt:
    @pytest.mark.asyncio
    async def test_unadopt_is_link_removal(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        await _adopt(client, b1)

        deleted = await client.delete(
            f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}"
        )
        assert deleted.status_code == 204

        assert await _list(client) == []
        # The blueprint itself is untouched by un-adoption.
        assert (await client.get(f"/api/v1/blueprints/{b1}")).status_code == 200

    @pytest.mark.asyncio
    async def test_unadopt_primary_leaves_no_primary(self, client, auth_override):
        b1 = await _new_blueprint(client, name="One")
        b2 = await _new_blueprint(client, name="Two")
        await _adopt(client, b1)  # primary
        await _adopt(client, b2)  # not primary

        deleted = await client.delete(
            f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}"
        )
        assert deleted.status_code == 204

        items = await _list(client)
        # b2 remains and is NOT auto-promoted.
        assert [i["id"] for i in items] == [b2]
        assert items[0]["is_primary"] is False


class TestValidationMatrix:
    @pytest.mark.asyncio
    async def test_duplicate_adopt_is_409(self, client, auth_override):
        b1 = await _new_blueprint(client)
        assert (await _adopt(client, b1)).status_code == 201
        assert (await _adopt(client, b1)).status_code == 409

    @pytest.mark.asyncio
    async def test_adopt_system_template_is_400(self, client, auth_override):
        resp = await _adopt(client, _NOVEL_ID)
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_adopt_foreign_blueprint_is_404(self, client, auth_override):
        foreign = await _seed_foreign_blueprint()
        resp = await _adopt(client, foreign)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_adopt_absent_blueprint_is_404(self, client, auth_override):
        resp = await _adopt(client, str(uuid4()))
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_patch_and_delete_non_adopted_is_404(self, client, auth_override):
        b1 = await _new_blueprint(client)  # created, never adopted
        assert (
            await client.patch(
                f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}",
                json={"is_primary": True},
            )
        ).status_code == 404
        assert (
            await client.delete(
                f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}"
            )
        ).status_code == 404

    @pytest.mark.asyncio
    async def test_project_not_owned_is_404(self, app, client, auth_override):
        b1 = await _new_blueprint(client)

        other = uuid4()
        app.dependency_overrides[get_current_user_id] = lambda: other

        # The project is owned by the fake user, so every op 404s for `other`.
        assert (
            await client.get(f"/api/v1/projects/{_PROJECT_ID}/blueprints/")
        ).status_code == 404
        assert (await _adopt(client, str(b1))).status_code == 404
        assert (
            await client.patch(
                f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}",
                json={"is_primary": True},
            )
        ).status_code == 404
        assert (
            await client.delete(
                f"/api/v1/projects/{_PROJECT_ID}/blueprints/{b1}"
            )
        ).status_code == 404
