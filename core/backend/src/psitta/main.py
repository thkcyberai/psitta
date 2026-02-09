"""
Psitta API — Main application entry point.

Production-ready FastAPI application with:
- Structured logging
- OpenTelemetry instrumentation
- CORS middleware
- Health checks
- Graceful shutdown
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

import structlog
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

from psitta.api.v1.router import api_router
from psitta.config import get_settings
from psitta.db.session import engine, sessionmanager
from psitta.dependencies import setup_providers
from psitta.middleware.rate_limit import RateLimitMiddleware
from psitta.middleware.request_id import RequestIDMiddleware


def configure_logging(log_level: str) -> None:
    """Configure structlog with JSON output for production, console for dev."""
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.StackInfoRenderer(),
            structlog.dev.set_exc_info,
            structlog.processors.TimeStamper(fmt="iso"),
            (
                structlog.dev.ConsoleRenderer()
                if not get_settings().is_production
                else structlog.processors.JSONRenderer()
            ),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelName(log_level.upper())
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Manage application lifecycle: startup and shutdown."""
    settings = get_settings()
    logger = structlog.get_logger()

    # Initialize database connection pool
    sessionmanager.init(str(settings.database_url))
    logger.info("database_connected", pool_size=settings.database_pool_size)

    # Initialize provider registry
    await setup_providers(settings)
    logger.info("providers_initialized")

    logger.info(
        "application_started",
        environment=settings.environment,
        version=settings.app_version,
    )

    yield

    # Graceful shutdown
    await sessionmanager.close()
    if engine:
        await engine.dispose()
    logger.info("application_stopped")


def create_app() -> FastAPI:
    """Application factory."""
    settings = get_settings()
    configure_logging(settings.log_level)

    app = FastAPI(
        title="Psitta API",
        version=settings.app_version,
        docs_url="/api/docs" if not settings.is_production else None,
        redoc_url="/api/redoc" if not settings.is_production else None,
        openapi_url="/api/openapi.json" if not settings.is_production else None,
        lifespan=lifespan,
    )

    # ── Middleware (order matters: first added = outermost) ───────
    app.add_middleware(RequestIDMiddleware)
    app.add_middleware(RateLimitMiddleware, settings=settings)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
        expose_headers=[
            "X-Request-ID",
            "X-RateLimit-Limit",
            "X-RateLimit-Remaining",
            "X-RateLimit-Reset",
        ],
    )

    # ── OpenTelemetry ────────────────────────────────────────────
    FastAPIInstrumentor.instrument_app(app)

    # ── Routes ───────────────────────────────────────────────────
    app.include_router(api_router, prefix="/api/v1")

    # ── Health check (outside /api/v1) ───────────────────────────
    @app.get("/health", tags=["health"])
    async def health_check() -> dict[str, str]:
        return {"status": "healthy", "version": settings.app_version}

    return app


app = create_app()
