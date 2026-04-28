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

from collections.abc import AsyncGenerator
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID, uuid4

import structlog
from fastapi import Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import Settings, get_settings
from psitta.middleware.auth import TokenClaims, get_current_user

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
    """Look up the user by auth0_user_id, auto-provisioning if not found.

    Race-safe under concurrent first-login. The desktop client
    dispatches ~5 parallel API calls on first login (splash → library
    fans out to /documents, /projects, /billing/status, /users/me,
    /voices). The previous check-then-insert pattern raced -- all
    requests passed the SELECT, then one won the INSERT and the rest
    returned 500 with UniqueViolationError on users_email_key (or
    users_auth0_user_id_key, depending on which constraint PostgreSQL
    evaluated first).

    Two unique constraints can race here -- ``(auth0_user_id)`` and
    ``(email)`` (the synthetic ``{sub}@auth0.local`` email is
    deterministic from the Cognito sub). Using ``ON CONFLICT DO
    NOTHING`` with no target column catches both atomically.
    """
    sub = claims.sub

    # Fast path: existing user. This SELECT runs on every authenticated
    # request, so we keep it ahead of the INSERT to avoid wasting an
    # INSERT-with-conflict on every call.
    result = await db.execute(
        text("SELECT id FROM users WHERE auth0_user_id = :sub"),
        {"sub": sub},
    )
    row = result.fetchone()
    if row is not None:
        return row[0]

    # First-login path: race-safe insert. ``ON CONFLICT DO NOTHING``
    # (no target) catches *any* unique-constraint violation -- both
    # ``users_auth0_user_id_key`` and ``users_email_key`` race for the
    # same logical conflict (both are deterministic from the Cognito
    # sub), and PostgreSQL doesn't guarantee which one fires first.
    new_id = uuid4()
    email = getattr(claims, "email", None) or f"{sub.replace('|', '_')}@auth0.local"
    display_name = getattr(claims, "name", None) or email.split("@")[0]
    now = datetime.now(UTC)

    insert_result = await db.execute(
        text(
            "INSERT INTO users (id, external_id, email, display_name, auth0_user_id, tier, is_active, created_at, updated_at) "
            "VALUES (:id, :external_id, :email, :display_name, :auth0_user_id, 'free', true, :now, :now) "
            "ON CONFLICT DO NOTHING "
            "RETURNING id"
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
    inserted = insert_result.fetchone()
    await db.flush()

    if inserted is not None:
        logger.info("user.provisioned", auth0_sub=sub, user_id=str(new_id))
        return inserted[0]

    # ON CONFLICT fired -- another concurrent request inserted the
    # canonical row first. Re-fetch by auth0_user_id (the canonical
    # lookup key). Under READ COMMITTED, the winning transaction must
    # have committed for the conflict to apply, so this SELECT sees
    # the row.
    result = await db.execute(
        text("SELECT id FROM users WHERE auth0_user_id = :sub"),
        {"sub": sub},
    )
    row = result.fetchone()
    if row is not None:
        logger.info(
            "user.provision_race_recovered",
            auth0_sub=sub,
            user_id=str(row[0]),
        )
        return row[0]

    # Defensive: ON CONFLICT fired but no row matches the auth0_user_id.
    # This means the conflict was on a different constraint -- most
    # likely ``users_email_key`` because a *different* user has the
    # same email (real email collision, not a synthetic-email race).
    # Surface as 500 with a specific log so the operator can
    # disambiguate from the latent race condition.
    logger.error(
        "user.provision_email_collision",
        auth0_sub=sub,
        attempted_email=email,
    )
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not provision user: email conflict with existing account.",
    )


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


# ── Billing / Plan Dependencies ────────────────────────────────────────

@dataclass(frozen=True)
class UserPlan:
    """Resolved plan for the current user."""

    plan: str          # "free", "reading_nook_pro", "creative_nook_pro"
    status: str        # "active", "trialing", "past_due", "canceled", "none"
    lookup_key: str    # raw lookup_key from subscriptions table, or ""


async def get_user_plan(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
) -> UserPlan:
    """Return the current user's plan. Never raises — defaults to free.

    Queries the Stripe billing tables (stripe_customers → subscriptions)
    for the most recent subscription. Maps the lookup_key to a plan name.
    """
    row = await db.execute(
        text("SELECT id FROM stripe_customers WHERE user_id = :uid"),
        {"uid": user_id},
    )
    sc = row.fetchone()
    if not sc:
        return UserPlan(plan="free", status="none", lookup_key="")

    result = await db.execute(
        text(
            "SELECT lookup_key, status FROM subscriptions "
            "WHERE stripe_customer_id = :sc_id "
            "ORDER BY created_at DESC LIMIT 1"
        ),
        {"sc_id": sc[0]},
    )
    sub = result.mappings().first()
    if not sub or sub["status"] == "canceled":
        return UserPlan(plan="free", status=sub["status"] if sub else "none", lookup_key="")

    lookup_key = sub["lookup_key"]
    plan = _lookup_key_to_plan(lookup_key)
    return UserPlan(plan=plan, status=sub["status"], lookup_key=lookup_key)


async def require_active_subscription(
    user_plan: UserPlan = Depends(get_user_plan),
) -> UserPlan:
    """Dependency that gates a route to users with an active subscription.

    Raises 403 if the user has no active or trialing subscription.
    Returns the UserPlan on success so the route can inspect plan details.
    """
    if user_plan.status not in ("active", "trialing"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "message": "Pro subscription required",
                "upgrade_url": "/billing/checkout-session",
            },
        )
    return user_plan


def _lookup_key_to_plan(lookup_key: str) -> str:
    """Map a Stripe lookup_key to the internal plan identifier.

    Stripe-side lookup keys still use the legacy ``creativity_nook_pro``
    prefix (must match Stripe Dashboard); internally we've renamed the
    plan to ``creative_nook_pro`` for the Beta launch.
    """
    if lookup_key.startswith("reading_nook_pro"):
        return "reading_nook_pro"
    if lookup_key.startswith("creativity_nook_pro"):
        return "creative_nook_pro"
    return "free"


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
