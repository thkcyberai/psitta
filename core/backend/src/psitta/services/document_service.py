"""
Document service — business logic for document lifecycle.

Handles upload, URL ingestion, processing orchestration, and deletion.
No direct HTTP concerns; no framework imports.
"""

from __future__ import annotations

import mimetypes
import uuid
from pathlib import Path

import structlog
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.models.domain import (
    AudioSegment,
    Document,
    DocumentChunk,
    Job,
    VisualElement,
)
from psitta.providers.interfaces.contracts import ProviderRegistry

logger = structlog.get_logger()

# Map content types to our source_type enum
MIME_TO_SOURCE_TYPE: dict[str, str] = {
    "application/pdf": "pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    "text/plain": "txt",
    "text/markdown": "markdown",
}


class DocumentService:
    """Orchestrates document lifecycle operations."""

    def __init__(self, db: AsyncSession, providers: ProviderRegistry) -> None:
        self._db = db
        self._providers = providers

    async def create_from_upload(
        self,
        user_id: str,
        filename: str,
        content: bytes,
        content_type: str,
        title_override: str | None = None,
        voice_id: str | None = None,
        auto_process: bool = True,
    ) -> Document:
        """Create a document record from an uploaded file."""
        source_type = MIME_TO_SOURCE_TYPE.get(content_type, "txt")
        title = title_override or Path(filename).stem

        # Generate unique storage key
        doc_id = uuid.uuid4()
        ext = Path(filename).suffix or f".{source_type}"
        file_key = f"uploads/{user_id}/{doc_id}/original{ext}"

        # Upload to object storage
        await self._providers.storage.upload(
            key=file_key,
            data=content,
            content_type=content_type,
        )

        # Create database record
        document = Document(
            id=doc_id,
            user_id=user_id,
            title=title,
            source_type=source_type,
            file_key=file_key,
            file_size_bytes=len(content),
            status="uploaded",
            metadata={"original_filename": filename},
        )
        self._db.add(document)
        await self._db.flush()

        # Enqueue processing job
        if auto_process:
            await self._enqueue_processing(document)

        return document

    async def create_from_url(
        self,
        user_id: str,
        url: str,
        title_override: str | None = None,
        voice_id: str | None = None,
        auto_process: bool = True,
    ) -> Document:
        """Create a document record from a URL."""
        doc_id = uuid.uuid4()
        file_key = f"uploads/{user_id}/{doc_id}/original.html"

        document = Document(
            id=doc_id,
            user_id=user_id,
            title=title_override or url[:100],
            source_type="url",
            source_url=url,
            file_key=file_key,
            file_size_bytes=0,  # Updated after fetch
            status="uploaded",
            metadata={"source_url": url},
        )
        self._db.add(document)
        await self._db.flush()

        if auto_process:
            await self._enqueue_processing(document)

        return document

    async def hard_delete(self, document: Document) -> None:
        """Delete a document and all associated data from DB and storage."""
        # Delete S3 objects (uploads, extracted, audio)
        prefixes = [
            f"uploads/{document.user_id}/{document.id}/",
            f"extracted/{document.id}/",
            f"audio/{document.id}/",
        ]
        for prefix in prefixes:
            try:
                await self._providers.storage.delete_prefix(prefix)
            except Exception:
                logger.warning(
                    "storage_delete_failed",
                    prefix=prefix,
                    document_id=str(document.id),
                )

        # Cascade delete handles chunks, visual_elements, audio_segments
        await self._db.delete(document)

    async def _enqueue_processing(self, document: Document) -> None:
        """Create a background processing job for a document."""
        idempotency_key = f"process_document:{document.id}"
        job = Job(
            type="process_document",
            payload={
                "document_id": str(document.id),
                "user_id": str(document.user_id),
            },
            idempotency_key=idempotency_key,
            priority=self._calculate_priority(document),
        )
        self._db.add(job)

        logger.info(
            "processing_enqueued",
            document_id=str(document.id),
            job_id=str(job.id),
        )

    def _calculate_priority(self, document: Document) -> int:
        """Higher priority for smaller documents (faster feedback)."""
        if document.file_size_bytes < 1_000_000:  # < 1 MB
            return 10
        if document.file_size_bytes < 10_000_000:  # < 10 MB
            return 5
        return 0
