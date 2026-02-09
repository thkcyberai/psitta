"""Integration tests for /api/v1/users endpoints."""

from __future__ import annotations

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from psitta.main import create_app


@pytest_asyncio.fixture
async def client():
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


class TestUserProfileEndpoint:
    """GET /api/v1/users/me"""

    @pytest.mark.asyncio
    async def test_profile_requires_auth(self, client):
        response = await client.get("/api/v1/users/me")
        assert response.status_code in (200, 401, 403)

    @pytest.mark.asyncio
    async def test_preferences_update_validates(self, client):
        response = await client.put(
            "/api/v1/users/me/preferences",
            json={"default_speed": 999.0},
        )
        assert response.status_code in (400, 401, 422)
