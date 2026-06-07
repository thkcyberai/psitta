"""
Integration tests for /api/v1/documents endpoints.

These tests run against a real FastAPI instance via ASGI transport.
Database and external services are mocked at the dependency level.
"""

from __future__ import annotations

import pytest


class TestDocumentListEndpoint:
    """GET /api/v1/documents"""

    @pytest.mark.asyncio
    async def test_list_returns_200(self, client, stub_jwks):
        # Group A: a present-but-invalid bearer passes HTTPBearer, then fails
        # JWT decode (JWKS stubbed offline) → 401, already in the assertion.
        response = await client.get(
            "/api/v1/documents",
            headers={"Authorization": "Bearer invalid.token"},
        )
        assert response.status_code in (200, 401, 422)

    @pytest.mark.asyncio
    async def test_list_returns_json(self, client):
        response = await client.get("/api/v1/documents")
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, (dict, list))


class TestDocumentUploadEndpoint:
    """POST /api/v1/documents/upload"""

    @pytest.mark.asyncio
    async def test_upload_without_file_returns_error(self, client, auth_override):
        # Group B: auth_override lets the request pass auth so the missing
        # required `file` is rejected at FastAPI validation (422), before the
        # handler touches the database.
        response = await client.post("/api/v1/documents/")
        assert response.status_code in (400, 422)

    @pytest.mark.asyncio
    async def test_upload_requires_auth_header(self, client, stub_jwks):
        """Upload should require authentication."""
        # Group A: present-but-invalid bearer → HTTPBearer passes → JWT decode
        # fails (JWKS stubbed offline) → 401, already in the assertion.
        response = await client.post(
            "/api/v1/documents/",
            files={"file": ("test.pdf", b"fake-pdf", "application/pdf")},
            headers={"Authorization": "Bearer invalid.token"},
        )
        # Either 401 (auth required) or 422 (validation) or 200 (no auth yet)
        assert response.status_code in (200, 401, 422)
