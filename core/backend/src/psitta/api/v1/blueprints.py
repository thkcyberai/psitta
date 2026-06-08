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

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.models.blueprint import Blueprint, BlueprintPart, PartDocument
from psitta.schemas.api import (
    BlueprintCloneRequest,
    BlueprintCreate,
    BlueprintDetail,
    BlueprintSummary,
    BlueprintUpdate,
    PartCreate,
    PartDetail,
    PartDocumentPlace,
    PartDocumentPlacement,
    PartUpdate,
)
from psitta.services import blueprint_service

router = APIRouter(prefix="/blueprints", tags=["blueprints"])


def _client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


async def _get_owned_blueprint_or_error(
    db: AsyncSession, user_id: UUID, blueprint_id: UUID
) -> Blueprint:
    """Load a blueprint for write, enforcing the write-access rules.

    Intentional divergence from the read 404-only rule: a **system template**
    (read-only) returns **403**, while a **user blueprint owned by someone
    else** returns **404** (no existence disclosure), and an absent id is 404.
    The HTTP mapping lives here in the route, not in the service.
    """
    blueprint = await blueprint_service.load_blueprint_by_id(db, blueprint_id)
    if blueprint is None:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    if blueprint.is_system or blueprint.user_id is None:
        raise HTTPException(
            status_code=403, detail="System templates are read-only"
        )
    if blueprint.user_id != user_id:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    return blueprint


async def _get_owned_part_or_error(
    db: AsyncSession, user_id: UUID, blueprint_id: UUID, part_id: UUID
) -> tuple[Blueprint, BlueprintPart]:
    """Authorize the blueprint (403 system / 404 foreign), then load the part.

    A part id that is absent or belongs to a different blueprint is a 404 — same
    no-existence-disclosure rule as the blueprint guard.
    """
    blueprint = await _get_owned_blueprint_or_error(db, user_id, blueprint_id)
    part = await blueprint_service.load_part_by_id(db, blueprint_id, part_id)
    if part is None:
        raise HTTPException(status_code=404, detail="Part not found")
    return blueprint, part


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


@router.post("/", response_model=BlueprintSummary, status_code=201)
async def create_blueprint(
    data: BlueprintCreate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Create a new, empty user-owned blueprint."""
    return await blueprint_service.create_blueprint(
        db, user_id, data, ip_address=_client_ip(request)
    )


@router.post(
    "/{blueprint_id}/clone/", response_model=BlueprintDetail, status_code=201
)
async def clone_blueprint(
    blueprint_id: UUID,
    request: Request,
    body: BlueprintCloneRequest | None = None,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Clone a visible blueprint (system or own) into a user-owned copy.

    Cloning a foreign or absent blueprint is a 404; system templates clone.
    """
    result = await blueprint_service.clone_blueprint(
        db,
        user_id,
        blueprint_id,
        name=body.name if body else None,
        ip_address=_client_ip(request),
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Blueprint not found")
    blueprint, parts_tree = result
    summary = BlueprintSummary.model_validate(blueprint)
    return BlueprintDetail(**summary.model_dump(), parts=parts_tree)


@router.patch("/{blueprint_id}", response_model=BlueprintSummary)
async def update_blueprint(
    blueprint_id: UUID,
    data: BlueprintUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Update a user blueprint. 403 if system, 404 if not owned by the caller."""
    blueprint = await _get_owned_blueprint_or_error(db, user_id, blueprint_id)
    return await blueprint_service.update_blueprint(
        db, user_id, blueprint, data, ip_address=_client_ip(request)
    )


@router.delete("/{blueprint_id}", status_code=204)
async def delete_blueprint(
    blueprint_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Delete a user blueprint (parts cascade). 403 if system, 404 if not owned."""
    blueprint = await _get_owned_blueprint_or_error(db, user_id, blueprint_id)
    await blueprint_service.delete_blueprint(
        db, user_id, blueprint, ip_address=_client_ip(request)
    )


# ── Parts (2D) ─────────────────────────────────────────────────────────────
# All part writes go through the blueprint guard first (403 system / 404 foreign
# or absent). Service-level validation failures (cross-blueprint parent, a cycle,
# or a bad after_part_id) surface as 400.


@router.post(
    "/{blueprint_id}/parts/", response_model=PartDetail, status_code=201
)
async def create_part(
    blueprint_id: UUID,
    data: PartCreate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Add a part to a user blueprint. 403 if system, 404 if not owned, 400 on
    a cross-blueprint parent or a bad after_part_id."""
    blueprint = await _get_owned_blueprint_or_error(db, user_id, blueprint_id)
    try:
        return await blueprint_service.create_part(
            db, user_id, blueprint, data, ip_address=_client_ip(request)
        )
    except blueprint_service.PartValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.patch(
    "/{blueprint_id}/parts/{part_id}", response_model=PartDetail
)
async def update_part(  # noqa: PLR0913 -- FastAPI route: two path params + body + request + two injected deps; none are removable
    blueprint_id: UUID,
    part_id: UUID,
    data: PartUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Edit fields and/or reorder/nest a part. 403 if system, 404 if not owned,
    400 on a cycle, cross-blueprint parent, or a bad after_part_id."""
    blueprint, part = await _get_owned_part_or_error(
        db, user_id, blueprint_id, part_id
    )
    try:
        return await blueprint_service.update_part(
            db, user_id, blueprint, part, data, ip_address=_client_ip(request)
        )
    except blueprint_service.PartValidationError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.delete(
    "/{blueprint_id}/parts/{part_id}", status_code=204
)
async def delete_part(
    blueprint_id: UUID,
    part_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Delete a part; its subtree cascades at the DB. 403 if system, 404 if not
    owned or the part is not in this blueprint."""
    blueprint, part = await _get_owned_part_or_error(
        db, user_id, blueprint_id, part_id
    )
    await blueprint_service.delete_part(
        db, user_id, blueprint, part, ip_address=_client_ip(request)
    )


# ── Document placement (2F) ─────────────────────────────────────────────────
# Routes under /documents/{document_id}/placement live HERE (not in documents.py)
# so the Blueprint feature stays self-contained. This second router carries the
# /documents prefix and is mounted bare alongside the /blueprints router.
#
# Auth/validation matrix: document foreign/absent/soft-deleted -> 404; document
# with no project -> 422; part absent -> 404; the part's blueprint a SYSTEM
# template -> 400 (clone first, consistent with 2E); the part's blueprint foreign
# -> 404; bad role -> 422 (RoleEnum). Placement is an idempotent assign-or-move
# that auto-adopts the part's blueprint into the project, atomically.

placement_router = APIRouter(prefix="/documents", tags=["placement"])


async def _get_placeable_document_or_error(
    db: AsyncSession, user_id: UUID, document_id: UUID
) -> dict:
    """Load a document for placement, enforcing the placement preconditions.

    Foreign or absent -> 404 (no existence disclosure). Soft-deleted (``status =
    'deleted'``) -> 404, identical to the rest of the documents API which hides
    deleted rows from their owner; the placement row (if any) is preserved and
    restored when the document is un-deleted. No project -> 422. Returns the
    document row (id + project_id) on success.
    """
    user_id_str = str(user_id)
    row = await db.execute(
        text("SELECT id, user_id, project_id, status FROM documents WHERE id = :id"),
        {"id": str(document_id)},
    )
    doc = row.mappings().first()
    if not doc or str(doc["user_id"]) != user_id_str:
        raise HTTPException(status_code=404, detail="Document not found")
    if doc["status"] == "deleted":
        raise HTTPException(status_code=404, detail="Document not found")
    if doc["project_id"] is None:
        raise HTTPException(
            status_code=422,
            detail="Document must belong to a project before it can be placed",
        )
    return dict(doc)


async def _get_adoptable_part_or_error(
    db: AsyncSession, user_id: UUID, part_id: UUID
) -> tuple[BlueprintPart, Blueprint]:
    """Resolve a part the caller may place a document into.

    Absent part -> 404. The part's blueprint is then authorized exactly like 2E
    adoption: a SYSTEM template -> 400 (clone first), a foreign user blueprint (or
    a defensively absent one) -> 404. Only a caller-owned user blueprint passes.
    """
    part = await blueprint_service.load_part_global(db, part_id)
    if part is None:
        raise HTTPException(status_code=404, detail="Part not found")
    blueprint = await blueprint_service.load_blueprint_by_id(db, part.blueprint_id)
    if blueprint is None:
        raise HTTPException(status_code=404, detail="Part not found")
    if blueprint.is_system or blueprint.user_id is None:
        raise HTTPException(
            status_code=400,
            detail="System templates must be cloned before placing documents",
        )
    if blueprint.user_id != user_id:
        raise HTTPException(status_code=404, detail="Part not found")
    return part, blueprint


def _placement_response(
    placement: PartDocument, blueprint_id: UUID
) -> PartDocumentPlacement:
    """Compose the placement response (placement row + its blueprint id)."""
    return PartDocumentPlacement(
        id=placement.id,
        document_id=placement.document_id,
        part_id=placement.part_id,
        blueprint_id=blueprint_id,
        role=placement.role,
        sort_order=float(placement.sort_order),
    )


@placement_router.put(
    "/{document_id}/placement", response_model=PartDocumentPlacement
)
async def place_document(  # noqa: PLR0913 -- FastAPI route: path param + body + request + response + two injected deps; none are removable
    document_id: UUID,
    data: PartDocumentPlace,
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Assign-or-move a document into a part; auto-adopt the part's blueprint.

    201 when the document is newly placed, 200 when an existing placement is
    moved (or its role refreshed). See the module-level matrix for error codes.
    """
    doc = await _get_placeable_document_or_error(db, user_id, document_id)
    part, blueprint = await _get_adoptable_part_or_error(db, user_id, data.part_id)
    placement, created = await blueprint_service.place_document(
        db,
        user_id,
        document_id=document_id,
        project_id=doc["project_id"],
        part=part,
        blueprint_id=blueprint.id,
        role=data.role.value,
        ip_address=_client_ip(request),
    )
    response.status_code = 201 if created else 200
    return _placement_response(placement, blueprint.id)


@placement_router.get(
    "/{document_id}/placement", response_model=PartDocumentPlacement
)
async def get_placement(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Return the document's current placement, or 404 if it is unplaced."""
    await _get_placeable_document_or_error(db, user_id, document_id)
    result = await blueprint_service.get_placement(db, document_id)
    if result is None:
        raise HTTPException(status_code=404, detail="Document is not placed")
    placement, blueprint_id = result
    return _placement_response(placement, blueprint_id)


@placement_router.delete("/{document_id}/placement", status_code=204)
async def unplace_document(
    document_id: UUID,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Un-place a document (remove its placement row). 404 if the document is not
    owned/active or has no placement. Never auto-un-adopts the blueprint."""
    await _get_placeable_document_or_error(db, user_id, document_id)
    removed = await blueprint_service.unplace_document(
        db, user_id, document_id, ip_address=_client_ip(request)
    )
    if not removed:
        raise HTTPException(status_code=404, detail="Document is not placed")
