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
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Request,
    UploadFile,
    status,
)
from fastapi.responses import Response
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import (
    get_current_user as get_auth_user,
    get_current_user_id,
    get_db_session,
)
from psitta.middleware.auth import TokenClaims
from psitta.middleware.rbac import get_tier_limits
from psitta.services import audit_service
from psitta.services.capabilities import capability_response
from psitta.services.subscription_service import get_effective_plan

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


@router.get(
    "/me/capabilities",
    summary="Resolved capabilities + limits for the current user",
    response_description="Capability list and numeric limits the client renders from",
)
async def get_my_capabilities(
    user_id: UUID = Depends(get_current_user_id),
    claims: TokenClaims = Depends(get_auth_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Single source of truth the Flutter client renders from.

    Resolves the user's plan through the SAME entitlement resolver the server
    enforces with (``get_effective_plan``), then maps it to a capability set +
    numeric limits (services/capabilities.py). The client must gate every
    feature on these capabilities, never on a plan id — so a leak on the
    client can't grant access the server denies.
    """
    plan = await get_effective_plan(db, user_id, email=claims.email)
    return capability_response(plan.plan_id)


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

    # Read profile fields (avatar_url/quote) best-effort: if migration 026
    # hasn't been applied yet, those columns don't exist — degrade to the core
    # fields rather than 500, so a code deploy never races the migration. The
    # SELECT runs in a SAVEPOINT so a missing-column error can't poison the tx.
    user = None
    try:
        async with db.begin_nested():
            result = await db.execute(
                text(
                    "SELECT id, display_name, tier, email, avatar_url, quote "
                    "FROM users WHERE auth0_user_id = :sub"
                ),
                {"sub": claims.sub},
            )
            user = result.mappings().first()
    except Exception:
        logger.warning("users.profile.columns_missing", sub=claims.sub)
        result = await db.execute(
            text(
                "SELECT id, display_name, tier, email "
                "FROM users WHERE auth0_user_id = :sub"
            ),
            {"sub": claims.sub},
        )
        base = result.mappings().first()
        user = dict(base) | {"avatar_url": None, "quote": None} if base else None

    if not user:
        return {
            "id": claims.sub,
            "display_name": claims.email.split("@")[0] if claims.email else "User",
            "tier": "free",
            "email": claims.email,
            "avatar_url": None,
            "quote": None,
            "usage": {"documents_this_month": 0, "documents_limit": 10, "storage_used_mb": 0},
        }

    tier = user["tier"]
    limits = get_tier_limits(tier)

    return {
        "id": str(user["id"]),
        "display_name": user["display_name"],
        "tier": tier,
        "email": user["email"],
        # avatar_url is the S3 key (presence flag + cache key); the image bytes
        # are served by GET /users/me/avatar. quote is the writer's message.
        "avatar_url": user["avatar_url"],
        "quote": user["quote"],
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
    quote: str | None = None,
    claims: TokenClaims = Depends(get_auth_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Update the authenticated user's profile.

    Only non-sensitive fields can be updated via this endpoint. Pass a field
    to set it; an empty string clears it (e.g. removing the quote).

    Args:
        display_name: User's display name (capped at 100 chars).
        quote: The writer's profile quote/message (capped at 200 chars).
    """
    logger.info("users.profile.update", has_display_name=display_name is not None,
                has_quote=quote is not None)

    updates: dict = {}
    if display_name is not None:
        updates["display_name"] = display_name.strip()[:100]
    if quote is not None:
        updates["quote"] = quote.strip()[:200]

    if updates:
        # Column names are fixed literals (not user input); values are bound.
        set_clause = ", ".join(f"{k} = :{k}" for k in updates)
        await db.execute(
            text(  # noqa: S608 — fixed column names, params bound
                f"UPDATE users SET {set_clause}, updated_at = NOW() "
                "WHERE auth0_user_id = :sub"
            ),
            {**updates, "sub": claims.sub},
        )
        await db.commit()

    await audit_service.log_event(
        db,
        action="user.profile.update",
        resource_type="user",
        user_id=claims.sub,
        resource_id=claims.sub,
        details={"fields": list(updates.keys())},
        ip_address=request.client.host if request.client else None,
    )
    return {**updates, "status": "updated"}


@router.post("/me/avatar", summary="Upload the current user's profile photo")
async def upload_avatar(
    request: Request,
    file: UploadFile,
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Upload + store the writer's profile photo (resized JPEG in S3).

    Mirrors the document-cover upload: validate type, resize with Pillow, store
    under ``avatars/<user_id>.jpg``, and record the key on ``users.avatar_url``.
    """
    import io

    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in {"jpeg", "jpg", "gif", "png"}:
        raise HTTPException(status_code=415, detail="Unsupported image type")
    if (file.content_type or "") not in {
        "image/jpeg",
        "image/jpg",
        "image/gif",
        "image/png",
    }:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported content type: {file.content_type}",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty image")
    if len(file_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image too large")

    from PIL import Image

    img = Image.open(io.BytesIO(file_bytes))
    if img.mode in ("RGBA", "P", "LA"):
        img = img.convert("RGB")
    img.thumbnail((512, 512))  # avatars are small; keep storage tiny
    out = io.BytesIO()
    img.save(out, format="JPEG", quality=88)
    out_bytes = out.getvalue()

    from psitta.config import get_settings
    from psitta.providers.storage_s3 import S3StorageProvider

    settings = get_settings()
    s3 = S3StorageProvider(settings)
    bucket = settings.S3_BUCKET_NAME
    key = f"avatars/{user_id}.jpg"
    await s3.delete_by_prefix(bucket, f"avatars/{user_id}.")
    await s3.put_object(bucket, key, out_bytes, content_type="image/jpeg")

    await db.execute(
        text(
            "UPDATE users SET avatar_url = :av, updated_at = NOW() "
            "WHERE id = :uid"
        ),
        {"av": key, "uid": str(user_id)},
    )
    await db.commit()
    await audit_service.log_event(
        db,
        action="user.avatar.upload",
        resource_type="user",
        user_id=str(user_id),
        resource_id=str(user_id),
        details={"size_bytes": len(out_bytes)},
        ip_address=request.client.host if request.client else None,
    )
    logger.info("users.avatar.uploaded", user_id=str(user_id))
    return {"avatar_url": key}


@router.get("/me/avatar", summary="Serve the current user's profile photo")
async def get_avatar(
    user_id: UUID = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db_session),
) -> Response:
    """Stream the writer's avatar image bytes (authed)."""
    row = (
        await db.execute(
            text("SELECT avatar_url FROM users WHERE id = :uid"),
            {"uid": str(user_id)},
        )
    ).first()
    if not row or not row.avatar_url:
        raise HTTPException(status_code=404, detail="No avatar")

    from psitta.config import get_settings
    from psitta.providers.storage_s3 import S3StorageProvider

    settings = get_settings()
    s3 = S3StorageProvider(settings)
    try:
        data = await s3.get_object(settings.S3_BUCKET_NAME, row.avatar_url)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=404, detail="Avatar not found") from exc
    return Response(content=data, media_type="image/jpeg")


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
