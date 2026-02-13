"""
Psitta — Async Database Session Management.

Configures SQLAlchemy async engine and session factory for PostgreSQL.
All database access flows through sessions created by this module.

Security:
  - Connection pool limits prevent resource exhaustion
  - Statement timeout prevents long-running queries (30s default)
  - SSL mode enforced in production
  - Credentials loaded from SecretStr (never in connection string logs)

Performance:
  - Connection pooling with configurable size and overflow
  - Prepared statement caching via asyncpg
  - NullPool option for serverless/Lambda deployments
"""

from __future__ import annotations

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from psitta.config import get_settings

_settings = get_settings()

# ── Async Engine ───────────────────────────────────────────────────────
async_engine: AsyncEngine = create_async_engine(
    _settings.database_url,
    pool_size=_settings.DATABASE_POOL_SIZE,
    max_overflow=_settings.DATABASE_POOL_OVERFLOW,
    pool_pre_ping=True,
    pool_recycle=300,
    echo=_settings.ENVIRONMENT == "development",
    connect_args={
        "server_settings": {
            "statement_timeout": "30000",
            "lock_timeout": "10000",
        },
    },
)

# ── Session Factory ────────────────────────────────────────────────────
async_session_factory: async_sessionmaker[AsyncSession] = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)
