"""
Psitta — Client control-plane config (public).

A single, unauthenticated endpoint the desktop client reads at startup to learn
what the SERVER says about client versions and feature availability:

  * minimum_supported_version — clients below this must upgrade to continue.
  * recommended_version       — soft nudge to update.
  * flags                     — feature flags / kill switches.

Public by design: an outdated client must be able to learn it needs to upgrade
even when its token is stale. Server-owned and changeable without a client
release (deploy != release). Fail-safe — serves permissive defaults if the
config store is unavailable, so a config fault never bricks the app.
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_db_session
from psitta.services.app_config import get_client_config

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()


@router.get(
    "/config",
    tags=["config"],
    summary="Client control-plane config (version floor + feature flags)",
    response_description="minimum_supported_version, recommended_version, flags",
)
async def get_config(db: AsyncSession = Depends(get_db_session)) -> dict:
    """Return the server-owned client control-plane config.

    Consumed by the client at startup to enforce a minimum version, surface an
    optional-update nudge, and toggle remotely-controlled features. Never
    raises — resolves fail-safe to permissive defaults.
    """
    return await get_client_config(db)
