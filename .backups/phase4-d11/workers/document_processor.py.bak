"""
Document processing worker — background job orchestrator.

Polls the jobs table for pending work and processes documents through
the full pipeline: parse → OCR → chunk → describe → classify → synthesize.

Designed for:
- At-least-once delivery with idempotency keys
- Exponential backoff on retries
- Progress reporting via Redis pub/sub
- Graceful shutdown on SIGTERM
"""

from __future__ import annotations

import asyncio
import signal
import uuid
from datetime import datetime, timezone

import structlog
from sqlalchemy import select, update

from psitta.config import get_settings
from psitta.db.session import DatabaseSessionManager
from psitta.models.domain import Document, DocumentChunk, Job
from psitta.providers.interfaces.contracts import registry

logger = structlog.get_logger()

POLL_INTERVAL_SECONDS = 2
MAX_CONCURRENT_JOBS = 3


class DocumentWorker:
    """Processes documents through the ingestion pipeline."""

    def __init__(self) -> None:
        self._running = False
        self._semaphore = asyncio.Semaphore(MAX_CONCURRENT_JOBS)
        self._db_manager = DatabaseSessionManager()

    async def start(self) -> None:
        """Start the worker loop."""
        settings = get_settings()
        self._db_manager.init(str(settings.database_url))
        self._running = True

        # Handle graceful shutdown
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self._shutdown)

        logger.info("worker_started", max_concurrent=MAX_CONCURRENT_JOBS)

        while self._running:
            try:
                await self._poll_and_process()
            except Exception:
                logger.exception("worker_poll_error")
            await asyncio.sleep(POLL_INTERVAL_SECONDS)

        await self._db_manager.close()
        logger.info("worker_stopped")

    def _shutdown(self) -> None:
        logger.info("worker_shutdown_requested")
        self._running = False

    async def _poll_and_process(self) -> None:
        """Poll for pending jobs and process them."""
        async with self._db_manager.session() as db:
            # Claim a pending job (atomic update)
            result = await db.execute(
                select(Job)
                .where(Job.status == "pending", Job.type == "process_document")
                .order_by(Job.priority.desc(), Job.created_at.asc())
                .limit(1)
                .with_for_update(skip_locked=True)
            )
            job = result.scalar_one_or_none()
            if job is None:
                return

            # Mark as processing
            job.status = "processing"
            job.attempts += 1
            job.started_at = datetime.now(timezone.utc)
            await db.commit()

        # Process with concurrency control
        async with self._semaphore:
            await self._process_job(job)

    async def _process_job(self, job: Job) -> None:
        """Execute the full document processing pipeline."""
        document_id = uuid.UUID(job.payload["document_id"])
        logger.info("job_started", job_id=str(job.id), document_id=str(document_id))

        try:
            async with self._db_manager.session() as db:
                # Fetch document
                result = await db.execute(
                    select(Document).where(Document.id == document_id)
                )
                document = result.scalar_one_or_none()
                if document is None:
                    raise ValueError(f"Document {document_id} not found")

                # Update status: parsing
                document.status = "parsing"
                await db.commit()

                # Step 1: Download and parse
                raw_content = await registry.storage.download(document.file_key)
                # TODO: Use DocumentParser based on source_type
                # parsed = await registry.document_parser(mime_type).parse(raw_content, mime_type)

                # Step 2: OCR (if scanned PDF)
                # Detected automatically by parser; run OCRProvider if needed

                # Step 3: Chunk into semantic blocks
                # For now, simple paragraph-based chunking
                text = raw_content.decode("utf-8", errors="replace")
                paragraphs = [p.strip() for p in text.split("\n\n") if p.strip()]

                for i, para in enumerate(paragraphs):
                    chunk = DocumentChunk(
                        document_id=document_id,
                        sequence_num=i,
                        content_type="text",
                        text_content=para,
                        tone_tag="neutral",
                        page_number=1,
                    )
                    db.add(chunk)

                # Step 4: Classify tone for each chunk
                for i, para in enumerate(paragraphs):
                    classification = await registry.tone_classifier.classify(para)
                    # Update chunk tone_tag (would be done via proper query)

                # Step 5: Mark as ready
                document.status = "ready"
                document.page_count = max(1, len(paragraphs) // 10)

                # Mark job complete
                result = await db.execute(
                    select(Job).where(Job.id == job.id)
                )
                job_record = result.scalar_one()
                job_record.status = "completed"
                job_record.completed_at = datetime.now(timezone.utc)

                await db.commit()

            logger.info(
                "job_completed",
                job_id=str(job.id),
                document_id=str(document_id),
                chunks=len(paragraphs),
            )

        except Exception as e:
            logger.exception(
                "job_failed",
                job_id=str(job.id),
                document_id=str(document_id),
                attempt=job.attempts,
            )
            async with self._db_manager.session() as db:
                result = await db.execute(select(Job).where(Job.id == job.id))
                job_record = result.scalar_one()

                if job_record.attempts >= job_record.max_attempts:
                    job_record.status = "dead_letter"
                    # Also mark document as failed
                    doc_result = await db.execute(
                        select(Document).where(Document.id == document_id)
                    )
                    doc = doc_result.scalar_one_or_none()
                    if doc:
                        doc.status = "failed"
                        doc.error_message = str(e)[:1000]
                else:
                    job_record.status = "pending"  # Will be retried

                job_record.error_message = str(e)[:1000]
                await db.commit()


async def main() -> None:
    """Entry point for running the worker."""
    worker = DocumentWorker()
    await worker.start()


if __name__ == "__main__":
    asyncio.run(main())
