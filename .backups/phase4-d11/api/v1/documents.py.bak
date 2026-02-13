"""
Document endpoints — upload, list, detail, delete, status, chunks.
"""

from __future__ import annotations

import uuid
from typing import Any

import structlog
from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from psitta.dependencies import CurrentUserId, DbSession, Providers
from psitta.models.domain import Document, DocumentChunk
from psitta.schemas.api import (
    ApiListResponse,
    ApiResponse,
    ChunkResponse,
    DocumentResponse,
    DocumentURLRequest,
    PaginationMeta,
)
from psitta.services.document_service import DocumentService

logger = structlog.get_logger()
router = APIRouter()


ALLOWED_MIME_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
    "text/markdown",
}

MAX_UPLOAD_SIZE = 100 * 1024 * 1024  # 100 MB


@router.post(
    "",
    response_model=ApiResponse[DocumentResponse],
    status_code=status.HTTP_201_CREATED,
)
async def upload_document(
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
    file: UploadFile = File(...),
    title: str | None = Form(None),
    voice_id: str | None = Form(None),
    auto_play: bool = Form(True),
) -> dict[str, Any]:
    """Upload a document for processing."""
    # Validate file type
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unsupported file type: {file.content_type}. "
            f"Allowed: {', '.join(ALLOWED_MIME_TYPES)}",
        )

    # Validate file size
    content = await file.read()
    if len(content) > MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size {len(content)} bytes exceeds maximum of {MAX_UPLOAD_SIZE} bytes",
        )

    service = DocumentService(db=db, providers=providers)
    document = await service.create_from_upload(
        user_id=user_id,
        filename=file.filename or "untitled",
        content=content,
        content_type=file.content_type or "application/octet-stream",
        title_override=title,
        voice_id=voice_id,
        auto_process=auto_play,
    )

    logger.info(
        "document_uploaded",
        document_id=str(document.id),
        user_id=user_id,
        source_type=document.source_type,
        size_bytes=document.file_size_bytes,
    )

    return {"data": DocumentResponse.model_validate(document)}


@router.post(
    "/url",
    response_model=ApiResponse[DocumentResponse],
    status_code=status.HTTP_201_CREATED,
)
async def ingest_url(
    body: DocumentURLRequest,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Ingest a document from a URL."""
    service = DocumentService(db=db, providers=providers)
    document = await service.create_from_url(
        user_id=user_id,
        url=str(body.url),
        title_override=body.title,
        voice_id=body.voice_id,
        auto_process=body.auto_play,
    )

    return {"data": DocumentResponse.model_validate(document)}


@router.get("", response_model=ApiListResponse[DocumentResponse])
async def list_documents(
    db: DbSession,
    user_id: CurrentUserId,
    status_filter: str | None = Query(None, alias="status"),
    source_type: str | None = Query(None),
    cursor: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
) -> dict[str, Any]:
    """List documents for the current user."""
    query = (
        select(Document)
        .where(Document.user_id == user_id)
        .order_by(Document.created_at.desc())
        .limit(limit + 1)  # Fetch one extra for cursor
    )

    if status_filter:
        query = query.where(Document.status == status_filter)
    if source_type:
        query = query.where(Document.source_type == source_type)
    if cursor:
        query = query.where(Document.id < uuid.UUID(cursor))

    result = await db.execute(query)
    documents = list(result.scalars().all())

    has_more = len(documents) > limit
    if has_more:
        documents = documents[:limit]

    return {
        "data": [DocumentResponse.model_validate(d) for d in documents],
        "meta": PaginationMeta(
            cursor=str(documents[-1].id) if has_more else None,
            has_more=has_more,
        ),
    }


@router.get("/{document_id}", response_model=ApiResponse[DocumentResponse])
async def get_document(
    document_id: uuid.UUID,
    db: DbSession,
    user_id: CurrentUserId,
) -> dict[str, Any]:
    """Get document detail."""
    document = await _get_user_document(db, document_id, user_id)
    return {"data": DocumentResponse.model_validate(document)}


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: uuid.UUID,
    db: DbSession,
    providers: Providers,
    user_id: CurrentUserId,
) -> None:
    """Hard delete a document and all associated data."""
    document = await _get_user_document(db, document_id, user_id)

    service = DocumentService(db=db, providers=providers)
    await service.hard_delete(document)

    logger.info("document_deleted", document_id=str(document_id), user_id=user_id)


@router.get("/{document_id}/chunks", response_model=ApiListResponse[ChunkResponse])
async def get_chunks(
    document_id: uuid.UUID,
    db: DbSession,
    user_id: CurrentUserId,
    from_seq: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
) -> dict[str, Any]:
    """Get text chunks for a document."""
    await _get_user_document(db, document_id, user_id)

    query = (
        select(DocumentChunk)
        .where(DocumentChunk.document_id == document_id)
        .where(DocumentChunk.sequence_num >= from_seq)
        .order_by(DocumentChunk.sequence_num)
        .limit(limit + 1)
    )

    result = await db.execute(query)
    chunks = list(result.scalars().all())

    has_more = len(chunks) > limit
    if has_more:
        chunks = chunks[:limit]

    return {
        "data": [ChunkResponse.model_validate(c) for c in chunks],
        "meta": PaginationMeta(
            cursor=str(chunks[-1].sequence_num + 1) if has_more else None,
            has_more=has_more,
        ),
    }


# ── Helpers ──────────────────────────────────────────────────────────


async def _get_user_document(
    db: DbSession, document_id: uuid.UUID, user_id: str
) -> Document:
    """Fetch a document ensuring it belongs to the current user."""
    result = await db.execute(
        select(Document).where(
            Document.id == document_id,
            Document.user_id == user_id,
        )
    )
    document = result.scalar_one_or_none()
    if document is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Document {document_id} not found",
        )
    return document
