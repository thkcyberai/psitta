"""
Psitta — FastAPI Application Factory.

Entry point for the backend API. Uses the factory pattern so that
test fixtures and CLI tools can create isolated app instances.

Usage:
    uvicorn psitta.main:create_app --factory --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from psitta import __version__
from psitta.config import get_settings
from psitta.middleware.rate_limit import RateLimitMiddleware
from psitta.middleware.request_id import RequestIDMiddleware


logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Lifespan (startup / shutdown) ─────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manage application lifecycle resources.

    Startup: Initialize DB pool, Redis connection, S3 client.
    Shutdown: Drain connections gracefully.
    """
    settings = get_settings()

    logger.info(
        "psitta.startup",
        version=__version__,
        environment=settings.ENVIRONMENT,
    )

    # ── Startup ────────────────────────────────────────────────────────
    # Database engine (lazy — created on first request if not here)
    # Redis pool and S3 client follow the same pattern.
    # These will be wired in dependencies.py via FastAPI's dependency injection.

    yield  # ← Application serves requests here

    # ── Shutdown ───────────────────────────────────────────────────────
    logger.info("psitta.shutdown", version=__version__)


# ── App Factory ────────────────────────────────────────────────────────
def create_app() -> FastAPI:
    """Create and configure the FastAPI application.

    Returns:
        Fully configured FastAPI instance with all routes,
        middleware, and lifecycle hooks registered.
    """
    settings = get_settings()

    app = FastAPI(
        title="Psitta API",
        description="Ultra-natural document narration — backend service",
        version=__version__,
        docs_url="/docs" if settings.ENVIRONMENT != "production" else None,
        redoc_url="/redoc" if settings.ENVIRONMENT != "production" else None,
        openapi_url="/openapi.json" if settings.ENVIRONMENT != "production" else None,
        lifespan=lifespan,
    )

    # ── Middleware (outermost first) ───────────────────────────────────
    # 1. Request ID — adds X-Request-ID to every request/response
    app.add_middleware(RequestIDMiddleware)

    # 2. CORS — configured from settings
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=[
            "X-Request-ID",
            "X-RateLimit-Limit",
            "X-RateLimit-Remaining",
            "X-RateLimit-Reset",
            "X-RateLimit-Tier",
            "Retry-After",
        ],
    )

    # 3. Rate limiting — per-tier token buckets keyed by authenticated
    #    Cognito user (sub) or client IP. Tiers:
    #       upload  5/min   POST /documents[/blank]
    #       tts    10/min   POST /documents/{id}[/chunks/{cid}]/resynthesize
    #       read  120/min   GET  /documents/...
    #       default         everything else
    app.add_middleware(RateLimitMiddleware)

    # ── Routes ─────────────────────────────────────────────────────────
    _register_routes(app)

    # ── Structured Logging ─────────────────────────────────────────────
    _configure_logging(settings.LOG_LEVEL)

    return app


# ── Route Registration ─────────────────────────────────────────────────
def _register_routes(app: FastAPI) -> None:
    """Mount all API version routers and health endpoints."""

    @app.get("/health", tags=["system"], include_in_schema=False)
    async def health_check() -> dict[str, str]:
        """Liveness probe — returns 200 if the process is running."""
        return {"status": "ok", "version": __version__}

    @app.get("/ready", tags=["system"], include_in_schema=False)
    async def readiness_check() -> dict[str, str]:
        """Readiness probe — returns 200 when all dependencies are reachable.

        TODO: Check DB, Redis, S3 connectivity before returning 200.
        """
        return {"status": "ready", "version": __version__}

    # Mount v1 API router
    from psitta.api.v1.router import v1_router

    app.include_router(v1_router, prefix="/api/v1")


# ── Logging Configuration ─────────────────────────────────────────────
def _configure_logging(log_level: str) -> None:
    """Configure structlog with JSON output for production, pretty for dev."""

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    logging.basicConfig(
        format="%(message)s",
        level=getattr(logging, log_level.upper(), logging.INFO),
    )
