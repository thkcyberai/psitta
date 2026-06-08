"""Integration tests for the Blueprint part write path (2D).

Exercises part create (first / between / end), reorder, nest (incl.
append-on-reparent), cycle prevention, cross-blueprint parent rejection, the
DB-cascade delete, and the auth matrix (system 403, cross-user 404, part not in
blueprint 404) against the real seeded Postgres via the shared ``client`` +
``auth_override`` fixtures.

A file-local autouse fixture (a) seeds the fake user row so the ``user_id`` FK on
blueprint writes is satisfiable, and (b) deletes all user-owned blueprints after
each test (parts cascade) via its own short-lived NullPool session, restoring the
"system-templates-only" invariant the 2B read tests depend on. Mirrors
``test_blueprint_write_api.py``.
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
                    "ext": "itest-blueprint-part-user",
                    "email": "itest-blueprint-part@test.local",
                },
            )
        yield
    finally:
        async with engine.begin() as conn:
            await conn.execute(
                text("DELETE FROM blueprints WHERE user_id IS NOT NULL")
            )
        await engine.dispose()


async def _new_blueprint(client, name="Parts BP", genre="Novel") -> str:
    resp = await client.post(
        "/api/v1/blueprints/", json={"name": name, "genre": genre}
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _add_part(client, bid, name, parent_part_id=None, after_part_id=None):
    body: dict = {"name": name}
    if parent_part_id is not None:
        body["parent_part_id"] = parent_part_id
    if after_part_id is not None:
        body["after_part_id"] = after_part_id
    return await client.post(f"/api/v1/blueprints/{bid}/parts/", json=body)


class TestCreatePart:
    @pytest.mark.asyncio
    async def test_create_first_between_end(self, client, auth_override):
        bid = await _new_blueprint(client)

        # Empty group ⇒ _GAP (1000).
        a = (await _add_part(client, bid, "A")).json()
        assert a["sort_order"] == 1000.0
        assert a["parent_part_id"] is None

        # After the last sibling ⇒ last + _GAP.
        c = (await _add_part(client, bid, "C", after_part_id=a["id"])).json()
        assert c["sort_order"] == 2000.0

        # Between A and C ⇒ midpoint.
        b = (await _add_part(client, bid, "B", after_part_id=a["id"])).json()
        assert b["sort_order"] == 1500.0

        # after_part_id absent ⇒ first child (front of the group): first / 2.
        first = (await _add_part(client, bid, "First")).json()
        assert first["sort_order"] == 500.0

        tree = (await client.get(f"/api/v1/blueprints/{bid}")).json()["parts"]
        assert [n["name"] for n in tree] == ["First", "A", "B", "C"]


class TestReorder:
    @pytest.mark.asyncio
    async def test_reorder_within_parent(self, client, auth_override):
        bid = await _new_blueprint(client)
        a = (await _add_part(client, bid, "A")).json()
        b = (await _add_part(client, bid, "B", after_part_id=a["id"])).json()
        c = (await _add_part(client, bid, "C", after_part_id=b["id"])).json()
        assert [a["sort_order"], b["sort_order"], c["sort_order"]] == [
            1000.0,
            2000.0,
            3000.0,
        ]

        moved = await client.patch(
            f"/api/v1/blueprints/{bid}/parts/{c['id']}",
            json={"after_part_id": a["id"]},
        )
        assert moved.status_code == 200
        assert moved.json()["sort_order"] == 1500.0
        assert moved.json()["parent_part_id"] is None

        tree = (await client.get(f"/api/v1/blueprints/{bid}")).json()["parts"]
        assert [n["name"] for n in tree] == ["A", "C", "B"]


class TestNest:
    @pytest.mark.asyncio
    async def test_create_child_and_reparent_append(self, client, auth_override):
        bid = await _new_blueprint(client)
        p = (await _add_part(client, bid, "Parent")).json()

        # A child created directly under Parent: first child of an empty group.
        ch = (await _add_part(client, bid, "Child", parent_part_id=p["id"])).json()
        assert ch["parent_part_id"] == p["id"]
        assert ch["sort_order"] == 1000.0

        # A second root, then reparent it under Parent with NO after_part_id ⇒
        # append to the end of Parent's children (Child at 1000 ⇒ 2000).
        q = (await _add_part(client, bid, "Q")).json()
        moved = await client.patch(
            f"/api/v1/blueprints/{bid}/parts/{q['id']}",
            json={"parent_part_id": p["id"]},
        )
        assert moved.status_code == 200
        assert moved.json()["parent_part_id"] == p["id"]
        assert moved.json()["sort_order"] == 2000.0

        tree = (await client.get(f"/api/v1/blueprints/{bid}")).json()["parts"]
        assert [n["name"] for n in tree] == ["Parent"]
        assert [k["name"] for k in tree[0]["children"]] == ["Child", "Q"]

    @pytest.mark.asyncio
    async def test_move_to_root(self, client, auth_override):
        bid = await _new_blueprint(client)
        p = (await _add_part(client, bid, "Parent")).json()
        ch = (await _add_part(client, bid, "Child", parent_part_id=p["id"])).json()

        # present-and-null parent_part_id ⇒ move to root.
        moved = await client.patch(
            f"/api/v1/blueprints/{bid}/parts/{ch['id']}",
            json={"parent_part_id": None},
        )
        assert moved.status_code == 200
        assert moved.json()["parent_part_id"] is None

        tree = (await client.get(f"/api/v1/blueprints/{bid}")).json()["parts"]
        assert {n["name"] for n in tree} == {"Parent", "Child"}


class TestValidation:
    @pytest.mark.asyncio
    async def test_cross_blueprint_parent_is_400(self, client, auth_override):
        bid1 = await _new_blueprint(client, name="BP1")
        bid2 = await _new_blueprint(client, name="BP2")
        foreign = (await _add_part(client, bid2, "Foreign")).json()

        resp = await _add_part(
            client, bid1, "Child", parent_part_id=foreign["id"]
        )
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_move_under_own_descendant_is_400(self, client, auth_override):
        bid = await _new_blueprint(client)
        p = (await _add_part(client, bid, "P")).json()
        c = (await _add_part(client, bid, "C", parent_part_id=p["id"])).json()
        g = (await _add_part(client, bid, "G", parent_part_id=c["id"])).json()

        # Move P under its own grandchild G ⇒ cycle ⇒ 400.
        resp = await client.patch(
            f"/api/v1/blueprints/{bid}/parts/{p['id']}",
            json={"parent_part_id": g["id"]},
        )
        assert resp.status_code == 400

        # A part cannot be its own parent.
        resp_self = await client.patch(
            f"/api/v1/blueprints/{bid}/parts/{p['id']}",
            json={"parent_part_id": p["id"]},
        )
        assert resp_self.status_code == 400

    @pytest.mark.asyncio
    async def test_bad_after_part_id_is_400(self, client, auth_override):
        bid = await _new_blueprint(client)
        await _add_part(client, bid, "A")
        # after_part_id references a non-existent (non-sibling) id.
        resp = await _add_part(client, bid, "B", after_part_id=str(uuid4()))
        assert resp.status_code == 400


class TestDeleteCascade:
    @pytest.mark.asyncio
    async def test_delete_cascades_subtree(self, client, auth_override):
        bid = await _new_blueprint(client)
        p = (await _add_part(client, bid, "P")).json()
        c = (await _add_part(client, bid, "C", parent_part_id=p["id"])).json()
        g = (await _add_part(client, bid, "G", parent_part_id=c["id"])).json()
        await _add_part(client, bid, "Survivor")

        deleted = await client.delete(
            f"/api/v1/blueprints/{bid}/parts/{p['id']}"
        )
        assert deleted.status_code == 204

        tree = (await client.get(f"/api/v1/blueprints/{bid}")).json()["parts"]
        assert {n["name"] for n in tree} == {"Survivor"}

        # Child and grandchild cascaded away ⇒ now 404.
        assert (
            await client.patch(
                f"/api/v1/blueprints/{bid}/parts/{c['id']}", json={"name": "x"}
            )
        ).status_code == 404
        assert (
            await client.delete(f"/api/v1/blueprints/{bid}/parts/{g['id']}")
        ).status_code == 404


class TestSystemTemplateGuard:
    @pytest.mark.asyncio
    async def test_create_part_on_system_is_403(self, client, auth_override):
        resp = await _add_part(client, _NOVEL_ID, "hijack")
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_patch_part_on_system_is_403(self, client, auth_override):
        # The system guard fires before the part is even loaded.
        resp = await client.patch(
            f"/api/v1/blueprints/{_NOVEL_ID}/parts/{uuid4()}",
            json={"name": "x"},
        )
        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_delete_part_on_system_is_403(self, client, auth_override):
        resp = await client.delete(
            f"/api/v1/blueprints/{_NOVEL_ID}/parts/{uuid4()}"
        )
        assert resp.status_code == 403


class TestOwnershipIsolation:
    @pytest.mark.asyncio
    async def test_other_users_part_is_404(self, app, client, auth_override):
        bid = await _new_blueprint(client)
        p = (await _add_part(client, bid, "Mine")).json()

        other = uuid4()
        app.dependency_overrides[get_current_user_id] = lambda: other

        assert (
            await client.post(
                f"/api/v1/blueprints/{bid}/parts/", json={"name": "x"}
            )
        ).status_code == 404
        assert (
            await client.patch(
                f"/api/v1/blueprints/{bid}/parts/{p['id']}", json={"name": "x"}
            )
        ).status_code == 404
        assert (
            await client.delete(f"/api/v1/blueprints/{bid}/parts/{p['id']}")
        ).status_code == 404


class TestPartNotInBlueprint:
    @pytest.mark.asyncio
    async def test_part_from_another_blueprint_is_404(self, client, auth_override):
        bid1 = await _new_blueprint(client, name="BP1")
        bid2 = await _new_blueprint(client, name="BP2")
        p = (await _add_part(client, bid1, "P1")).json()

        # Both blueprints are owned by the caller, but the part is not in bid2.
        assert (
            await client.patch(
                f"/api/v1/blueprints/{bid2}/parts/{p['id']}", json={"name": "x"}
            )
        ).status_code == 404
        assert (
            await client.delete(f"/api/v1/blueprints/{bid2}/parts/{p['id']}")
        ).status_code == 404

        # An unknown part id under an owned blueprint is also 404.
        assert (
            await client.delete(f"/api/v1/blueprints/{bid1}/parts/{uuid4()}")
        ).status_code == 404
