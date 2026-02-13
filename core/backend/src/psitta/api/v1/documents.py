"""
Psitta — Document Management Routes.

Endpoints for uploading, listing, retrieving status, and deleting documents.
Documents pass through the pipeline: upload → parse → chunk → TTS → ready.

Security:
  - File size validated before storage (MAX_DOCUMENT_SIZE_MB)
  - File type whitelist enforced (PDF, DOCX, TXT, MD, HTML)
  - User isolation — users can only access their own documents
  - Storage keys are opaque UUIDs (no user-guessable paths)
"""

from __future__ import annotations

from typing import Annotated
from uuid import UUID

import structlog
from fastapi import APIRouter, HTTPException, Query, UploadFile, status

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

router = APIRouter()

# Allowed MIME types for upload validation
ALLOWED_CONTENT_TYPES: frozenset[str] = frozenset({
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
    "text/markdown",
    "text/html",
})

ALLOWED_EXTENSIONS: frozenset[str] = frozenset({
    ".pdf", ".docx", ".txt", ".md", ".html",
})


@router.post(
    "/",
    status_code=status.HTTP_202_ACCEPTED,
    summary="Upload a document for processing",
    response_description="Document accepted and queued for processing",
)
async def upload_document(
    file: UploadFile,
) -> dict:
    """Upload a document to begin the narration pipeline.

    The document is validated, stored, and a processing job is queued.
    Returns immediately with the document ID and initial status.

    Supported formats: PDF, DOCX, TXT, Markdown, HTML.
    """
    # ── Validate file type ─────────────────────────────────────────────
    filename = file.filename or "unknown"
    extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type '{extension}'. "
                   f"Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    logger.info(
        "document.upload.started",
        filename=filename,
        content_type=file.content_type,
        extension=extension,
    )

    # TODO: Wire to DocumentService
    # 1. Validate file size against MAX_DOCUMENT_SIZE_MB
    # 2. Upload to S3 via StorageProvider
    # 3. Create document record in DB
    # 4. Enqueue processing job to Redis Streams
    # 5. Return document ID + status

    return {
        "message": "Document upload endpoint — service layer pending",
        "filename": filename,
        "status": "accepted",
    }


@router.get(
    "/",
    summary="List user's documents",
    response_description="Paginated list of documents",
)
async def list_documents(
    page: Annotated[int, Query(ge=1, description="Page number")] = 1,
    size: Annotated[int, Query(ge=1, le=100, description="Items per page")] = 20,
) -> dict:
    """Return paginated list of documents for the authenticated user.

    Results are sorted by creation date (newest first).
    Includes document status, page count, and processing progress.
    """
    logger.info("document.list", page=page, size=size)

    # TODO: Wire to DocumentService.list_documents()
    return {
        "items": [],
        "page": page,
        "size": size,
        "total": 0,
    }


@router.get(
    "/{document_id}",
    summary="Get document details and status",
    response_description="Document metadata and processing status",
)
async def get_document(document_id: UUID) -> dict:
    """Retrieve detailed information about a specific document.

    Includes processing status, chunk count, available voices,
    and estimated remaining processing time.
    """
    logger.info("document.get", document_id=str(document_id))

    # TODO: Wire to DocumentService.get_document()
    return {
        "id": str(document_id),
        "status": "pending",
        "message": "Document detail endpoint — service layer pending",
    }


@router.delete(
    "/{document_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a document and all associated audio",
)
async def delete_document(document_id: UUID) -> None:
    """Soft-delete a document and all associated audio segments.

    Marks the document as deleted. Actual storage cleanup
    is handled by the retention worker on a scheduled basis.

    Security: Only the document owner can delete their documents.
    """
    logger.info("document.delete", document_id=str(document_id))

    # TODO: Wire to DocumentService.delete_document()
    # 1. Verify ownership
    # 2. Soft-delete document record
    # 3. Enqueue storage cleanup job
