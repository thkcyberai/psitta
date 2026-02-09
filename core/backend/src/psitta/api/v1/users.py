"""
User endpoints — profile, preferences, account deletion.
"""

from __future__ import annotations

from typing import Any

import structlog
from fastapi import APIRouter, Header, HTTPException, status
from sqlalchemy import select

from psitta.dependencies import CurrentUserId, DbSession
from psitta.models.domain import User
from psitta.schemas.api import ApiResponse, UserResponse, UserUpdateRequest

logger = structlog.get_logger()
router = APIRouter()


@router.get("/me", response_model=ApiResponse[UserResponse])
async def get_current_user(
    db: DbSession,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Get the current user's profile."""
    user = await _get_user(db, user_id)
    return {"data": UserResponse.model_validate(user)}


@router.patch("/me", response_model=ApiResponse[UserResponse])
async def update_user(
    body: UserUpdateRequest,
    db: DbSession,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Update the current user's profile or preferences."""
    user = await _get_user(db, user_id)

    if body.display_name is not None:
        user.display_name = body.display_name
    if body.preferences is not None:
        user.preferences = {**user.preferences, **body.preferences}

    await db.flush()
    logger.info("user_updated", user_id=user_id)
    return {"data": UserResponse.model_validate(user)}


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    db: DbSession,
    user_id: CurrentUserId,
    x_confirm_delete: str = Header(..., alias="X-Confirm-Delete"),
) -> None:
    """Delete the current user's account and all associated data."""
    if x_confirm_delete.lower() != "true":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account deletion requires X-Confirm-Delete: true header",
        )

    user = await _get_user(db, user_id)
    await db.delete(user)
    logger.warning("account_deleted", user_id=user_id)


async def _get_user(db: DbSession, external_id: str) -> User:
    """Fetch user by external auth provider ID."""
    result = await db.execute(
        select(User).where(User.external_id == external_id)
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user
