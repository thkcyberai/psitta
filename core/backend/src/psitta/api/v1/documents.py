"""Psitta - Document Management Routes."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID, uuid4

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_db_session

logger = structlog.get_logger(__name__)

router = APIRouter()

ALLOWED_EXTENSIONS = frozenset({".pdf", ".docx", ".txt", ".md", ".html"})

DEV_USER_ID = "00000000-0000-0000-0000-000000000001"


@router.post("/", status_code=status.HTTP_202_ACCEPTED)
async def upload_document(
    file: UploadFile,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    filename = file.filename or "unknown"
    extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=415, detail="Unsupported file type")

    file_bytes = await file.read()
    file_size = len(file_bytes)

    doc_id = uuid4()
    title = filename.rsplit(".", 1)[0] if "." in filename else filename
    source_type = extension.lstrip(".")
    storage_key = f"uploads/{doc_id}{extension}"
    now = datetime.now(timezone.utc)

    await db.execute(
        text(
            "INSERT INTO documents (id, user_id, title, source_type, status, file_size_bytes, storage_key, created_at, updated_at) "
            "VALUES (:id, :user_id, :title, :source_type, :status, :file_size_bytes, :storage_key, :created_at, :updated_at)"
        ),
        {
            "id": doc_id,
            "user_id": DEV_USER_ID,
            "title": title,
            "source_type": source_type,
            "status": "uploaded",
            "file_size_bytes": file_size,
            "storage_key": storage_key,
            "created_at": now,
            "updated_at": now,
        },
    )

    logger.info("document.upload.accepted", doc_id=str(doc_id), title=title)

    return {
        "id": str(doc_id),
        "title": title,
        "status": "uploaded",
        "source_type": source_type,
        "page_count": None,
        "created_at": now.isoformat(),
    }


@router.get("/")
async def list_documents(
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    offset = (page - 1) * size

    count_result = await db.execute(
        text("SELECT COUNT(*) FROM documents WHERE user_id = :uid AND status != 'deleted'"),
        {"uid": DEV_USER_ID},
    )
    total = count_result.scalar() or 0

    rows = await db.execute(
        text(
            "SELECT id, title, status, source_type, page_count, created_at "
            "FROM documents WHERE user_id = :uid AND status != 'deleted' "
            "ORDER BY created_at DESC LIMIT :lim OFFSET :off"
        ),
        {"uid": DEV_USER_ID, "lim": size, "off": offset},
    )

    items = [
        {
            "id": str(r.id),
            "title": r.title,
            "status": r.status,
            "source_type": r.source_type,
            "page_count": r.page_count,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]

    return {"items": items, "page": page, "size": size, "total": total}


@router.get("/{document_id}")
async def get_document(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    result = await db.execute(
        text("SELECT id, title, status, source_type, page_count, file_size_bytes, created_at FROM documents WHERE id = :did"),
        {"did": document_id},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    return {
        "id": str(row.id),
        "title": row.title,
        "status": row.status,
        "source_type": row.source_type,
        "page_count": row.page_count,
        "file_size_bytes": row.file_size_bytes,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
) -> None:
    result = await db.execute(
        text("UPDATE documents SET status = 'deleted', updated_at = NOW() WHERE id = :did AND user_id = :uid AND status != 'deleted'"),
        {"did": document_id, "uid": DEV_USER_ID},
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Document not found")
    logger.info("document.deleted", doc_id=str(document_id))
