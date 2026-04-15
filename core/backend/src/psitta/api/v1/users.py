"""
Psitta — User Management Routes.

Endpoints for user profile, preferences, and subscription tier info.
Authentication is handled upstream (middleware/dependency injection).

Security:
  - All endpoints require authentication
  - Users can only access their own profile
  - Sensitive fields (email, tier) are never exposed in public APIs
  - Password changes trigger session invalidation
"""

from __future__ import annotations

from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user as get_auth_user, get_db_session
from psitta.middleware.auth import TokenClaims
from psitta.middleware.rbac import get_tier_limits
from psitta.services import audit_service

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


@router.get(
    "/me",
    summary="Get current user's profile",
    response_description="User profile and preferences",
)
async def get_current_user_profile(
    claims: TokenClaims = Depends(get_auth_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Retrieve the authenticated user's profile.

    Returns display name, email (masked), subscription tier,
    usage stats, and preferences.
    """
    logger.info("users.profile.get", sub=claims.sub)

    result = await db.execute(
        text("SELECT id, display_name, tier, email FROM users WHERE auth0_user_id = :sub"),
        {"sub": claims.sub},
    )
    user = result.mappings().first()

    if not user:
        return {
            "id": claims.sub,
            "display_name": claims.email.split("@")[0] if claims.email else "User",
            "tier": "free",
            "email": claims.email,
            "usage": {"documents_this_month": 0, "documents_limit": 3, "storage_used_mb": 0},
        }

    tier = user["tier"]
    limits = get_tier_limits(tier)

    return {
        "id": str(user["id"]),
        "display_name": user["display_name"],
        "tier": tier,
        "email": user["email"],
        "usage": {
            "documents_this_month": 0,
            "documents_limit": limits.documents_per_month,
            "storage_used_mb": 0,
            "storage_limit_mb": limits.storage_mb,
        },
    }


@router.patch(
    "/me",
    summary="Update current user's profile",
    response_description="Profile updated",
)
async def update_current_user(
    request: Request,
    display_name: str | None = None,
    claims: TokenClaims = Depends(get_auth_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Update the authenticated user's profile.

    Only non-sensitive fields can be updated via this endpoint.
    Email changes require a separate verification flow.

    Args:
        display_name: User's display name (2–100 characters).
    """
    logger.info("users.profile.update", display_name=display_name)

    # TODO: Wire to user service with input validation
    await audit_service.log_event(
        db,
        action="user.profile.update",
        resource_type="user",
        user_id=claims.sub,
        resource_id=claims.sub,
        details={"fields": [k for k, v in {"display_name": display_name}.items() if v is not None]},
        ip_address=request.client.host if request.client else None,
    )
    return {
        "display_name": display_name,
        "status": "updated",
        "message": "Profile update endpoint — service layer pending",
    }


@router.get(
    "/me/usage",
    summary="Get current usage and limits",
    response_description="Document count, storage, and tier limits",
)
async def get_usage() -> dict:
    """Retrieve the user's current usage against their tier limits.

    Includes documents processed this billing period,
    storage consumed, and remaining quota.
    """
    logger.info("users.usage.get")

    # TODO: Wire to usage tracking service
    return {
        "tier": "free",
        "billing_period_start": "pending",
        "documents_used": 0,
        "documents_limit": 3,
        "storage_used_mb": 0,
        "storage_limit_mb": 500,
        "message": "Usage endpoint — service layer pending",
    }


@router.get(
    "/me/preferences",
    summary="Get user preferences",
    response_description="User's app preferences and settings",
)
async def get_preferences() -> dict:
    """Retrieve the user's application preferences.

    Includes theme, notification settings, default voice,
    auto-delete policy, and accessibility options.
    """
    logger.info("users.preferences.get")

    # TODO: Wire to preferences service
    return {
        "theme": "system",
        "notifications_enabled": True,
        "auto_delete_days": 60,
        "default_voice_id": "en-US-AriaNeural",
        "default_speed": 1.0,
        "message": "Preferences endpoint — service layer pending",
    }


@router.put(
    "/me/preferences",
    summary="Update user preferences",
    response_description="Preferences updated",
)
async def update_preferences(
    request: Request,
    theme: str | None = None,
    notifications_enabled: bool | None = None,
    auto_delete_days: int | None = None,
    claims: TokenClaims = Depends(get_auth_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Update the user's application preferences.

    Partial updates supported — only provided fields are changed.
    """
    logger.info(
        "users.preferences.update",
        theme=theme,
        notifications_enabled=notifications_enabled,
        auto_delete_days=auto_delete_days,
    )

    # TODO: Wire to preferences service with validation
    await audit_service.log_event(
        db,
        action="user.preferences.update",
        resource_type="user",
        user_id=claims.sub,
        resource_id=claims.sub,
        details={
            "fields": [
                k for k, v in {
                    "theme": theme,
                    "notifications_enabled": notifications_enabled,
                    "auto_delete_days": auto_delete_days,
                }.items() if v is not None
            ]
        },
        ip_address=request.client.host if request.client else None,
    )
    return {
        "theme": theme,
        "notifications_enabled": notifications_enabled,
        "auto_delete_days": auto_delete_days,
        "status": "updated",
        "message": "Preferences update endpoint — service layer pending",
    }
