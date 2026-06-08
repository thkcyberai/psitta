"""Shared fixtures for API integration tests.

Provides a single httpx ``AsyncClient`` bound to the real FastAPI app via
ASGI transport, with ``follow_redirects=True``.

The v1 routers declare trailing-slash paths (e.g. ``/voices/``,
``/playback/sessions/``, ``/documents/``) and the app runs with FastAPI's
default ``redirect_slashes=True``. A slashless request therefore returns a
307 to the canonical path; following it lets these tests assert on the real
endpoint's response instead of on the redirect itself.

Two OPT-IN fixtures support tests that must reach FastAPI request validation
on auth-protected endpoints. Neither is autouse; both tear down cleanly so
they cannot leak into another test:

  - ``auth_override`` replaces ``get_current_user_id`` with a fixed fake user
    so a missing/invalid request field surfaces as a 422 at FastAPI
    validation, *before* the handler touches the database.
  - ``stub_jwks`` stubs the Cognito JWKS network fetch. ``get_current_user``
    fetches JWKS *before* decoding the token; with ``COGNITO_USER_POOL_ID``
    unset (as in CI) that fetch errors and surfaces as a 500. Stubbing it lets
    an *invalid* bearer token fail at JWT decode → 401 (the code an
    auth-required endpoint should return for a bad token), with no network.
"""

from __future__ import annotations

from uuid import UUID

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from psitta.config import get_settings
from psitta.dependencies import get_db_session
from psitta.main import create_app

_FAKE_USER_ID = UUID("00000000-0000-0000-0000-000000000001")


@pytest_asyncio.fixture
async def app():
    """A fresh FastAPI app per test (function-scoped → isolated overrides)."""
    return create_app()


@pytest_asyncio.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        follow_redirects=True,
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def auth_override(app):
    """OPT-IN (not autouse). Bypass ``get_current_user_id`` with a fixed fake
    user so a test can reach request validation past the auth dependency.
    Cleared in teardown so it never leaks into another test's app."""
    from psitta.dependencies import get_current_user_id

    app.dependency_overrides[get_current_user_id] = lambda: _FAKE_USER_ID
    try:
        yield _FAKE_USER_ID
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)


@pytest_asyncio.fixture
async def stub_jwks(monkeypatch):
    """OPT-IN (not autouse). Stub the Cognito JWKS fetch so token validation
    runs offline; an invalid bearer token then fails JWT decode → 401 rather
    than 500 from the network fetch. ``monkeypatch`` reverts in teardown."""
    import psitta.middleware.auth as auth_module

    async def _fake_get_jwks(_settings):
        return {"keys": []}

    monkeypatch.setattr(auth_module, "_get_jwks", _fake_get_jwks)
    yield


@pytest_asyncio.fixture(autouse=True)
async def _db_session_on_test_loop(app):
    """Route ``get_db_session`` through a NullPool engine created and disposed
    inside the test's own event loop.

    The app's module-level engine uses QueuePool, which retains asyncpg
    connections after a function-scoped loop closes; finalizing them on the
    dead loop raises ``RuntimeError: Event loop is closed`` at teardown.
    NullPool opens and closes a connection per checkout within the live loop,
    and the per-test ``engine.dispose()`` guarantees cleanup before the loop
    ends. The real ``get_db_session`` contract (commit on success, rollback +
    re-raise on exception, close) is preserved exactly — only the pool class
    differs. Autouse so every integration request that reaches the DB is safe;
    the audit-log test (which manages its own engine) is unaffected.
    """
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    session_factory = async_sessionmaker(
        bind=engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
    )

    async def _override_get_db_session():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
            finally:
                await session.close()

    app.dependency_overrides[get_db_session] = _override_get_db_session
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_db_session, None)
        await engine.dispose()
