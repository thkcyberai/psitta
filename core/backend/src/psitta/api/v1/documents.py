"""Psitta - Document Management Routes."""

from __future__ import annotations

import re
import io
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID, uuid4

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from pydantic import BaseModel, Field

from psitta.dependencies import get_db_session

logger = structlog.get_logger(__name__)

router = APIRouter()

ALLOWED_EXTENSIONS = frozenset({".pdf", ".docx", ".txt", ".md", ".html"})
TEXT_EXTENSIONS = frozenset({".txt", ".md", ".html"})
TARGET_CHUNK_SIZE = 1500  # characters per chunk

DEV_USER_ID = "00000000-0000-0000-0000-000000000001"


def _extract_text(file_bytes: bytes, extension: str) -> str | None:
    """Extract plain text from supported file types."""
    if extension in TEXT_EXTENSIONS:
        for encoding in ("utf-8", "latin-1", "cp1252"):
            try:
                return file_bytes.decode(encoding)
            except UnicodeDecodeError:
                continue

    if extension == ".docx":
        # Extract text from DOCX using python-docx.
        try:
            import docx  # python-docx
            doc = docx.Document(io.BytesIO(file_bytes))
            parts: list[str] = []
            for para in doc.paragraphs:
                t = (para.text or "").strip()
                if t:
                    parts.append(t)
            text = "\n\n".join(parts).strip()
            return text if text else None
        except Exception:
            return None

    if extension == ".pdf":
        # Extract text from PDF using pypdf.
        # For scanned PDFs with no text layer, this returns None.
        try:
            from pypdf import PdfReader
            reader = PdfReader(io.BytesIO(file_bytes))
            parts: list[str] = []
            for page in reader.pages:
                t = (page.extract_text() or "").strip()
                if t:
                    parts.append(t)
            text = "\n\n".join(parts).strip()
            return text if text else None
        except Exception:
            return None

    return None


def _chunk_markdown(raw_text: str) -> list[dict]:
    """Split text into chunks by headings or paragraph groups."""
    lines = raw_text.strip().splitlines()
    if not lines:
        return []

    sections: list[tuple[str, list[str]]] = []
    current_title = "Section 1"
    current_lines: list[str] = []
    section_counter = 1

    for line in lines:
        heading_match = re.match(r"^(#{1,3})\s+(.+)", line)
        if heading_match:
            if current_lines:
                sections.append((current_title, current_lines))
                current_lines = []
            current_title = heading_match.group(2).strip()
        else:
            current_lines.append(line)

    if current_lines:
        sections.append((current_title, current_lines))

    if not sections:
        return []

    chunks: list[dict] = []
    seq = 0

    for title, sec_lines in sections:
        body = "\n".join(sec_lines).strip()
        if not body:
            continue

        if len(body) <= TARGET_CHUNK_SIZE * 1.5:
            chunks.append({
                "title": title,
                "text": body,
                "seq": seq,
            })
            seq += 1
        else:
            paragraphs = re.split(r"\n\s*\n", body)
            buffer = ""
            part = 1
            for para in paragraphs:
                para = para.strip()
                if not para:
                    continue
                if buffer and len(buffer) + len(para) > TARGET_CHUNK_SIZE:
                    chunk_title = title if part == 1 else f"{title} (part {part})"
                    chunks.append({"title": chunk_title, "text": buffer.strip(), "seq": seq})
                    seq += 1
                    part += 1
                    buffer = para + "\n\n"
                else:
                    buffer += para + "\n\n"
            if buffer.strip():
                chunk_title = title if part == 1 else f"{title} (part {part})"
                chunks.append({"title": chunk_title, "text": buffer.strip(), "seq": seq})
                seq += 1

    if not chunks and raw_text.strip():
        chunks.append({"title": "Document", "text": raw_text.strip()[:5000], "seq": 0})

    return chunks


async def _process_document(
    doc_id: UUID,
    file_bytes: bytes,
    extension: str,
    db: AsyncSession,
) -> int:
    """Extract text, chunk, and insert into document_chunks. Returns chunk count."""
    raw_text = _extract_text(file_bytes, extension)
    if raw_text is None:
        logger.warning("document.process.unsupported", doc_id=str(doc_id), ext=extension)
        return 0

    chunks = _chunk_markdown(raw_text)
    if not chunks:
        return 0

    for chunk in chunks:
        chunk_id = uuid4()
        await db.execute(
            text(
                "INSERT INTO document_chunks "
                "(id, document_id, sequence_index, chunk_type, text_content, tone, page_number, character_count, metadata_json) "
                "VALUES (:id, :doc_id, :seq, :ctype, :txt, :tone, :page, :chars, :meta)"
            ),
            {
                "id": chunk_id,
                "doc_id": doc_id,
                "seq": chunk["seq"],
                "ctype": "text",
                "txt": chunk["text"],
                "tone": "neutral",
                "page": 1,
                "chars": len(chunk["text"]),
                "meta": f'{{"title": "{chunk["title"]}"}}',
            },
        )

    await db.execute(
        text("UPDATE documents SET status = :st, page_count = :pc, updated_at = NOW() WHERE id = :did"),
        {"st": "ready", "pc": len(chunks), "did": doc_id},
    )

    logger.info("document.processed", doc_id=str(doc_id), chunks=len(chunks))
    return len(chunks)


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

    chunk_count = await _process_document(doc_id, file_bytes, extension, db)
    doc_status = "ready" if chunk_count > 0 else "uploaded"

    logger.info("document.upload.accepted", doc_id=str(doc_id), title=title, chunks=chunk_count)

    return {
        "id": str(doc_id),
        "title": title,
        "status": doc_status,
        "source_type": source_type,
        "page_count": chunk_count if chunk_count > 0 else None,
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


@router.get("/{document_id}/chunks")
async def get_document_chunks(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Return all chunks for a document, ordered by sequence."""
    doc_result = await db.execute(
        text("SELECT id, status FROM documents WHERE id = :did"),
        {"did": document_id},
    )
    doc = doc_result.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    rows = await db.execute(
        text(
            "SELECT id, sequence_index, chunk_type, text_content, tone, page_number, character_count, metadata_json "
            "FROM document_chunks WHERE document_id = :did "
            "ORDER BY sequence_index"
        ),
        {"did": document_id},
    )

    chunks = []
    for r in rows:
        meta = r.metadata_json if isinstance(r.metadata_json, dict) else {}
        chunks.append({
            "id": str(r.id),
            "sequence_index": r.sequence_index,
            "chunk_type": r.chunk_type,
            "title": meta.get("title", f"Section {r.sequence_index + 1}"),
            "text_content": r.text_content,
            "tone": r.tone,
            "page_number": r.page_number,
            "character_count": r.character_count,
        })

    return {
        "document_id": str(document_id),
        "status": doc.status,
        "total_chunks": len(chunks),
        "chunks": chunks,
    }



class DocumentUpdateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)


@router.patch("/{document_id}")
async def update_document(
    document_id: UUID,
    payload: DocumentUpdateRequest,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Update editable document fields.

    Currently supports title rename only.
    """
    # Update title for this user's document (ignore deleted docs)
    result = await db.execute(
        text(
            "UPDATE documents "
            "SET title = :title, updated_at = NOW() "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": DEV_USER_ID, "title": payload.title.strip()},
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Document not found")

    row = await db.execute(
        text(
            "SELECT id, user_id, title, status, source_type, page_count, file_size_bytes, created_at, updated_at "
            "FROM documents WHERE id = :did"
        ),
        {"did": document_id},
    )
    doc = row.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    logger.info("document.updated", doc_id=str(document_id), fields=["title"])

    return {
        "id": str(doc.id),
        "title": doc.title,
        "status": doc.status,
        "source_type": doc.source_type,
        "page_count": doc.page_count,
        "file_size_bytes": doc.file_size_bytes,
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
        "updated_at": doc.updated_at.isoformat() if doc.updated_at else None,
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

    # Purge cached audio for this document (best-effort).
    # This prevents stale MP3 reuse after document deletion.
    try:
        from pathlib import Path as _Path

        audio_dir = _Path("/app/audio_cache")
        prefix = f"psitta_{document_id}_"
        purged = 0

        if audio_dir.exists():
            for f in audio_dir.iterdir():
                name = f.name
                if name.startswith(prefix) and name.endswith(".mp3"):
                    try:
                        f.unlink()
                        purged += 1
                    except Exception:
                        pass

        logger.info("document.audio_cache.purge", doc_id=str(document_id), purged=purged)
    except Exception:
        logger.info("document.audio_cache.purge", doc_id=str(document_id), purged=None)

@router.post("/{document_id}/synthesize")
async def synthesize_document(
    document_id: UUID,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Synthesize audio for all chunks in a document."""
    from psitta.config import get_settings
    settings = get_settings()

    doc_result = await db.execute(
        text("SELECT id, status FROM documents WHERE id = :did"),
        {"did": document_id},
    )
    doc = doc_result.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    chunks_result = await db.execute(
        text("SELECT id, text_content FROM document_chunks WHERE document_id = :did ORDER BY sequence_index"),
        {"did": document_id},
    )
    chunks = list(chunks_result)
    if not chunks:
        raise HTTPException(status_code=400, detail="No chunks to synthesize")

    from psitta.providers.tts_router import TTSRouter
    import os
    tts = TTSRouter()
    if not tts.has_provider:
        raise HTTPException(status_code=503, detail="No TTS provider configured. Set ELEVENLABS_API_KEY or AZURE_TTS_KEY.")

    audio_dir = "/app/audio_cache"
    os.makedirs(audio_dir, exist_ok=True)

    synthesized = 0
    for chunk in chunks:
        existing = await db.execute(
            text("SELECT id FROM audio_segments WHERE chunk_id = :cid AND voice_id = :vid"),
            {"cid": chunk.id, "vid": voice_id},
        )
        if existing.first():
            synthesized += 1
            continue

        audio_bytes = await tts.synthesize(chunk.text_content, voice_id)

        seg_id = uuid4()
        audio_path = f"{audio_dir}/{seg_id}.mp3"
        with open(audio_path, "wb") as f:
            f.write(audio_bytes)

        await db.execute(
            text(
                "INSERT INTO audio_segments (id, document_id, chunk_id, voice_id, speed, storage_key, duration_ms, file_size_bytes, format) "
                "VALUES (:id, :doc_id, :chunk_id, :voice_id, :speed, :key, :dur, :size, :fmt)"
            ),
            {
                "id": seg_id,
                "doc_id": document_id,
                "chunk_id": chunk.id,
                "voice_id": voice_id,
                "speed": 1.0,
                "key": audio_path,
                "dur": 0,
                "size": len(audio_bytes),
                "fmt": "mp3",
            },
        )
        synthesized += 1
        logger.info("tts.chunk.synthesized", chunk_id=str(chunk.id), size=len(audio_bytes))

    await db.execute(
        text("UPDATE documents SET status = 'ready', updated_at = NOW() WHERE id = :did"),
        {"did": document_id},
    )

    return {"document_id": str(document_id), "synthesized": synthesized, "voice_id": voice_id}


@router.get("/{document_id}/chunks/{chunk_id}/audio")
async def get_chunk_audio(
    document_id: UUID,
    chunk_id: UUID,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    db: AsyncSession = Depends(get_db_session),
) -> None:
    """Stream audio for a specific chunk. Auto-synthesizes on cache miss."""
    import os
    from fastapi.responses import FileResponse

    # Check cache first
    result = await db.execute(
        text("SELECT storage_key FROM audio_segments WHERE chunk_id = :cid AND voice_id = :vid"),
        {"cid": chunk_id, "vid": voice_id},
    )
    row = result.first()

    if row and os.path.exists(row.storage_key):
        return FileResponse(row.storage_key, media_type="audio/mpeg", filename=f"{chunk_id}.mp3")

    # Cache miss -- synthesize on demand
    logger.info("audio.cache_miss", chunk_id=str(chunk_id), voice_id=voice_id)

    # Get chunk text
    chunk_result = await db.execute(
        text("SELECT text_content FROM document_chunks WHERE id = :cid AND document_id = :did"),
        {"cid": chunk_id, "did": document_id},
    )
    chunk_row = chunk_result.first()
    if not chunk_row or not chunk_row.text_content:
        raise HTTPException(status_code=404, detail="Chunk not found")

    # Synthesize
    from psitta.providers.tts_router import TTSRouter
    tts = TTSRouter()
    try:
        audio_bytes = await tts.synthesize(chunk_row.text_content, voice_id)
    except Exception as e:
        logger.error("audio.synthesize_failed", error=str(e), voice_id=voice_id)
        raise HTTPException(status_code=502, detail=f"TTS synthesis failed: {e}")

    # Save to disk
    audio_dir = "/tmp/psitta_audio"
    os.makedirs(audio_dir, exist_ok=True)
    storage_key = f"{audio_dir}/{chunk_id}_{voice_id}.mp3"
    with open(storage_key, "wb") as f:
        f.write(audio_bytes)

    # Insert cache record (delete stale row first if file was missing)
    if row:
        await db.execute(
            text("DELETE FROM audio_segments WHERE chunk_id = :cid AND voice_id = :vid"),
            {"cid": chunk_id, "vid": voice_id},
        )
    from uuid import uuid4 as _uuid4
    await db.execute(
        text(
            "INSERT INTO audio_segments (id, document_id, chunk_id, voice_id, speed, storage_key, duration_ms, file_size_bytes, format) "
            "VALUES (:id, :doc_id, :chunk_id, :voice_id, :speed, :key, :dur, :size, :fmt)"
        ),
        {
            "id": _uuid4(),
            "doc_id": document_id,
            "chunk_id": chunk_id,
            "voice_id": voice_id,
            "speed": 1.0,
            "key": storage_key,
            "dur": int(len(audio_bytes) / 24),
            "size": len(audio_bytes),
            "fmt": "mp3",
        },
    )
    await db.commit()
    logger.info("audio.synthesized_on_demand", chunk_id=str(chunk_id), voice_id=voice_id, size=len(audio_bytes))

    return FileResponse(storage_key, media_type="audio/mpeg", filename=f"{chunk_id}.mp3")
