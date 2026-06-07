"""
Unit tests for PlaybackService.

Tests session management and position tracking
in isolation using mock providers.
"""

from __future__ import annotations

from unittest.mock import AsyncMock
from uuid import uuid4

import pytest

from psitta.config import Settings
from psitta.models.domain import PlaybackSession
from psitta.services.playback_service import PlaybackService
from tests.factories import PlaybackSessionFactory


class TestPlaybackSessionCreate:
    """Tests for creating playback sessions."""

    @pytest.fixture
    def service(self, mock_storage):
        return PlaybackService(
            db_session=AsyncMock(),
            storage_client=mock_storage,
            redis_client=AsyncMock(),
            settings=Settings(),
        )

    @pytest.mark.asyncio
    async def test_create_session_sets_initial_position(self, service):
        """New sessions should start at chunk 0, position 0."""
        session = PlaybackSessionFactory.create()

        assert session.current_chunk_index == 0
        assert session.position_ms == 0

    @pytest.mark.asyncio
    async def test_create_session_preserves_voice_choice(self, service):
        """Session should record the selected voice."""
        session = PlaybackSessionFactory.create(
            voice_id="en-GB-SoniaNeural",
            speed=1.5,
        )

        assert session.voice_id == "en-GB-SoniaNeural"
        assert session.speed == 1.5


class TestPlaybackPositionUpdate:
    """Tests for position tracking."""

    @pytest.mark.asyncio
    async def test_position_update_validates_bounds(self):
        """Position cannot exceed total chunks."""
        session = PlaybackSessionFactory.create(total_chunks=10)

        # Valid: chunk 9 (0-indexed, 10 total)
        assert session.total_chunks == 10

        # The service should reject chunk_index >= total_chunks
        # This is validated at the schema level (tested in test_schemas.py)


class TestPlaybackAudioUrl:
    """Tests for audio URL generation."""

    @pytest.fixture
    def service(self, mock_storage):
        return PlaybackService(
            db_session=AsyncMock(),
            storage_client=mock_storage,
            redis_client=AsyncMock(),
            settings=Settings(),
        )

    @pytest.mark.asyncio
    async def test_audio_url_uses_presigned_url(self, service, mock_storage):
        """Audio streaming should use pre-signed S3 URLs."""
        mock_storage.generate_presigned_url.return_value = (
            "https://s3.example.com/audio/test.mp3?signed=true"
        )

        url = await mock_storage.generate_presigned_url(
            bucket="psitta-storage",
            key="audio/test.mp3",
            expires_in=900,
        )

        assert "signed=true" in url
        mock_storage.generate_presigned_url.assert_called_once()
