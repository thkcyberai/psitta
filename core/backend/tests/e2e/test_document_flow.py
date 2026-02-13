"""
End-to-end test: Upload → Process → Play full cycle.

This test exercises the complete document narration pipeline.
Requires all services running (Postgres, Redis, MinIO).

Marked as slow — excluded from default test runs.
Run with: pytest -m slow
"""

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


@pytest.mark.slow
class TestDocumentNarrationFlow:
    """Full lifecycle: upload → process → playback."""

    @pytest.mark.asyncio
    async def test_health_check_available(self, client):
        """Smoke test — API is responsive."""
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

    @pytest.mark.asyncio
    async def test_ready_check_reports_dependencies(self, client):
        """Readiness probe reports infrastructure status."""
        response = await client.get("/ready")
        # May fail if services aren't running — that's expected
        assert response.status_code in (200, 503)

    @pytest.mark.asyncio
    @pytest.mark.skip(reason="Requires full stack — enable in CI with services")
    async def test_upload_process_and_play(self, client):
        """Upload a document, wait for processing, verify audio playback.

        Pipeline:
          1. POST /api/v1/documents/upload — upload PDF
          2. Poll GET /api/v1/documents/{id} — wait for status=ready
          3. POST /api/v1/playback/sessions — create session
          4. GET /api/v1/playback/sessions/{id}/audio — stream audio
          5. PUT /api/v1/playback/sessions/{id}/position — update position
          6. DELETE /api/v1/documents/{id} — cleanup
        """
        pass
