"""Writing Nook welcome-kit seeding.

Creates the 6 starter documents (docx / md / txt / html / pdf / epub) in a
new writer's Library, each parsed + chunked (so they are immediately
readable and listenable) and given a cover from the cover reservatory.

Design notes
------------
* Reuses the production ingest primitives from ``api.v1.documents`` rather
  than duplicating parse/chunk logic — imports are function-local to avoid
  a circular import (``documents`` triggers this module).
* Does NOT go through the HTTP upload handler and deliberately skips
  ``check_and_increment_doc_quota`` — welcome docs are free and must not
  consume the writer's monthly upload allowance.
* Does NOT eager-synthesize audio. The welcome docs narrate on first play
  (lazy), so seeding never burns ElevenLabs quota for a writer who may
  never open them.
* Each document is seeded independently; one failure is logged and skipped
  so a single bad asset can't deny the whole kit.

The one-time guard (``users.welcome_seeded``) is owned by the *caller*
(the list-documents trigger claims it atomically before scheduling the
background task). ``seed_welcome_kit`` itself is mechanical and will
happily seed again if called directly — the admin one-off uses that for
``--force`` re-seeds.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.get_logger(__name__)

# psitta/services/seed_service.py -> psitta/seeds/welcome
_SEED_DIR = Path(__file__).resolve().parents[1] / "seeds" / "welcome"


def _load_manifest() -> dict:
    with (_SEED_DIR / "manifest.json").open(encoding="utf-8") as f:
        return json.load(f)


async def _seed_one(
    db: AsyncSession,
    user_id: UUID,
    doc_meta: dict,
) -> int:
    """Seed a single welcome document. Returns chunk count (0 on skip)."""
    from psitta.api.v1.documents import _process_document
    from psitta.config import get_settings
    from psitta.providers.storage_s3 import S3StorageProvider
    from psitta.services.audio_cache import put_raw_file

    source_type = doc_meta["source_type"]
    extension = f".{source_type}"
    file_path = _SEED_DIR / doc_meta["file"]
    file_bytes = file_path.read_bytes()
    file_size = len(file_bytes)

    doc_id = uuid4()
    storage_key = f"uploads/{doc_id}{extension}"
    now = datetime.now(timezone.utc)

    # 1. Persist the raw file (same S3 path uploads use).
    await put_raw_file(str(doc_id), extension, file_bytes)

    # 2. Insert the documents row (status flips to 'ready' inside
    #    _process_document once chunking succeeds).
    await db.execute(
        text(
            "INSERT INTO documents "
            "(id, user_id, title, source_type, status, file_size_bytes, "
            "storage_key, page_count, word_count, created_at, updated_at) "
            "VALUES "
            "(:id, :user_id, :title, :source_type, 'uploaded', :sz, "
            ":key, 0, 0, :now, :now)"
        ),
        {
            "id": doc_id,
            "user_id": str(user_id),
            "title": doc_meta["title"],
            "source_type": source_type,
            "sz": file_size,
            "key": storage_key,
            "now": now,
        },
    )

    # 3. Parse + chunk (synchronous, reuses every format extractor).
    chunk_count, _chunk_ids = await _process_document(
        doc_id, file_bytes, extension, db
    )

    # 4. Cover from the reservatory — store under the document's cover key.
    cover_name = doc_meta.get("cover")
    if cover_name:
        cover_path = _SEED_DIR / cover_name
        if cover_path.exists():
            settings = get_settings()
            s3 = S3StorageProvider(settings)
            bucket = settings.S3_BUCKET_NAME
            key = f"covers/{doc_id}.jpg"
            await s3.put_object(
                bucket, key, cover_path.read_bytes(), content_type="image/jpeg"
            )
            await db.execute(
                text(
                    "UPDATE documents SET cover_type = 'uploaded', "
                    "cover_value = :cv WHERE id = :id"
                ),
                {"cv": key, "id": str(doc_id)},
            )

    logger.info(
        "welcome_seed.document_created",
        user_id=str(user_id),
        doc_id=str(doc_id),
        source_type=source_type,
        chunks=chunk_count,
    )
    return chunk_count


async def seed_welcome_kit(
    db: AsyncSession,
    user_id: UUID,
) -> tuple[int, int]:
    """Seed all welcome documents for ``user_id``. Returns (docs, chunks).

    Caller owns the transaction commit and the ``welcome_seeded`` guard.
    Per-document failures are logged and skipped.
    """
    manifest = _load_manifest()
    docs = sorted(manifest["documents"], key=lambda d: d.get("order", 0))

    docs_created = 0
    chunks_created = 0
    for doc_meta in docs:
        try:
            chunks = await _seed_one(db, user_id, doc_meta)
            docs_created += 1
            chunks_created += chunks
        except Exception:  # noqa: BLE001 — one bad asset must not abort the kit
            logger.warning(
                "welcome_seed.document_failed",
                user_id=str(user_id),
                file=doc_meta.get("file"),
                exc_info=True,
            )

    logger.info(
        "welcome_seed.completed",
        user_id=str(user_id),
        docs=docs_created,
        chunks=chunks_created,
    )
    return docs_created, chunks_created


async def run_welcome_seed_background(user_id: UUID) -> None:
    """Background-task entrypoint: open a fresh session, seed, commit.

    Used by the list-documents trigger via ``BackgroundTasks``. The
    triggering request's session is already closed by the time this runs,
    so we own a new session here. The ``welcome_seeded`` flag was already
    claimed atomically by the trigger before scheduling this task.
    """
    from psitta.db.session import async_session_factory

    try:
        async with async_session_factory() as db:
            await seed_welcome_kit(db, user_id)
            await db.commit()
    except Exception:  # noqa: BLE001 — background task: log, never raise
        logger.error(
            "welcome_seed.background_failed",
            user_id=str(user_id),
            exc_info=True,
        )
