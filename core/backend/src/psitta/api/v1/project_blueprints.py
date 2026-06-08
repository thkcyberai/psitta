"""Psitta — Project ↔ Blueprint adoption API (Phase 2E).

Endpoints under ``/projects/{project_id}/blueprints/`` that let a project adopt
user-owned blueprints and choose one primary:

  - ``GET    /projects/{id}/blueprints/``               list adopted (primary-first)
  - ``POST   /projects/{id}/blueprints/``               adopt a blueprint
  - ``PATCH  /projects/{id}/blueprints/{blueprint_id}`` set/clear primary
  - ``DELETE /projects/{id}/blueprints/{blueprint_id}`` un-adopt (link removal)

Kept in its own module (router mounted bare, prefix ``/projects``) so the
Blueprint feature stays self-contained rather than bloating ``projects.py``.
Project ownership reuses ``projects._get_project_or_404`` (the ``projects`` table
is unmapped, queried via raw SQL). Adoption logic lives in ``blueprint_service``.

Auth/validation: project not owned/absent → 404; blueprint absent or foreign →
404; a SYSTEM template → 400 (clone first); duplicate adoption → 409; a
PATCH/DELETE on a non-adopted blueprint → 404.
"""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.api.v1.projects import _get_project_or_404
from psitta.dependencies import get_current_user_id, get_db_session
from psitta.models.blueprint import Blueprint
from psitta.schemas.api import (
    AdoptedBlueprint,
    ProjectBlueprintAdopt,
    ProjectBlueprintSetPrimary,
)
from psitta.services import blueprint_service

router = APIRouter(prefix="/projects", tags=["project-blueprints"])


def _client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


async def _get_adoptable_blueprint_or_error(
    db: AsyncSession, user_id: UUID, blueprint_id: UUID
) -> Blueprint:
    """Resolve a blueprint that the caller may adopt into a project.

    Absent or foreign (a user blueprint owned by someone else) → 404 (no
    existence disclosure). A SYSTEM template is visible but NOT adoptable → 400
    (clone it first), consistent with the clone-on-use rule. Only the caller's
    own user blueprint passes.
    """
    blueprint = await blueprint_service.load_blueprint_by_id(db, blueprint_id)
    if blueprint is None:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    if blueprint.is_system or blueprint.user_id is None:
        raise HTTPException(
            status_code=400,
            detail="System templates must be cloned before adoption",
        )
    if blueprint.user_id != user_id:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    return blueprint


@router.get("/{project_id}/blueprints/", response_model=list[AdoptedBlueprint])
async def list_adopted_blueprints(
    project_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """List the blueprints adopted by a project (primary-first). 404 if the
    project is absent or not owned by the caller."""
    await _get_project_or_404(str(project_id), str(user_id), db)
    return await blueprint_service.list_project_blueprints(db, project_id)


@router.post(
    "/{project_id}/blueprints/",
    response_model=AdoptedBlueprint,
    status_code=201,
)
async def adopt_blueprint(
    project_id: UUID,
    data: ProjectBlueprintAdopt,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Adopt a user-owned blueprint into a project. 404 project/blueprint, 400
    on a system template, 409 if already adopted. First adoption is primary."""
    await _get_project_or_404(str(project_id), str(user_id), db)
    blueprint = await _get_adoptable_blueprint_or_error(
        db, user_id, data.blueprint_id
    )
    try:
        return await blueprint_service.adopt_blueprint(
            db,
            user_id,
            project_id,
            blueprint,
            request_primary=data.is_primary,
            ip_address=_client_ip(request),
        )
    except blueprint_service.AlreadyAdoptedError as exc:
        raise HTTPException(
            status_code=409,
            detail="Blueprint already adopted by this project",
        ) from exc


@router.patch(
    "/{project_id}/blueprints/{blueprint_id}",
    response_model=AdoptedBlueprint,
)
async def set_primary_blueprint(  # noqa: PLR0913 -- FastAPI route: two path params + body + request + two injected deps; none are removable
    project_id: UUID,
    blueprint_id: UUID,
    data: ProjectBlueprintSetPrimary,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Set or clear which adopted blueprint is the project's primary. 404 if the
    project is not owned or the blueprint is not adopted."""
    await _get_project_or_404(str(project_id), str(user_id), db)
    try:
        return await blueprint_service.set_primary_blueprint(
            db,
            user_id,
            project_id,
            blueprint_id,
            is_primary=data.is_primary,
            ip_address=_client_ip(request),
        )
    except blueprint_service.NotAdoptedError as exc:
        raise HTTPException(
            status_code=404, detail="Blueprint not adopted by this project"
        ) from exc


@router.delete(
    "/{project_id}/blueprints/{blueprint_id}", status_code=204
)
async def unadopt_blueprint(
    project_id: UUID,
    blueprint_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Un-adopt a blueprint from a project (plain link removal). 404 if the
    project is not owned or the blueprint is not adopted."""
    await _get_project_or_404(str(project_id), str(user_id), db)
    try:
        await blueprint_service.unadopt_blueprint(
            db, user_id, project_id, blueprint_id, ip_address=_client_ip(request)
        )
    except blueprint_service.NotAdoptedError as exc:
        raise HTTPException(
            status_code=404, detail="Blueprint not adopted by this project"
        ) from exc
