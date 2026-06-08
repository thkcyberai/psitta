"""Integration tests for the read-only Blueprints API.

Exercises the real FastAPI app against the integration Postgres seeded to head
(migration 022 inserts the ten system templates and their parts). Auth is
bypassed with the ``auth_override`` fixture (fixed fake user); the shared
``client`` fixture (``follow_redirects=True``) handles the trailing-slash 307.

Since no write endpoints exist yet, the fake user owns zero blueprints, so
every visible row is a system template.
"""

from __future__ import annotations

from uuid import uuid4

import pytest

pytestmark = pytest.mark.integration

# Stable seeded template ids (migration 022 _BP_ID), referenced by spec.
_NOVEL_ID = "5eed0001-0000-4000-8000-000000000001"
_SCREENPLAY_ID = "5eed0007-0000-4000-8000-000000000007"

_EXPECTED_GENRES = {
    "Novel",
    "Memoir",
    "Non-Fiction",
    "Biography",
    "Research Paper",
    "Children's Picture Book",
    "Screenplay",
    "Workbook/How-To",
    "Business Book",
    "Short Story Collection",
}


def _count_nodes(nodes) -> int:
    """Recursively count a parts tree (roots + all descendants)."""
    return sum(1 + _count_nodes(n["children"]) for n in nodes)


def _find(nodes, name):
    for n in nodes:
        if n["name"] == name:
            return n
    return None


class TestListBlueprints:
    @pytest.mark.asyncio
    async def test_lists_all_ten_system_templates(self, client, auth_override):
        resp = await client.get("/api/v1/blueprints/")
        assert resp.status_code == 200
        rows = resp.json()

        assert len(rows) >= 10
        assert _EXPECTED_GENRES.issubset({r["genre"] for r in rows})
        # No write path exists → every visible blueprint is a system template.
        assert all(r["is_system"] is True for r in rows)

    @pytest.mark.asyncio
    async def test_fresh_user_sees_no_user_blueprints(self, client, auth_override):
        resp = await client.get("/api/v1/blueprints/")
        assert resp.status_code == 200
        rows = resp.json()
        assert [r for r in rows if r["is_system"] is False] == []


class TestGetBlueprintDetail:
    @pytest.mark.asyncio
    async def test_novel_nested_tree_matches_seed(self, client, auth_override):
        resp = await client.get(f"/api/v1/blueprints/{_NOVEL_ID}")
        assert resp.status_code == 200
        body = resp.json()

        assert body["genre"] == "Novel"
        assert body["is_system"] is True

        parts = body["parts"]
        assert len(parts) == 5  # Front Matter, Act I, Act II, Act III, Back Matter

        front = _find(parts, "Front Matter")
        back = _find(parts, "Back Matter")
        assert front is not None and len(front["children"]) == 2
        assert back is not None and len(back["children"]) == 2

        # 5 top-level + 2 + 2 nested = 9 total nodes.
        assert _count_nodes(parts) == 9

        # Top-level parts are returned in ascending sort_order.
        orders = [p["sort_order"] for p in parts]
        assert orders == sorted(orders)

    @pytest.mark.asyncio
    async def test_screenplay_is_flat(self, client, auth_override):
        resp = await client.get(f"/api/v1/blueprints/{_SCREENPLAY_ID}")
        assert resp.status_code == 200
        body = resp.json()

        parts = body["parts"]
        assert len(parts) == 4  # Title Page, Act I, Act II, Act III
        assert all(p["children"] == [] for p in parts)

    @pytest.mark.asyncio
    async def test_unknown_uuid_returns_404(self, client, auth_override):
        resp = await client.get(f"/api/v1/blueprints/{uuid4()}")
        assert resp.status_code == 404
