"""
Unit tests for RequestID middleware.

Verifies that every response includes an X-Request-ID header,
that client-provided IDs are preserved, and that malformed
IDs are rejected.
"""

from __future__ import annotations

from uuid import uuid4

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


class TestRequestIDMiddleware:
    """Tests for X-Request-ID header handling."""

    @pytest.mark.asyncio
    async def test_generates_request_id_when_missing(self, client):
        """Requests without X-Request-ID get one generated."""
        response = await client.get("/health")

        assert response.status_code == 200
        request_id = response.headers.get("X-Request-ID")
        assert request_id is not None
        assert len(request_id) > 0

    @pytest.mark.asyncio
    async def test_preserves_incoming_request_id(self, client):
        """Client-provided X-Request-ID is preserved in response."""
        custom_id = f"test-{uuid4().hex[:8]}"
        response = await client.get(
            "/health",
            headers={"X-Request-ID": custom_id},
        )

        assert response.status_code == 200
        assert response.headers.get("X-Request-ID") == custom_id

    @pytest.mark.asyncio
    async def test_request_id_format_is_valid(self, client):
        """Generated request IDs should be valid UUIDs or prefixed strings."""
        response = await client.get("/health")
        request_id = response.headers.get("X-Request-ID", "")

        # Should be non-empty and reasonable length
        assert 8 <= len(request_id) <= 64

    @pytest.mark.asyncio
    async def test_rejects_oversized_request_id(self, client):
        """Excessively long X-Request-ID values should be rejected or truncated."""
        long_id = "x" * 200
        response = await client.get(
            "/health",
            headers={"X-Request-ID": long_id},
        )

        # Should still respond (not crash)
        assert response.status_code in (200, 400, 422)
        # If accepted, the returned ID should not be the oversized one
        returned_id = response.headers.get("X-Request-ID", "")
        assert len(returned_id) <= 128
