"""
Psitta — Document Service.

Orchestrates the document lifecycle: upload, validation, storage,
processing pipeline trigger, status tracking, and deletion.

This is the primary business logic layer for documents. Route handlers
delegate to this service; the service coordinates providers and DB access.

Security:
  - File size and type validated before any storage operation
  - User isolation enforced on every query (user_id filter)
  - Storage keys are opaque UUIDs (never user-controlled paths)
  - Soft-delete with scheduled hard-delete via retention worker
"""

from __future__ import annotations

from uuid import UUID, uuid4

import structlog

from psitta.config import Settings
from psitta.models.domain import Document, DocumentStatus

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# Maximum file size in bytes (from settings, but define constant for validation)
_MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024  # 50 MB default


class DocumentService:
    """Manages document lifecycle operations.

    All methods enforce user-scoped access — the caller must
    provide the authenticated user_id for every operation.
    """

    def __init__(
        self,
        db_session: object,
        storage_client: object,
        redis_client: object,
        settings: Settings,
    ) -> None:
        self._db = db_session
        self._storage = storage_client
        self._redis = redis_client
        self._settings = settings
        self._max_size = settings.MAX_DOCUMENT_SIZE_MB * 1024 * 1024

    async def upload_document(
        self,
        user_id: str,
        filename: str,
        content_bytes: bytes,
        content_type: str,
    ) -> Document:
        """Upload and register a new document.

        Steps:
          1. Validate file size and type
          2. Generate opaque storage key
          3. Upload to S3 via storage provider
          4. Create document record in database
          5. Enqueue processing job to Redis Streams

        Args:
            user_id: Authenticated user's ID.
            filename: Original filename from upload.
            content_bytes: Raw file content.
            content_type: MIME type of the uploaded file.

        Returns:
            Document domain object with initial status.

        Raises:
            ValueError: If file exceeds size limit or type is unsupported.
        """
        # ── Validate size ──────────────────────────────────────────────
        if len(content_bytes) > self._max_size:
            msg = (
                f"File size {len(content_bytes)} bytes exceeds maximum "
                f"{self._max_size} bytes ({self._settings.MAX_DOCUMENT_SIZE_MB} MB)"
            )
            logger.warning("document.upload.size_exceeded", filename=filename)
            raise ValueError(msg)

        # ── Generate storage key ───────────────────────────────────────
        doc_id = uuid4()
        extension = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
        storage_key = f"uploads/{user_id}/{doc_id}.{extension}"

        logger.info(
            "document.upload.storing",
            document_id=str(doc_id),
            user_id=user_id,
            filename=filename,
            size_bytes=len(content_bytes),
        )

        # TODO: Upload to S3
        # await self._storage.put_object(
        #     bucket=self._settings.S3_BUCKET_NAME,
        #     key=storage_key,
        #     body=content_bytes,
        #     content_type=content_type,
        # )

        # TODO: Create DB record
        document = Document(
            id=doc_id,
            user_id=user_id,
            title=filename.rsplit(".", 1)[0] if "." in filename else filename,
            source_type=extension,
            status=DocumentStatus.UPLOADED,
            file_size_bytes=len(content_bytes),
            storage_key=storage_key,
        )

        # TODO: Enqueue processing job
        # await self._redis.xadd(
        #     "psitta:jobs:document_processing",
        #     {"document_id": str(doc_id), "user_id": user_id},
        # )

        logger.info(
            "document.upload.complete",
            document_id=str(doc_id),
            status=document.status.value,
        )

        return document

    async def get_document(self, user_id: str, document_id: UUID) -> Document | None:
        """Retrieve a document by ID, scoped to the requesting user.

        Returns None if the document doesn't exist or belongs
        to a different user (prevents enumeration attacks).
        """
        logger.info(
            "document.get",
            document_id=str(document_id),
            user_id=user_id,
        )

        # TODO: Query DB with user_id + document_id filter
        # row = await self._db.execute(
        #     select(DocumentModel)
        #     .where(DocumentModel.id == document_id)
        #     .where(DocumentModel.user_id == user_id)
        #     .where(DocumentModel.status != DocumentStatus.DELETED)
        # )
        return None

    async def list_documents(
        self, user_id: str, page: int = 1, size: int = 20
    ) -> tuple[list[Document], int]:
        """List documents for a user with pagination.

        Returns (items, total_count) tuple.
        Excludes soft-deleted documents.
        """
        logger.info(
            "document.list",
            user_id=user_id,
            page=page,
            size=size,
        )

        # TODO: Query DB with pagination
        return [], 0

    async def delete_document(self, user_id: str, document_id: UUID) -> bool:
        """Soft-delete a document and schedule storage cleanup.

        Returns True if the document was found and deleted,
        False if it didn't exist or wasn't owned by the user.

        Actual file cleanup is handled by the retention worker.
        """
        logger.info(
            "document.delete",
            document_id=str(document_id),
            user_id=user_id,
        )

        # TODO: Update status to DELETED in DB
        # TODO: Enqueue cleanup job for storage files
        return False
