"""
Unit tests for DocumentService.

Tests business logic in isolation using mock providers.
No database or external service calls.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4

import pytest
import pytest_asyncio

from psitta.config import Settings
from psitta.models.domain import Document, DocumentStatus
from psitta.services.document_service import DocumentService
from tests.factories import DocumentFactory


class TestDocumentServiceUpload:
    """Tests for document upload flow."""

    @pytest.fixture
    def service(self, mock_storage, mock_redis):
        return DocumentService(
            db_session=AsyncMock(),
            storage_client=mock_storage,
            redis_client=mock_redis,
            settings=Settings(),
        )

    @pytest.mark.xfail(
        reason="storage/redis wiring not yet implemented - M11", strict=False
    )
    @pytest.mark.asyncio
    async def test_upload_stores_file_in_s3(self, service, mock_storage):
        """Upload should store the file bytes in S3."""
        file_bytes = b"fake-pdf-content"
        filename = "report.pdf"
        user_id = f"user_{uuid4().hex[:12]}"

        # Service calls storage.put_object
        await service.upload_document(
            content_bytes=file_bytes,
            filename=filename,
            user_id=user_id,
            content_type="application/pdf",
        )

        mock_storage.put_object.assert_called_once()
        call_args = mock_storage.put_object.call_args
        assert call_args[1]["data"] == file_bytes or call_args[0][1] == file_bytes

    @pytest.mark.asyncio
    async def test_upload_rejects_oversized_file(self, service):
        """Files exceeding the size limit should be rejected."""
        # 100MB file (over the 50MB default limit)
        file_bytes = b"x" * (100 * 1024 * 1024)

        with pytest.raises(ValueError, match="[Ss]ize"):
            await service.upload_document(
                content_bytes=file_bytes,
                filename="huge.pdf",
                user_id="user_test",
                content_type="application/pdf",
            )

    @pytest.mark.xfail(
        reason="storage/redis wiring not yet implemented - M11", strict=False
    )
    @pytest.mark.asyncio
    async def test_upload_queues_processing_job(self, service, mock_redis):
        """After upload, a processing job should be queued in Redis."""
        await service.upload_document(
            content_bytes=b"pdf-bytes",
            filename="test.pdf",
            user_id="user_test",
            content_type="application/pdf",
        )

        mock_redis.xadd.assert_called_once()


class TestDocumentServiceDelete:
    """Tests for document deletion."""

    @pytest.fixture
    def service(self, mock_storage, mock_redis):
        return DocumentService(
            db_session=AsyncMock(),
            storage_client=mock_storage,
            redis_client=mock_redis,
            settings=Settings(),
        )

    @pytest.mark.xfail(
        reason="storage/redis wiring not yet implemented - M11", strict=False
    )
    @pytest.mark.asyncio
    async def test_delete_removes_storage_objects(self, service, mock_storage):
        """Delete should remove the source file from S3."""
        doc = DocumentFactory.create(user_id="user_test")

        await service.delete_document(
            document_id=doc.id,
            user_id=doc.user_id,
        )

        mock_storage.delete_object.assert_called()
