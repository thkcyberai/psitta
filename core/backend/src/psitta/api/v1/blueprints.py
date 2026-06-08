"""Psitta — Blueprints API (read surface, Phase 2B).

Read-only endpoints over the Blueprint feature:

  - ``GET /blueprints/``              list visible blueprints (summary)
  - ``GET /blueprints/{blueprint_id}``  one blueprint with its nested parts tree

Visibility is enforced in the service: a caller sees system templates plus
their own blueprints. A foreign or absent blueprint is an identical 404 (no
existence disclosure). No writes, no audit on reads. The prefix/tags are
declared here and the router is mounted bare in ``api/v1/router.py`` (mirrors
``projects.py``).
"""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.schemas.api import BlueprintDetail, BlueprintSummary
from psitta.services import blueprint_service

router = APIRouter(prefix="/blueprints", tags=["blueprints"])


@router.get("/", response_model=list[BlueprintSummary])
async def list_blueprints(
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """List blueprints visible to the caller (system templates + own)."""
    return await blueprint_service.list_blueprints(db, user_id)


@router.get("/{blueprint_id}", response_model=BlueprintDetail)
async def get_blueprint(
    blueprint_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Return one visible blueprint with its nested parts tree, else 404."""
    result = await blueprint_service.get_blueprint(db, user_id, blueprint_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    blueprint, parts_tree = result
    summary = BlueprintSummary.model_validate(blueprint)
    return BlueprintDetail(**summary.model_dump(), parts=parts_tree)
