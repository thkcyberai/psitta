import json
import uuid
from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import bindparam, text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.schemas.api import (
    ActivityEvent,
    DocumentBeatUpdate,
    NarrativeCheckRequest,
    NarrativeCheckResponse,
    ProjectDetail,
    ProjectNarrativeUpdate,
    ProjectPlacement,
)
from psitta.services import audit_service

logger = structlog.get_logger(__name__)

router = APIRouter(prefix="/projects", tags=["projects"])


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_project_or_404(project_id: str, user_id: str, db: AsyncSession) -> dict:
    row = await db.execute(
        text("SELECT id, user_id, name, created_at, cover_document_id FROM projects WHERE id = :id"),
        {"id": project_id},
    )
    project = row.mappings().first()
    if not project or project["user_id"] != user_id:
        raise HTTPException(status_code=404, detail="Project not found")
    return dict(project)


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
async def create_project(
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    user_id = str(user_id)
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=422, detail="name is required")
    project_id = str(uuid.uuid4())
    await db.execute(
        text(
            "INSERT INTO projects (id, user_id, name) VALUES (:id, :uid, :name)"
        ),
        {"id": project_id, "uid": user_id, "name": name},
    )
    await db.commit()
    row = await db.execute(
        text("SELECT id, name, created_at FROM projects WHERE id = :id"),
        {"id": project_id},
    )
    project = dict(row.mappings().first())
    project["id"] = str(project["id"])
    project["created_at"] = project["created_at"].isoformat()
    project["document_count"] = 0
    project["cover_document_id"] = None
    project["cover_type"] = None
    project["cover_value"] = None
    await audit_service.log_event(
        db,
        action="project.create",
        resource_type="project",
        user_id=user_id,
        resource_id=project_id,
        details={"name": name},
        ip_address=request.client.host if request.client else None,
    )
    return project


@router.get("/")
async def list_projects(
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    user_id = str(user_id)
    rows = await db.execute(
        text("""
            SELECT p.id, p.name, p.created_at, p.cover_document_id,
                   COUNT(d.id) AS document_count,
                   cd.cover_type AS cover_doc_cover_type,
                   cd.cover_value AS cover_doc_cover_value
            FROM projects p
            LEFT JOIN documents d
                ON d.project_id = p.id AND d.status != 'deleted'
            LEFT JOIN documents cd
                ON cd.id = p.cover_document_id
            WHERE p.user_id = :uid
            GROUP BY p.id, p.name, p.created_at, p.cover_document_id,
                     cd.cover_type, cd.cover_value
            ORDER BY p.created_at DESC
        """),
        {"uid": user_id},
    )
    result = []
    for row in rows.mappings():
        result.append({
            "id": str(row["id"]),
            "name": row["name"],
            "created_at": row["created_at"].isoformat(),
            "document_count": row["document_count"],
            "cover_document_id": str(row["cover_document_id"]) if row["cover_document_id"] else None,
            "cover_type": row["cover_doc_cover_type"],
            "cover_value": row["cover_doc_cover_value"],
        })
    return result


@router.get("/{project_id}", response_model=ProjectDetail)
async def get_project(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Aggregated detail for one owned project (Phase 5, read-only).

    Owner-guarded via ``_get_project_or_404`` (absent / not-owned → 404), then a
    single aggregate over existing columns: non-deleted document count, adopted
    blueprint count, and the sum of word_count over non-deleted documents (0 when
    none). No schema change.
    """
    await _get_project_or_404(project_id, str(user_id), db)
    row = await db.execute(
        text("""
            SELECT
                p.id, p.name, p.user_id, p.created_at, p.updated_at,
                p.narrative_structure_key, p.narrative_variant,
                p.narrative_beats,
                (SELECT COUNT(*) FROM documents d
                   WHERE d.project_id = p.id AND d.status != 'deleted')
                    AS document_count,
                (SELECT COUNT(*) FROM project_blueprints pb
                   WHERE pb.project_id = p.id) AS blueprint_count,
                COALESCE((SELECT SUM(d2.word_count) FROM documents d2
                   WHERE d2.project_id = p.id AND d2.status != 'deleted'), 0)
                    AS total_words
            FROM projects p
            WHERE p.id = :id
        """),
        {"id": project_id},
    )
    r = row.mappings().first()
    return ProjectDetail(
        id=r["id"],
        name=r["name"],
        user_id=r["user_id"],
        created_at=r["created_at"],
        updated_at=r["updated_at"],
        document_count=r["document_count"],
        blueprint_count=r["blueprint_count"],
        total_words=r["total_words"],
        narrative_structure_key=r["narrative_structure_key"],
        narrative_variant=r["narrative_variant"],
        narrative_beats=r["narrative_beats"],
    )


@router.patch("/{project_id}")
async def update_project(
    project_id: str,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    await _get_project_or_404(project_id, str(user_id), db)

    set_parts: list[str] = []
    params: dict = {"id": project_id}

    if "name" in body:
        name = (body["name"] or "").strip()
        if not name:
            raise HTTPException(status_code=422, detail="name is required")
        set_parts.append("name = :name")
        params["name"] = name

    if "cover_document_id" in body:
        cover_doc_id = body["cover_document_id"]
        if cover_doc_id is not None:
            # Verify the document exists
            doc_row = await db.execute(
                text("SELECT id FROM documents WHERE id = :did AND status != 'deleted'"),
                {"did": cover_doc_id},
            )
            if not doc_row.first():
                raise HTTPException(status_code=404, detail="Cover document not found")
        set_parts.append("cover_document_id = :cover_doc_id")
        params["cover_doc_id"] = cover_doc_id

    if not set_parts:
        raise HTTPException(status_code=400, detail="No fields to update")

    set_parts.append("updated_at = now()")
    set_clause = ", ".join(set_parts)

    await db.execute(
        text(f"UPDATE projects SET {set_clause} WHERE id = :id"),
        params,
    )
    await db.commit()

    logger.info("project.updated", project_id=project_id, fields=list(body.keys()))
    await audit_service.log_event(
        db,
        action="project.update",
        resource_type="project",
        user_id=str(user_id),
        resource_id=project_id,
        details={"fields": list(body.keys())},
        ip_address=request.client.host if request.client else None,
    )
    return {"id": project_id, **{k: v for k, v in body.items() if k in ("name", "cover_document_id")}}


@router.put("/{project_id}/narrative", response_model=ProjectDetail)
async def set_project_narrative(
    project_id: str,
    data: ProjectNarrativeUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Set (or clear) this project's chosen narrative. Owner-guarded; the
    narrative lives on the project, never as Book Structure sections."""
    await _get_project_or_404(project_id, str(user_id), db)
    beats_json = (
        json.dumps(data.narrative_beats)
        if data.narrative_beats is not None
        else None
    )
    await db.execute(
        text(
            """
            UPDATE projects
            SET narrative_structure_key = :k,
                narrative_variant = :v,
                narrative_beats = CAST(:b AS JSONB),
                updated_at = now()
            WHERE id = :id
            """
        ),
        {
            "k": data.narrative_structure_key,
            "v": data.narrative_variant,
            "b": beats_json,
            "id": project_id,
        },
    )
    await db.commit()
    await audit_service.log_event(
        db,
        action="project.set_narrative",
        resource_type="project",
        user_id=str(user_id),
        resource_id=project_id,
        details={
            "structure_key": data.narrative_structure_key,
            "variant": data.narrative_variant,
            "beats": len(data.narrative_beats or []),
        },
        ip_address=request.client.host if request.client else None,
    )
    return await get_project(project_id=project_id, db=db, user_id=user_id)


@router.post("/{project_id}/narrative/check", response_model=NarrativeCheckResponse)
async def check_project_narrative(
    project_id: str,
    data: NarrativeCheckRequest,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> NarrativeCheckResponse:
    """AI Story-Coach — judge whether a drafted passage fits this project's
    committed narrative (Writing Nook Pro / Creative Nook Pro).

    Owner-guarded (404 if absent/not-owned). 422 if the project has no
    narrative attached. Quota-gated against llm_usage_counters: 403 if the plan
    has no LLM access, 402 if the period quota is exhausted. Privacy-safe — the
    passage is sent to the LLM for judging but is never logged or audited.
    """
    from psitta.services.narrative_coach_service import check_narrative_with_quota

    try:
        pid = UUID(project_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail="Project not found") from exc

    result = await check_narrative_with_quota(
        db,
        user_id,
        pid,
        passage=data.passage,
        beat_index=data.beat_index,
    )
    return NarrativeCheckResponse(**result)


# ── Activity feed ───────────────────────────────────────────────────────────

# Curated allowlist of audit actions surfaced in the project Activity feed.
# Deliberately excludes read/noise events (*.fetched, *.streamed, per-chunk
# saves, billing, auth) so the feed stays a meaningful project timeline.
_ACTIVITY_ACTIONS: list[str] = [
    "project.create",
    "project.update",
    "project.set_narrative",
    "document.create_blank",
    "document.upload",
    "document.update",
    "document.delete",
    "document.restore",
    "document.archive",
    "document.assign_project",
    "document.duplicate",
    "document.summarized",
    "document.set_narrative_beat",
    "recording.create",
]


def _activity_entry(
    action: str,
    doc_title: str | None,
    details: dict,
    project_name: str,
) -> tuple[str, str]:
    """Map a raw audit row to a (kind, human-summary) pair. Surfaces only safe,
    curated text — never raw audit details."""
    title = doc_title or (details.get("title") if isinstance(details, dict) else None)
    title = title or "a file"
    quoted = f'“{title}”'

    if action == "project.create":
        return ("project", f'Created the project “{project_name}”')
    if action == "project.update":
        fields = details.get("fields") if isinstance(details, dict) else None
        if isinstance(fields, list) and "name" in fields:
            return ("project", "Renamed the project")
        return ("project", "Updated the project")
    if action == "project.set_narrative":
        variant = details.get("variant") if isinstance(details, dict) else None
        suffix = f" · {variant}" if variant else ""
        return ("narrative", f"Set the narrative structure{suffix}")
    if action == "document.create_blank":
        return ("document_add", f"Started {quoted}")
    if action == "document.upload":
        return ("document_add", f"Uploaded {quoted}")
    if action == "document.duplicate":
        return ("document_add", f"Duplicated {quoted}")
    if action == "document.assign_project":
        return ("document_add", f"Added {quoted} to the project")
    if action == "recording.create":
        return ("document_add", "Added a recording")
    if action == "document.update":
        return ("document_edit", f"Edited {quoted}")
    if action == "document.summarized":
        return ("summary", f"Summarized {quoted}")
    if action == "document.set_narrative_beat":
        beat = details.get("beat") if isinstance(details, dict) else None
        if beat:
            return ("narrative", f"Mapped {quoted} to the {beat} beat")
        return ("narrative", f"Unassigned {quoted} from its beat")
    if action == "document.delete":
        return ("document_remove", f"Moved {quoted} to Trash")
    if action == "document.archive":
        return ("document_remove", f"Archived {quoted}")
    if action == "document.restore":
        return ("document_restore", f"Restored {quoted}")
    return ("event", action)


@router.get("/{project_id}/activity", response_model=list[ActivityEvent])
async def list_project_activity(
    project_id: str,
    limit: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> list[ActivityEvent]:
    """Curated, reverse-chronological Activity feed for an owned project.

    Read-only over ``audit_log`` (SELECT is permitted under the append-only
    tamper rules). Owner-guarded (404 if absent/not-owned). Scopes events to the
    project two ways — ``resource_type='project'`` on this id, and
    ``resource_type='document'`` for documents currently in the project — and
    always filters to the owner. Only the curated action allowlist is surfaced,
    mapped to safe human summaries (never raw audit details).
    """
    project = await _get_project_or_404(project_id, str(user_id), db)
    project_name = project.get("name") or "this project"

    stmt = text(
        """
        SELECT al.id, al.action, al.resource_type, al.resource_id,
               al.details_json, al.created_at, d.title AS doc_title
        FROM audit_log al
        LEFT JOIN documents d ON d.id = al.resource_id
        WHERE al.user_id = :uid
          AND al.action IN :actions
          AND (
            (al.resource_type = 'project' AND al.resource_id = :pid)
            OR (al.resource_type = 'document' AND al.resource_id IN (
                  SELECT id FROM documents WHERE project_id = :pid))
          )
        ORDER BY al.created_at DESC
        LIMIT :limit
        """
    ).bindparams(bindparam("actions", expanding=True))

    rows = await db.execute(
        stmt,
        {
            "uid": str(user_id),
            "pid": project_id,
            "actions": _ACTIVITY_ACTIONS,
            "limit": limit,
        },
    )

    events: list[ActivityEvent] = []
    for row in rows.mappings():
        details = row["details_json"]
        if not isinstance(details, dict):
            details = {}
        kind, summary = _activity_entry(
            row["action"], row["doc_title"], details, project_name
        )
        events.append(
            ActivityEvent(
                id=row["id"],
                kind=kind,
                summary=summary,
                created_at=row["created_at"],
                resource_type=row["resource_type"],
                resource_id=row["resource_id"],
            )
        )
    return events


@router.delete("/{project_id}", status_code=204)
async def delete_project(
    project_id: str,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    project = await _get_project_or_404(project_id, str(user_id), db)
    # Unassign all docs first (project_id → null)
    await db.execute(
        text(
            "UPDATE documents SET project_id = NULL WHERE project_id = :pid"
        ),
        {"pid": project_id},
    )
    await db.execute(
        text("DELETE FROM projects WHERE id = :id"),
        {"id": project_id},
    )
    await db.commit()
    await audit_service.log_event(
        db,
        action="project.delete",
        resource_type="project",
        user_id=str(user_id),
        resource_id=project_id,
        details={"name": project.get("name")},
        ip_address=request.client.host if request.client else None,
    )


@router.get("/{project_id}/documents")
async def list_project_documents(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    await _get_project_or_404(project_id, str(user_id), db)
    rows = await db.execute(
        text("""
            SELECT id, title, source_type, status, page_count, word_count,
                   file_size_bytes, created_at, project_id,
                   cover_type, cover_value, narrative_beat
            FROM documents
            WHERE project_id = :pid
              AND status != 'deleted'
            ORDER BY created_at DESC
        """),
        {"pid": project_id},
    )
    result = []
    for row in rows.mappings():
        result.append({
            "id": str(row["id"]),
            "title": row["title"],
            "source_type": row["source_type"],
            "status": row["status"],
            "page_count": row["page_count"],
            "word_count": row["word_count"],
            "file_size_bytes": row["file_size_bytes"],
            "created_at": row["created_at"].isoformat(),
            "project_id": str(row["project_id"]) if row["project_id"] else None,
            "cover_type": row["cover_type"],
            "cover_value": row["cover_value"],
            "narrative_beat": row["narrative_beat"],
        })
    return result


@router.put("/{project_id}/documents/{document_id}/beat")
async def set_document_narrative_beat(
    project_id: str,
    document_id: str,
    data: DocumentBeatUpdate,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Scene Mapper: map a document to a narrative beat (or unassign with null).

    Owner-guarded via the project (404 if absent/not-owned), and the document
    must belong to this project (404 otherwise). Sets ``documents.narrative_beat``
    to the chosen beat label and audit-logs ``document.set_narrative_beat`` so the
    change surfaces in the project Activity feed.
    """
    await _get_project_or_404(project_id, str(user_id), db)

    # The document must belong to this project (and not be deleted).
    doc = await db.execute(
        text(
            "SELECT id, title FROM documents "
            "WHERE id = :did AND project_id = :pid AND status != 'deleted'"
        ),
        {"did": document_id, "pid": project_id},
    )
    row = doc.mappings().first()
    if row is None:
        raise HTTPException(status_code=404, detail="Document not found")

    beat = (data.beat or "").strip() or None
    await db.execute(
        text("UPDATE documents SET narrative_beat = :beat WHERE id = :did"),
        {"beat": beat, "did": document_id},
    )
    await db.commit()

    await audit_service.log_event(
        db,
        action="document.set_narrative_beat",
        resource_type="document",
        user_id=str(user_id),
        resource_id=document_id,
        details={"beat": beat, "title": row["title"]},
        ip_address=request.client.host if request.client else None,
    )
    return {"id": document_id, "narrative_beat": beat}


@router.get("/{project_id}/placements", response_model=list[ProjectPlacement])
async def list_project_placements(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Document→blueprint/part placements for an owned project (Phase 5, read).

    Owner-guarded (absent / not-owned → 404). Joins part_documents →
    blueprint_parts → blueprints, scoped to the project's non-deleted documents
    (mirrors the raw-table conventions in ``blueprint_coherence``). Returns an
    empty list (200) when nothing is placed.
    """
    await _get_project_or_404(project_id, str(user_id), db)
    rows = await db.execute(
        text("""
            SELECT pd.document_id, bp.blueprint_id, pd.part_id,
                   b.name AS blueprint_name, bp.name AS part_name,
                   pd.role, pd.sort_order
            FROM part_documents pd
            JOIN documents d ON d.id = pd.document_id
            JOIN blueprint_parts bp ON bp.id = pd.part_id
            JOIN blueprints b ON b.id = bp.blueprint_id
            WHERE d.project_id = :pid AND d.status != 'deleted'
            ORDER BY pd.document_id
        """),
        {"pid": project_id},
    )
    return [
        ProjectPlacement(
            document_id=row["document_id"],
            blueprint_id=row["blueprint_id"],
            part_id=row["part_id"],
            blueprint_name=row["blueprint_name"],
            part_name=row["part_name"],
            role=row["role"],
            sort_order=float(row["sort_order"]),
        )
        for row in rows.mappings()
    ]
