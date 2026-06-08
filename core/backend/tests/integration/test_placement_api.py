"""Integration tests for document placement with auto-adopt (2F).

Exercises the ``/documents/{document_id}/placement`` surface against the real
seeded Postgres via the shared ``client`` + ``auth_override`` fixtures:

  - place (201) auto-adopts the part's blueprint into the document's project and,
    when the project had no adoptions, makes it primary;
  - placing a second document into a SECOND blueprint adopts it non-primary;
  - re-placing a document is a move (200), not a duplicate;
  - GET returns the current placement (or 404 when unplaced);
  - DELETE un-places (204) and NEVER auto-un-adopts the blueprint;
  - the full auth/validation matrix (no-project 422, soft-deleted 404, foreign
    404, absent part 404, system-template part 400, foreign-blueprint part 404,
    bad role 422).

A file-local autouse fixture seeds the fake user, an owned project, and four
documents (two placeable in the project, one with no project, one soft-deleted),
then purges placements + user blueprints + the seeded docs + the project after
each test — restoring the system-templates-only invariant the 2B read tests rely
on. Mirrors ``test_project_blueprint_api``.
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
_PROJECT_ID = "9b1d0002-0000-4000-8000-000000000001"

_DOC1_ID = "d0c00001-0000-4000-8000-000000000001"
_DOC2_ID = "d0c00002-0000-4000-8000-000000000002"
_DOC_NOPROJ_ID = "d0c00003-0000-4000-8000-000000000003"
_DOC_DELETED_ID = "d0c00004-0000-4000-8000-000000000004"

# Stable seeded system template (migration 022) — used for the system-part case.
_NOVEL_ID = "5eed0001-0000-4000-8000-000000000001"

_SEEDED_DOC_IDS = [_DOC1_ID, _DOC2_ID, _DOC_NOPROJ_ID, _DOC_DELETED_ID]


@pytest_asyncio.fixture(autouse=True)
async def _seed_and_cleanup():
    """Seed the fake user + an owned project + four documents; purge placements,
    user blueprints, the seeded docs, and the project afterwards. Own NullPool
    engine, disposed on the test loop."""
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO users (id, external_id, email) "
                    "VALUES (:id, :ext, :email) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": str(_FAKE_USER_ID),
                    "ext": "itest-placement-user",
                    "email": "itest-placement@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO projects (id, user_id, name) "
                    "VALUES (:id, :uid, :name) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": _PROJECT_ID,
                    "uid": str(_FAKE_USER_ID),
                    "name": "2F Project",
                },
            )
            # Two placeable docs in the project, one with no project, one deleted.
            for doc_id, project_id, status in (
                (_DOC1_ID, _PROJECT_ID, "ready"),
                (_DOC2_ID, _PROJECT_ID, "ready"),
                (_DOC_NOPROJ_ID, None, "ready"),
                (_DOC_DELETED_ID, _PROJECT_ID, "deleted"),
            ):
                await conn.execute(
                    text(
                        "INSERT INTO documents "
                        "(id, user_id, project_id, title, source_type, status, "
                        " storage_key) "
                        "VALUES (:id, :uid, :pid, :title, 'docx', :status, '') "
                        "ON CONFLICT (id) DO NOTHING"
                    ),
                    {
                        "id": doc_id,
                        "uid": str(_FAKE_USER_ID),
                        "pid": project_id,
                        "title": f"Doc {doc_id[-1]}",
                        "status": status,
                    },
                )
        yield
    finally:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "DELETE FROM part_documents WHERE document_id = ANY(:ids)"
                ),
                {"ids": _SEEDED_DOC_IDS},
            )
            # Deleting user blueprints cascades parts → placements AND adoptions.
            await conn.execute(
                text("DELETE FROM blueprints WHERE user_id IS NOT NULL")
            )
            await conn.execute(
                text("DELETE FROM documents WHERE id = ANY(:ids)"),
                {"ids": _SEEDED_DOC_IDS},
            )
            await conn.execute(
                text("DELETE FROM projects WHERE id = :id"), {"id": _PROJECT_ID}
            )
        await engine.dispose()


# ── Helpers ──────────────────────────────────────────────────────────────────


async def _new_blueprint(client, name="BP", genre="Novel") -> str:
    resp = await client.post(
        "/api/v1/blueprints/", json={"name": name, "genre": genre}
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _new_part(client, blueprint_id, name="Chapter") -> str:
    resp = await client.post(
        f"/api/v1/blueprints/{blueprint_id}/parts/", json={"name": name}
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _place(client, document_id, part_id, role=None):
    body: dict = {"part_id": part_id}
    if role is not None:
        body["role"] = role
    return await client.put(
        f"/api/v1/documents/{document_id}/placement", json=body
    )


async def _project_blueprints(client) -> list[dict]:
    resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/blueprints/")
    assert resp.status_code == 200
    return resp.json()


async def _seed_foreign_part() -> str:
    """Insert a blueprint + part owned by a DIFFERENT user; return the part id."""
    bid = str(uuid4())
    part_id = str(uuid4())
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO users (id, external_id, email) "
                    "VALUES (:id, :ext, :email) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": str(_OTHER_USER_ID),
                    "ext": "itest-placement-other",
                    "email": "itest-placement-other@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO blueprints "
                    "(id, user_id, is_system, name, genre, status) "
                    "VALUES (:id, :uid, false, 'Foreign', 'Novel', 'Draft')"
                ),
                {"id": bid, "uid": str(_OTHER_USER_ID)},
            )
            await conn.execute(
                text(
                    "INSERT INTO blueprint_parts "
                    "(id, blueprint_id, name, sort_order) "
                    "VALUES (:id, :bid, 'Foreign Part', 1000)"
                ),
                {"id": part_id, "bid": bid},
            )
    finally:
        await engine.dispose()
    return part_id


async def _seed_foreign_document() -> str:
    """Insert a document owned by a DIFFERENT user; return its id."""
    doc_id = str(uuid4())
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "INSERT INTO users (id, external_id, email) "
                    "VALUES (:id, :ext, :email) ON CONFLICT (id) DO NOTHING"
                ),
                {
                    "id": str(_OTHER_USER_ID),
                    "ext": "itest-placement-other",
                    "email": "itest-placement-other@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO documents "
                    "(id, user_id, title, source_type, status, storage_key) "
                    "VALUES (:id, :uid, 'Foreign Doc', 'docx', 'ready', '')"
                ),
                {"id": doc_id, "uid": str(_OTHER_USER_ID)},
            )
    finally:
        # The foreign doc shares _OTHER_USER_ID; the foreign-user row is left in
        # place (harmless) — no cascade touches the fake user's data.
        await engine.dispose()
    return doc_id


# ── Place + auto-adopt ────────────────────────────────────────────────────────


class TestPlaceAndAutoAdopt:
    @pytest.mark.asyncio
    async def test_place_creates_and_auto_adopts_primary(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)

        resp = await _place(client, _DOC1_ID, part_id)
        assert resp.status_code == 201
        body = resp.json()
        assert body["document_id"] == _DOC1_ID
        assert body["part_id"] == part_id
        assert body["blueprint_id"] == bid
        assert body["role"] == "Main Content"

        # The part's blueprint was adopted into the project AND made primary
        # (first adoption), in the same transaction.
        adopted = await _project_blueprints(client)
        assert [a["id"] for a in adopted] == [bid]
        assert adopted[0]["is_primary"] is True

    @pytest.mark.asyncio
    async def test_place_with_explicit_role(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)

        resp = await _place(client, _DOC1_ID, part_id, role="Research")
        assert resp.status_code == 201
        assert resp.json()["role"] == "Research"

    @pytest.mark.asyncio
    async def test_second_blueprint_adopts_non_primary(self, client, auth_override):
        a = await _new_blueprint(client, name="A")
        a_part = await _new_part(client, a)
        b = await _new_blueprint(client, name="B")
        b_part = await _new_part(client, b)

        assert (await _place(client, _DOC1_ID, a_part)).status_code == 201
        assert (await _place(client, _DOC2_ID, b_part)).status_code == 201

        by_id = {x["id"]: x for x in await _project_blueprints(client)}
        assert by_id[a]["is_primary"] is True  # first adoption stays primary
        assert by_id[b]["is_primary"] is False

    @pytest.mark.asyncio
    async def test_replace_is_a_move_not_a_duplicate(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part1 = await _new_part(client, bid, name="One")
        part2 = await _new_part(client, bid, name="Two")

        first = await _place(client, _DOC1_ID, part1)
        assert first.status_code == 201
        placement_id = first.json()["id"]

        moved = await _place(client, _DOC1_ID, part2, role="Notes")
        assert moved.status_code == 200  # moved, not created
        assert moved.json()["id"] == placement_id  # same single placement row
        assert moved.json()["part_id"] == part2
        assert moved.json()["role"] == "Notes"

        # Still adopted exactly once (idempotent auto-adopt on the same blueprint).
        assert len(await _project_blueprints(client)) == 1

    @pytest.mark.asyncio
    async def test_move_across_blueprints_keeps_old_adoption(
        self, client, auth_override
    ):
        a = await _new_blueprint(client, name="A")
        a_part = await _new_part(client, a)
        b = await _new_blueprint(client, name="B")
        b_part = await _new_part(client, b)

        assert (await _place(client, _DOC1_ID, a_part)).status_code == 201
        assert (await _place(client, _DOC1_ID, b_part)).status_code == 200

        # Both blueprints remain adopted — moving out never auto-un-adopts.
        ids = {x["id"] for x in await _project_blueprints(client)}
        assert ids == {a, b}


# ── Read + un-place ────────────────────────────────────────────────────────────


class TestGetAndDelete:
    @pytest.mark.asyncio
    async def test_get_returns_current_placement(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        await _place(client, _DOC1_ID, part_id, role="Reference Material")

        resp = await client.get(f"/api/v1/documents/{_DOC1_ID}/placement")
        assert resp.status_code == 200
        body = resp.json()
        assert body["part_id"] == part_id
        assert body["blueprint_id"] == bid
        assert body["role"] == "Reference Material"

    @pytest.mark.asyncio
    async def test_get_unplaced_is_404(self, client, auth_override):
        resp = await client.get(f"/api/v1/documents/{_DOC1_ID}/placement")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_unplaces_and_keeps_adoption(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        await _place(client, _DOC1_ID, part_id)

        deleted = await client.delete(f"/api/v1/documents/{_DOC1_ID}/placement")
        assert deleted.status_code == 204

        # The placement is gone, but the blueprint adoption stays (explicit only).
        assert (
            await client.get(f"/api/v1/documents/{_DOC1_ID}/placement")
        ).status_code == 404
        assert [a["id"] for a in await _project_blueprints(client)] == [bid]

    @pytest.mark.asyncio
    async def test_delete_unplaced_is_404(self, client, auth_override):
        resp = await client.delete(f"/api/v1/documents/{_DOC1_ID}/placement")
        assert resp.status_code == 404


# ── Auth / validation matrix ────────────────────────────────────────────────────


class TestValidationMatrix:
    @pytest.mark.asyncio
    async def test_no_project_document_is_422(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        resp = await _place(client, _DOC_NOPROJ_ID, part_id)
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_soft_deleted_document_is_404(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        resp = await _place(client, _DOC_DELETED_ID, part_id)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_foreign_document_is_404(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        foreign_doc = await _seed_foreign_document()
        resp = await _place(client, foreign_doc, part_id)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_absent_document_is_404(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        resp = await _place(client, str(uuid4()), part_id)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_absent_part_is_404(self, client, auth_override):
        resp = await _place(client, _DOC1_ID, str(uuid4()))
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_system_template_part_is_400(self, client, auth_override):
        detail = (await client.get(f"/api/v1/blueprints/{_NOVEL_ID}")).json()
        sys_part_id = detail["parts"][0]["id"]
        resp = await _place(client, _DOC1_ID, sys_part_id)
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_foreign_blueprint_part_is_404(self, client, auth_override):
        foreign_part = await _seed_foreign_part()
        resp = await _place(client, _DOC1_ID, foreign_part)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_bad_role_is_422(self, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        resp = await _place(client, _DOC1_ID, part_id, role="Bogus")
        assert resp.status_code == 422

    @pytest.mark.asyncio
    async def test_placement_is_user_scoped_404(self, app, client, auth_override):
        bid = await _new_blueprint(client, name="A")
        part_id = await _new_part(client, bid)
        await _place(client, _DOC1_ID, part_id)

        other = uuid4()
        app.dependency_overrides[get_current_user_id] = lambda: other
        # _DOC1_ID is owned by the fake user → every op 404s for `other`.
        assert (
            await client.get(f"/api/v1/documents/{_DOC1_ID}/placement")
        ).status_code == 404
        assert (await _place(client, _DOC1_ID, part_id)).status_code == 404
        assert (
            await client.delete(f"/api/v1/documents/{_DOC1_ID}/placement")
        ).status_code == 404
