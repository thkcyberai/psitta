"""Integration tests for the Phase 5 project read endpoints.

Covers the three additive, owner-guarded reads against the seeded CI Postgres
via the shared ``client`` + ``auth_override`` fixtures:

  - ``GET /projects/{id}``              aggregated detail (counts + word sum)
  - ``GET /projects/{id}/documents``    now carries ``word_count``
  - ``GET /projects/{id}/placements``   document -> blueprint/part names

A file-local autouse fixture seeds the fake user, an owned project, and two
non-deleted documents with known word counts, then purges placements, user
blueprints, the seeded docs, and the project after each test. Blueprints + parts
are built via the API (placement auto-adopts), mirroring ``test_blueprint_
overview_api``.
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
_PROJECT_ID = "9b1d0005-0000-4000-8000-000000000001"

_DOC_A = "d0c00501-0000-4000-8000-000000000001"  # 100 words
_DOC_B = "d0c00502-0000-4000-8000-000000000002"  # 250 words
_SEEDED = [(_DOC_A, 100), (_DOC_B, 250)]
_SEEDED_IDS = [d for d, _ in _SEEDED]


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
                    "ext": "itest-proj5-user",
                    "email": "itest-proj5@test.local",
                },
            )
            await conn.execute(
                text(
                    "INSERT INTO projects (id, user_id, name) "
                    "VALUES (:id, :uid, :name) ON CONFLICT (id) DO NOTHING"
                ),
                {"id": _PROJECT_ID, "uid": str(_FAKE_USER_ID), "name": "P5 Project"},
            )
            for doc_id, words in _SEEDED:
                await conn.execute(
                    text(
                        "INSERT INTO documents "
                        "(id, user_id, project_id, title, source_type, status, "
                        " storage_key, word_count) "
                        "VALUES (:id, :uid, :pid, :title, 'docx', 'ready', '', :wc) "
                        "ON CONFLICT (id) DO NOTHING"
                    ),
                    {
                        "id": doc_id,
                        "uid": str(_FAKE_USER_ID),
                        "pid": _PROJECT_ID,
                        "title": f"Doc {doc_id[-1]}",
                        "wc": words,
                    },
                )
        yield
    finally:
        async with engine.begin() as conn:
            await conn.execute(
                text("DELETE FROM part_documents WHERE document_id = ANY(:ids)"),
                {"ids": _SEEDED_IDS},
            )
            await conn.execute(
                text("DELETE FROM blueprints WHERE user_id IS NOT NULL")
            )
            await conn.execute(
                text("DELETE FROM documents WHERE id = ANY(:ids)"),
                {"ids": _SEEDED_IDS},
            )
            await conn.execute(
                text("DELETE FROM projects WHERE id = :id"), {"id": _PROJECT_ID}
            )
        await engine.dispose()


# ── Helpers (mirror test_blueprint_overview_api) ──────────────────────────────


async def _new_blueprint(client, name="P5 BP", genre="Novel") -> str:
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


# ── GET /projects/{id} ────────────────────────────────────────────────────────


class TestProjectDetail:
    @pytest.mark.asyncio
    async def test_detail_counts_and_word_sum(self, client, auth_override):
        # One placement auto-adopts a blueprint into the project.
        bid = await _new_blueprint(client)
        part = await _new_part(client, bid, "Act I")
        await _place(client, _DOC_A, part)

        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}")
        assert resp.status_code == 200
        body = resp.json()

        assert body["id"] == _PROJECT_ID
        assert body["name"] == "P5 Project"
        assert body["user_id"] == str(_FAKE_USER_ID)
        assert body["document_count"] == 2  # both non-deleted docs
        assert body["blueprint_count"] == 1  # auto-adopted
        assert body["total_words"] == 350  # 100 + 250
        assert "created_at" in body and "updated_at" in body

    @pytest.mark.asyncio
    async def test_detail_total_words_zero_with_no_docs(
        self, client, auth_override
    ):
        # A separate, empty owned project: total_words is 0, not null.
        empty_id = "9b1d0005-0000-4000-8000-0000000000ee"
        engine = create_async_engine(
            get_settings().database_url, poolclass=NullPool
        )
        try:
            async with engine.begin() as conn:
                await conn.execute(
                    text(
                        "INSERT INTO projects (id, user_id, name) "
                        "VALUES (:id, :uid, :name) ON CONFLICT (id) DO NOTHING"
                    ),
                    {"id": empty_id, "uid": str(_FAKE_USER_ID), "name": "Empty"},
                )
            resp = await client.get(f"/api/v1/projects/{empty_id}")
            assert resp.status_code == 200
            body = resp.json()
            assert body["document_count"] == 0
            assert body["blueprint_count"] == 0
            assert body["total_words"] == 0
        finally:
            async with engine.begin() as conn:
                await conn.execute(
                    text("DELETE FROM projects WHERE id = :id"), {"id": empty_id}
                )
            await engine.dispose()

    @pytest.mark.asyncio
    async def test_detail_404_when_not_owned(self, app, client, auth_override):
        app.dependency_overrides[get_current_user_id] = lambda: uuid4()
        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}")
        assert resp.status_code == 404


# ── GET /projects/{id}/documents (word_count addition) ────────────────────────


class TestDocumentsWordCount:
    @pytest.mark.asyncio
    async def test_documents_list_includes_word_count(
        self, client, auth_override
    ):
        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/documents")
        assert resp.status_code == 200
        docs = resp.json()
        assert len(docs) == 2
        for d in docs:
            assert "word_count" in d
        by_id = {d["id"]: d["word_count"] for d in docs}
        assert by_id[_DOC_A] == 100
        assert by_id[_DOC_B] == 250


# ── GET /projects/{id}/placements ─────────────────────────────────────────────


class TestProjectPlacements:
    @pytest.mark.asyncio
    async def test_placements_return_blueprint_and_part_names(
        self, client, auth_override
    ):
        bid = await _new_blueprint(client, name="Nested")
        part = await _new_part(client, bid, "Act I")
        await _place(client, _DOC_A, part)

        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/placements")
        assert resp.status_code == 200
        rows = resp.json()
        assert len(rows) == 1
        row = rows[0]
        assert row["document_id"] == _DOC_A
        assert row["blueprint_id"] == bid
        assert row["part_id"] == part
        assert row["blueprint_name"] == "Nested"
        assert row["part_name"] == "Act I"

    @pytest.mark.asyncio
    async def test_placements_empty_when_none(self, client, auth_override):
        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/placements")
        assert resp.status_code == 200
        assert resp.json() == []

    @pytest.mark.asyncio
    async def test_placements_404_when_not_owned(
        self, app, client, auth_override
    ):
        app.dependency_overrides[get_current_user_id] = lambda: uuid4()
        resp = await client.get(f"/api/v1/projects/{_PROJECT_ID}/placements")
        assert resp.status_code == 404
