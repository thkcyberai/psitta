"""
Psitta — FastAPI Dependency Injection.

Centralized dependency factories for database sessions, Redis connections,
S3 clients, and service instances. All injected via FastAPI's Depends().

Security:
  - Database sessions are scoped per-request and auto-committed/rolled-back
  - Redis connections are pooled (not created per-request)
  - S3 clients use short-lived credentials where possible
  - Service instances are stateless — safe to create per-request
"""

from __future__ import annotations

from typing import AsyncGenerator

import structlog
from fastapi import Depends
from sqlalchemy import text

from psitta.config import Settings, get_settings
from psitta.middleware.auth import TokenClaims  # noqa: F401 — re-export for convenience
from psitta.middleware.auth import get_current_user  # noqa: F401
from psitta.middleware.auth import require_permission  # noqa: F401
from psitta.middleware.auth import require_role  # noqa: F401

from uuid import UUID, uuid4
from datetime import datetime, timezone

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Database Session ───────────────────────────────────────────────────
async def get_db_session() -> AsyncGenerator:  # type: ignore[type-arg]
    """Yield a transactional async database session."""
    from psitta.db.session import async_session_factory
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# ── Current User ID ───────────────────────────────────────────────────
async def get_current_user_id(
    claims: TokenClaims = Depends(get_current_user),
    db=Depends(get_db_session),
) -> UUID:
    """Look up the user by auth0_user_id, auto-provisioning if not found."""
    sub = claims.sub

    # Look up existing user
    result = await db.execute(
        text("SELECT id FROM users WHERE auth0_user_id = :sub"),
        {"sub": sub},
    )
    row = result.fetchone()
    if row is not None:
        return row[0]

    # Auto-provision new user
    new_id = uuid4()
    email = getattr(claims, "email", None) or f"{sub.replace('|', '_')}@auth0.local"
    display_name = getattr(claims, "name", None) or email.split("@")[0]
    now = datetime.now(timezone.utc)

    await db.execute(
        text(
            "INSERT INTO users (id, external_id, email, display_name, auth0_user_id, tier, is_active, created_at, updated_at) "
            "VALUES (:id, :external_id, :email, :display_name, :auth0_user_id, 'free', true, :now, :now)"
        ),
        {
            "id": new_id,
            "external_id": str(new_id),
            "email": email,
            "display_name": display_name,
            "auth0_user_id": sub,
            "now": now,
        },
    )
    await db.flush()

    logger.info("user.provisioned", auth0_sub=sub, user_id=str(new_id))
    return new_id


# ── Settings Dependency ────────────────────────────────────────────────
async def get_app_settings() -> Settings:
    """Inject application settings into route handlers."""
    return get_settings()


async def get_redis():  # type: ignore[no-untyped-def]
    """Inject a Redis connection from the shared pool.

    Redis is used for:
      - Rate limiting counters
      - Playback session cache
      - Job queue (Redis Streams)
      - Audio URL cache

    Usage:
        @router.get("/cached")
        async def get_cached(redis: Redis = Depends(get_redis)):
            ...
    """
    # TODO: Wire to Redis pool initialized in lifespan
    # from psitta.main import app
    # yield app.state.redis
    yield None  # Placeholder until Redis is wired


# ── S3 Storage Client ──────────────────────────────────────────────────
async def get_storage_client():  # type: ignore[no-untyped-def]
    """Inject an S3-compatible storage client.

    Used for document uploads and audio file storage.
    Supports both AWS S3 and MinIO (local development).

    Usage:
        @router.post("/upload")
        async def upload(storage = Depends(get_storage_client)):
            ...
    """
    # TODO: Wire to S3 client initialized in lifespan
    yield None  # Placeholder until S3 is wired


# ── Service Factories ──────────────────────────────────────────────────
# These will be uncommented as services are implemented:
#
# async def get_document_service(
#     db=Depends(get_db_session),
#     storage=Depends(get_storage_client),
#     redis=Depends(get_redis),
#     settings: Settings = Depends(get_app_settings),
# ) -> DocumentService:
#     return DocumentService(db=db, storage=storage, redis=redis, settings=settings)
#
# async def get_playback_service(
#     db=Depends(get_db_session),
#     storage=Depends(get_storage_client),
#     redis=Depends(get_redis),
#     settings: Settings = Depends(get_app_settings),
# ) -> PlaybackService:
#     return PlaybackService(db=db, storage=storage, redis=redis, settings=settings)
