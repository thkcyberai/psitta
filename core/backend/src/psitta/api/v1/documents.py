"""Psitta - Document Management Routes."""

from __future__ import annotations

import re
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
