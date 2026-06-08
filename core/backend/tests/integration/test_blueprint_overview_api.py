"""Integration tests for the derived blueprint overview (Phase 2G).

Exercises ``GET /projects/{project_id}/blueprint-overview/`` end-to-end against
the real seeded Postgres via the shared ``client`` + ``auth_override`` fixtures.

Builds a nested user blueprint and places documents to produce all three
readiness states, then asserts the derived counts (excluding a soft-deleted
doc whose placement row survives), leaf-aware readiness, per-blueprint and
project progress, the primary flag, the empty-project case, and project-not-
owned 404.

A file-local autouse fixture seeds the fake user + an owned project + three
placeable documents, then purges placements, user blueprints, the seeded docs,
and the project after each test. Mirrors ``test_placement_api``.
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
_PROJECT_ID = "9b1d0003-0000-4000-8000-000000000001"

_DOC_CH1 = "d0c00301-0000-4000-8000-000000000001"
_DOC_CH2 = "d0c00302-0000-4000-8000-000000000002"  # soft-deleted after placement
_DOC_CH3 = "d0c00303-0000-4000-8000-000000000003"
_SEEDED_DOC_IDS = [_DOC_CH1, _DOC_CH2, _DOC_CH3]


@pytest_asyncio.fixture(autouse=True)
async def _seed_and_cleanup():
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
                    "ext": "itest-overview-user",
                    "email": "itest-overview@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO projects (id, user_id, name) "
                    "VALUES (:id, :uid, :name) ON CONFLICT (id) DO NOTHING"
                ),
                {"id": _PROJECT_ID, "uid": str(_FAKE_USER_ID), "name": "2G Project"},
            )
            for doc_id in _SEEDED_DOC_IDS:
                await conn.execute(
                    text(
                        "INSERT INTO documents "
                        "(id, user_id, project_id, title, source_type, status, "
                        " storage_key, word_count) "
                        "VALUES (:id, :uid, :pid, :title, 'docx', 'ready', '', 0) "
                        "ON CONFLICT (id) DO NOTHING"
                    ),
                    {
                        "id": doc_id,
                        "uid": str(_FAKE_USER_ID),
                        "pid": _PROJECT_ID,
                        "title": f"Doc {doc_id[-1]}",
                    },
                )
        yield
    finally:
        async with engine.begin() as conn:
            await conn.execute(
                text("DELETE FROM part_documents WHERE document_id = ANY(:ids)"),
                {"ids": _SEEDED_DOC_IDS},
            )
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


async def _new_part(client, blueprint_id, name, parent_part_id=None) -> str:
    body: dict = {"name": name}
    if parent_part_id is not None:
        body["parent_part_id"] = parent_part_id
    resp = await client.post(
        f"/api/v1/blueprints/{blueprint_id}/parts/", json=body
    )
    assert resp.status_code == 201
    return resp.json()["id"]


async def _place(client, document_id, part_id):
    resp = await client.put(
        f"/api/v1/documents/{document_id}/placement", json={"part_id": part_id}
    )
    assert resp.status_code in (200, 201)
    return resp


async def _soft_delete(document_id):
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    try:
        async with engine.begin() as conn:
            await conn.execute(
                text(
                    "UPDATE documents SET status = 'deleted' WHERE id = :id"
                ),
                {"id": document_id},
            )
    finally:
        await engine.dispose()


def _overview(client):
    return client.get(f"/api/v1/projects/{_PROJECT_ID}/blueprint-overview/")


def _by_name(nodes) -> dict:
    return {n["name"]: n for n in nodes}


async def _build_nested_blueprint(client) -> str:
    """A nested tree exercising all three readiness states + soft-delete.

      Act I (container)        -> in_progress (Ch 1 ready, Ch 2 empty)
        Ch 1 (leaf)            -> ready   (1 live doc)
        Ch 2 (leaf)            -> empty   (1 placed doc, then soft-deleted)
      Act II (container)       -> ready   (Ch 3 ready)
        Ch 3 (leaf)            -> ready   (1 live doc)
      Act III (leaf)           -> empty   (no docs)

    Leaves: Ch1, Ch2, Ch3, Act III = 4; with content: Ch1, Ch3 = 2 -> 0.5.
    """
    bid = await _new_blueprint(client, name="Nested")
    act1 = await _new_part(client, bid, "Act I")
    ch1 = await _new_part(client, bid, "Ch 1", parent_part_id=act1)
    ch2 = await _new_part(client, bid, "Ch 2", parent_part_id=act1)
    act2 = await _new_part(client, bid, "Act II")
    ch3 = await _new_part(client, bid, "Ch 3", parent_part_id=act2)
    await _new_part(client, bid, "Act III")

    await _place(client, _DOC_CH1, ch1)  # first placement auto-adopts as primary
    await _place(client, _DOC_CH3, ch3)
    await _place(client, _DOC_CH2, ch2)
    await _soft_delete(_DOC_CH2)  # placement row survives, excluded from counts
    return bid


# ── Tests ──────────────────────────────────────────────────────────────────────


class TestDerivedOverview:
    @pytest.mark.asyncio
    async def test_counts_readiness_and_progress(self, client, auth_override):
        await _build_nested_blueprint(client)

        resp = await _overview(client)
        assert resp.status_code == 200
        body = resp.json()

        # One adopted blueprint, primary (auto on first placement).
        assert len(body["blueprints"]) == 1
        bp = body["blueprints"][0]
        assert bp["is_primary"] is True

        # Project progress == primary blueprint progress == 2/4 leaves.
        for prog in (body["progress"], bp["progress"]):
            assert prog["total_leaves"] == 4
            assert prog["leaves_with_content"] == 2
            assert prog["ratio"] == 0.5

        roots = _by_name(bp["parts"])
        act1, act2, act3 = roots["Act I"], roots["Act II"], roots["Act III"]

        # Act I: one ready child, one empty child -> in_progress.
        assert act1["readiness"] == "in_progress"
        a1 = _by_name(act1["children"])
        assert a1["Ch 1"]["document_count"] == 1
        assert a1["Ch 1"]["has_content"] is True
        assert a1["Ch 1"]["readiness"] == "ready"
        # Ch 2's only doc was soft-deleted -> excluded from the count -> empty.
        assert a1["Ch 2"]["document_count"] == 0
        assert a1["Ch 2"]["has_content"] is False
        assert a1["Ch 2"]["readiness"] == "empty"

        # Act II: all children ready -> ready.
        assert act2["readiness"] == "ready"
        assert _by_name(act2["children"])["Ch 3"]["document_count"] == 1

        # Act III: leaf with no docs -> empty.
        assert act3["readiness"] == "empty"
        assert act3["document_count"] == 0

    @pytest.mark.asyncio
    async def test_soft_deleted_placement_row_survives(self, client, auth_override):
        await _build_nested_blueprint(client)
        # Ch 2 reports zero documents, but its placement row is still present.
        engine = create_async_engine(
            get_settings().database_url, poolclass=NullPool
        )
        try:
            async with engine.begin() as conn:
                count = (
                    await conn.execute(
                        text(
                            "SELECT count(*) FROM part_documents "
                            "WHERE document_id = :id"
                        ),
                        {"id": _DOC_CH2},
                    )
                ).scalar_one()
        finally:
            await engine.dispose()
        assert count == 1


class TestEmptyAndAuth:
    @pytest.mark.asyncio
    async def test_empty_project_is_200_empty(self, client, auth_override):
        # No blueprint adopted into the project.
        resp = await _overview(client)
        assert resp.status_code == 200
        body = resp.json()
        assert body["progress"] is None
        assert body["blueprints"] == []

    @pytest.mark.asyncio
    async def test_project_not_owned_is_404(self, app, client, auth_override):
        other = uuid4()
        app.dependency_overrides[get_current_user_id] = lambda: other
        resp = await _overview(client)
        assert resp.status_code == 404
