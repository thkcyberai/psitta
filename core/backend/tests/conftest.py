"""
Psitta — Shared Test Fixtures.

Provides reusable fixtures for all test levels:
  - Unit: mock providers, in-memory state
  - Integration: real DB + Redis via service containers
  - E2E: full application stack via ASGI transport

Fixtures follow pytest-asyncio patterns with proper
teardown to prevent state leakage between tests.
"""

from __future__ import annotations

from typing import AsyncGenerator
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from psitta.config import Settings
from psitta.models.domain import (
    DocumentStatus,
    ToneCategory,
    UserTier,
)


# ── Core Fixtures ──────────────────────────────────────────────────────

@pytest.fixture
def anyio_backend():
    """Use asyncio for all async tests."""
    return "asyncio"


@pytest.fixture
def test_settings() -> Settings:
    """Settings configured for testing — no external services required."""
    return Settings(
        ENVIRONMENT="testing",
        LOG_LEVEL="WARNING",
        DATABASE_HOST="localhost",
        DATABASE_PORT=5432,
        DATABASE_NAME="psitta_test",
        DATABASE_USER="psitta",
        DATABASE_PASSWORD="test_password",
        REDIS_HOST="localhost",
        REDIS_PORT=6379,
        S3_ENDPOINT_URL="http://localhost:9000",
        S3_BUCKET_NAME="psitta-test",
        AWS_ACCESS_KEY_ID="testing",
        AWS_SECRET_ACCESS_KEY="testing",
        AZURE_TTS_KEY="",
        AZURE_TTS_REGION="centralus",
        ANTHROPIC_API_KEY="",
        SECRET_KEY="test-secret-not-for-production",
    )


# ── Mock Provider Fixtures ─────────────────────────────────────────────

@pytest.fixture
def mock_storage() -> AsyncMock:
    """Mock S3 storage provider."""
    storage = AsyncMock()
    storage.put_object = AsyncMock(return_value=f"uploads/{uuid4()}.pdf")
    storage.get_object = AsyncMock(return_value=b"fake-file-content")
    storage.delete_object = AsyncMock(return_value=True)
    storage.generate_presigned_url = AsyncMock(
        return_value="https://s3.example.com/presigned/test"
    )
    storage.health_check = AsyncMock(return_value=True)
    return storage


@pytest.fixture
def mock_tts() -> AsyncMock:
    """Mock TTS provider."""
    tts = AsyncMock()
    tts.synthesize = AsyncMock(return_value=b"fake-audio-bytes")
    tts.health_check = AsyncMock(return_value=True)
    return tts


@pytest.fixture
def mock_vision() -> AsyncMock:
    """Mock vision description provider."""
    vision = AsyncMock()
    vision.describe_image = AsyncMock(
        return_value="A bar chart showing quarterly revenue growth."
    )
    vision.health_check = AsyncMock(return_value=True)
    return vision


@pytest.fixture
def mock_voice_catalog() -> AsyncMock:
    """Mock voice catalog provider."""
    from psitta.models.domain import VoiceProfile

    voices = [
        VoiceProfile(
            id="en-US-AriaNeural",
            display_name="Aria",
            language="en-US",
            gender="female",
            provider="azure",
            tier="free",
            styles=["chat", "narration-professional"],
            description="Test voice",
        ),
    ]

    catalog = AsyncMock()
    catalog.list_voices = AsyncMock(return_value=voices)
    catalog.get_voice = AsyncMock(return_value=voices[0])
    catalog.get_preview_url = AsyncMock(
        return_value="/api/v1/voices/en-US-AriaNeural/preview/audio"
    )
    return catalog


@pytest.fixture
def mock_tone_classifier() -> AsyncMock:
    """Mock tone classifier."""
    classifier = AsyncMock()
    classifier.classify = AsyncMock(return_value=ToneCategory.NEUTRAL)
    return classifier


@pytest.fixture
def mock_redis() -> AsyncMock:
    """Mock Redis client."""
    redis = AsyncMock()
    redis.xadd = AsyncMock(return_value="1234567890-0")
    redis.get = AsyncMock(return_value=None)
    redis.set = AsyncMock(return_value=True)
    redis.ping = AsyncMock(return_value=True)
    return redis


# ── Test Client Fixture ────────────────────────────────────────────────

@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Async HTTP client for integration/e2e tests.

    Creates a fresh FastAPI app instance per test with
    ASGI transport (no real HTTP server needed).
    """
    from psitta.main import create_app

    app = create_app()
    transport = ASGITransport(app=app)

    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        headers={"X-Request-ID": f"test-{uuid4().hex[:8]}"},
    ) as ac:
        yield ac


# ── Test Data Helpers ──────────────────────────────────────────────────

@pytest.fixture
def sample_user_id() -> str:
    return f"user_{uuid4().hex[:12]}"


@pytest.fixture
def sample_document_id() -> str:
    return str(uuid4())
