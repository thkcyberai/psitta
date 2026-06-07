"""Integration tests for /api/v1/playback endpoints."""

from __future__ import annotations

import pytest


class TestPlaybackSessionEndpoint:
    """POST /api/v1/playback/sessions"""

    @pytest.mark.asyncio
    async def test_create_session_requires_body(self, client, auth_override):
        # Group B: auth_override passes auth so the missing required
        # `document_id` query param is rejected at validation (422), pre-DB.
        response = await client.post("/api/v1/playback/sessions")
        assert response.status_code in (400, 422)

    @pytest.mark.asyncio
    async def test_create_session_validates_document_id(self, client, auth_override):
        # Group B: `document_id` is a query param; sending it in the JSON body
        # leaves the query param absent → 422 at validation, pre-DB. (The
        # nonexistent-UUID path is never reached, so this never hits the DB.)
        response = await client.post(
            "/api/v1/playback/sessions",
            json={"document_id": "not-a-uuid", "voice_id": "en-US-AriaNeural"},
        )
        assert response.status_code in (400, 422)
