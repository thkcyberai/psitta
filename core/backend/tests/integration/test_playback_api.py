"""Integration tests for /api/v1/playback endpoints."""

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


class TestPlaybackSessionEndpoint:
    """POST /api/v1/playback/sessions"""

    @pytest.mark.asyncio
    async def test_create_session_requires_body(self, client):
        response = await client.post("/api/v1/playback/sessions")
        assert response.status_code in (400, 422)

    @pytest.mark.asyncio
    async def test_create_session_validates_document_id(self, client):
        response = await client.post(
            "/api/v1/playback/sessions",
            json={"document_id": "not-a-uuid", "voice_id": "en-US-AriaNeural"},
        )
        assert response.status_code in (400, 422)
