"""
Psitta — Authentication Routes.

Handles post-login user provisioning and audit logging.
The actual JWT validation is handled by the auth middleware;
this module handles the first-login user creation flow.
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, Request
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import uuid4

from psitta.dependencies import get_current_user, get_db_session
from psitta.middleware.auth import TokenClaims
from psitta.services.audit_service import log_event

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


@router.post(
    "/login",
    summary="Post-login hook — provision user and log event",
    response_description="User profile after login",
)
async def post_login(
    request: Request,
    claims: TokenClaims = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Called by the client after Auth0 login to:

    1. Create the user record if this is their first login
    2. Update auth0_user_id mapping
    3. Record an audit log entry for the login event
    """
    auth0_sub = claims.sub
    email = claims.email

    # Check if user already exists
    result = await db.execute(
        text("SELECT id, display_name, tier FROM users WHERE auth0_user_id = :sub"),
        {"sub": auth0_sub},
    )
    user_row = result.mappings().first()

    client_ip = request.client.host if request.client else None

    if user_row:
        # Existing user — log login event
        user_id = str(user_row["id"])
        await log_event(
            db,
            action="user.login",
            resource_type="user",
            user_id=auth0_sub,
            resource_id=user_id,
            details={"email": email, "method": "auth0"},
            ip_address=client_ip,
        )
        await db.commit()

        logger.info("auth.login.existing", sub=auth0_sub, user_id=user_id)
        return {
            "id": user_id,
            "display_name": user_row["display_name"],
            "tier": user_row["tier"],
            "email": email,
            "is_new_user": False,
        }

    # New user — provision account
    user_id = str(uuid4())
    display_name = email.split("@")[0] if email else "User"

    await db.execute(
        text(
            "INSERT INTO users (id, external_id, auth0_user_id, email, display_name, tier) "
            "VALUES (:id, :ext_id, :auth0_id, :email, :name, 'free')"
        ),
        {
            "id": user_id,
            "ext_id": auth0_sub,
            "auth0_id": auth0_sub,
            "email": email,
            "name": display_name,
        },
    )

    await log_event(
        db,
        action="user.signup",
        resource_type="user",
        user_id=auth0_sub,
        resource_id=user_id,
        details={"email": email, "method": "auth0", "tier": "free"},
        ip_address=client_ip,
    )
    await db.commit()

    logger.info("auth.login.new_user", sub=auth0_sub, user_id=user_id)
    return {
        "id": user_id,
        "display_name": display_name,
        "tier": "free",
        "email": email,
        "is_new_user": True,
    }
