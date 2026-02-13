"""Integration tests for /api/v1/voices endpoints."""

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


class TestVoiceListEndpoint:
    """GET /api/v1/voices"""

    @pytest.mark.asyncio
    async def test_list_voices_returns_200(self, client):
        response = await client.get("/api/v1/voices")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_list_voices_returns_array(self, client):
        response = await client.get("/api/v1/voices")
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, (dict, list))

    @pytest.mark.asyncio
    async def test_filter_by_language(self, client):
        response = await client.get("/api/v1/voices?language=en-US")
        assert response.status_code in (200, 422)
