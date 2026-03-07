import uuid
from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from psitta.dependencies import get_db_session

router = APIRouter(prefix="/projects", tags=["projects"])

DEV_USER_ID = "00000000-0000-0000-0000-000000000001"


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _get_project_or_404(project_id: str, db: AsyncSession) -> dict:
    row = await db.execute(
        text("SELECT id, user_id, name, created_at FROM projects WHERE id = :id"),
        {"id": project_id},
    )
    project = row.mappings().first()
    if not project or project["user_id"] != DEV_USER_ID:
        raise HTTPException(status_code=404, detail="Project not found")
    return dict(project)


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
async def create_project(
    body: dict,
    db: AsyncSession = Depends(get_db_session),
):
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=422, detail="name is required")
    project_id = str(uuid.uuid4())
    await db.execute(
        text(
            "INSERT INTO projects (id, user_id, name) VALUES (:id, :uid, :name)"
        ),
        {"id": project_id, "uid": DEV_USER_ID, "name": name},
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
    return project


@router.get("/")
async def list_projects(
    db: AsyncSession = Depends(get_db_session),
):
    rows = await db.execute(
        text("""
            SELECT p.id, p.name, p.created_at,
                   COUNT(d.id) AS document_count
            FROM projects p
            LEFT JOIN documents d
                ON d.project_id = p.id AND d.status != 'deleted'
            WHERE p.user_id = :uid
            GROUP BY p.id, p.name, p.created_at
            ORDER BY p.created_at DESC
        """),
        {"uid": DEV_USER_ID},
    )
    result = []
    for row in rows.mappings():
        result.append({
            "id": str(row["id"]),
            "name": row["name"],
            "created_at": row["created_at"].isoformat(),
            "document_count": row["document_count"],
        })
    return result


@router.patch("/{project_id}")
async def rename_project(
    project_id: str,
    body: dict,
    db: AsyncSession = Depends(get_db_session),
):
    await _get_project_or_404(project_id, db)
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(status_code=422, detail="name is required")
    await db.execute(
        text(
            "UPDATE projects SET name = :name, updated_at = now() WHERE id = :id"
        ),
        {"name": name, "id": project_id},
    )
    await db.commit()
    return {"id": project_id, "name": name}


@router.delete("/{project_id}", status_code=204)
async def delete_project(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    await _get_project_or_404(project_id, db)
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


@router.get("/{project_id}/documents")
async def list_project_documents(
    project_id: str,
    db: AsyncSession = Depends(get_db_session),
):
    await _get_project_or_404(project_id, db)
    rows = await db.execute(
        text("""
            SELECT id, title, source_type, status, page_count,
                   file_size_bytes, created_at, project_id
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
            "file_size_bytes": row["file_size_bytes"],
            "created_at": row["created_at"].isoformat(),
            "project_id": str(row["project_id"]) if row["project_id"] else None,
        })
    return result
