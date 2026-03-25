"""Psitta - Document Management Routes."""

from __future__ import annotations

import io
import json
import re
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID, uuid4

import pysbd
import structlog
from pathlib import Path
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session
from psitta.middleware.auth import TokenClaims
from psitta.schemas.api import ChunkResponse, ChunkUpdateRequest, ResynthesizeResponse

logger = structlog.get_logger(__name__)


def _reflow_pdf_text(text: str) -> str:
    """Reflow PDF-extracted text.
    Keeps paragraph breaks (blank lines) but merges single newlines into spaces.
    """
    if not text:
        return ""
    t = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = t.split("\n")
    out: list[str] = []
    buf = ""
    for line in lines:
        ln = line.strip()
        if not ln:
            if buf.strip():
                out.append(buf.strip())
                buf = ""
            out.append("")
            continue
        if buf.endswith("-"):
            buf = buf[:-1] + ln
        else:
            buf = (buf + " " + ln).strip() if buf else ln
    if buf.strip():
        out.append(buf.strip())
    # collapse 3+ blank lines to max 2
    joined = "\n".join(out)
    joined = re.sub(r"\n{3,}", "\n\n", joined)
    return joined


def _sanitize_text_for_db(text: str) -> str:
    """Remove bytes/chars that Postgres TEXT cannot store.
    - strips NULL bytes (\x00)
    - strips other control chars except \n \r \t
    """
    if not text:
        return ""
    text = text.replace("\x00", "")
    text = "".join(ch for ch in text if (ch >= " " or ch in "\n\r\t"))
    return text


def _normalize_sentence_compare(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().casefold()


def _normalize_pdf_page_marker(line: str) -> str:
    stripped = line.strip()
    stripped = re.sub(r"^[\s\[\](){}<>#*~\-.:|]+", "", stripped)
    stripped = re.sub(r"[\s\[\](){}<>#*~\-.:|]+$", "", stripped)
    return stripped


def _looks_like_pdf_page_number_line(line: str, page_number: int | None = None) -> bool:
    stripped = _normalize_pdf_page_marker(line)
    if not stripped:
        return False
    if page_number is not None:
        if stripped == str(page_number):
            return True
        if re.fullmatch(rf"page\s+{page_number}(?:\s+of\s+\d+)?", stripped, re.IGNORECASE):
            return True
        if re.fullmatch(rf"{page_number}\s*/\s*\d+", stripped):
            return True
    if re.fullmatch(r"page\s+[ivxlcdm]{1,8}", stripped, re.IGNORECASE):
        return True
    if re.fullmatch(r"[ivxlcdm]{2,8}", stripped, re.IGNORECASE):
        return True
    return bool(re.fullmatch(r"page\s+\d+(?:\s+of\s+\d+)?", stripped, re.IGNORECASE))


def _strip_pdf_page_number_prefix(text: str, page_number: int | None = None) -> str:
    if not text:
        return ""

    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = normalized.split("\n")
    filtered: list[str] = []
    removed_prefix = False

    for idx, line in enumerate(lines):
        stripped = line.strip()
        if idx < 2 and not removed_prefix and _looks_like_pdf_page_number_line(stripped, page_number):
            removed_prefix = True
            continue
        filtered.append(line)

    cleaned = "\n".join(filtered).lstrip()
    if page_number is not None:
        cleaned = re.sub(
            rf"^(?:page\s+)?{page_number}(?:\s+of\s+\d+)?[\s:.\-]+",
            "",
            cleaned,
            count=1,
            flags=re.IGNORECASE,
        )
    return cleaned.strip()


def _strip_pdf_page_number_suffix(text: str, page_number: int | None = None) -> str:
    if not text:
        return ""

    cleaned = text.strip()
    if page_number is not None:
        cleaned = re.sub(
            rf"[\s:.\-]+(?:page\s+)?{page_number}(?:\s+of\s+\d+)?$",
            "",
            cleaned,
            count=1,
            flags=re.IGNORECASE,
        )
        cleaned = re.sub(
            rf"[\s:.\-]+{page_number}$",
            "",
            cleaned,
            count=1,
        )
    cleaned = re.sub(
        r"[\s:.\-]+page\s+\d+(?:\s+of\s+\d+)?$",
        "",
        cleaned,
        count=1,
        flags=re.IGNORECASE,
    )
    return cleaned.strip()


def _strip_pdf_page_number_edge_tokens(text: str, page_number: int | None = None) -> str:
    if not text:
        return ""

    cleaned = text.strip()
    wrapper = r"[\s\[\](){}<>#*~:|.\-]*"
    start_patterns = [
        rf"^{wrapper}page\s+\d+(?:\s+of\s+\d+)?{wrapper}\s+",
        rf"^{wrapper}[ivxlcdm]{{2,8}}{wrapper}\s+",
    ]
    end_patterns = [
        rf"\s+{wrapper}page\s+\d+(?:\s+of\s+\d+)?{wrapper}$",
        rf"\s+{wrapper}[ivxlcdm]{{2,8}}{wrapper}$",
    ]
    if page_number is not None:
        start_patterns.insert(
            0,
            rf"^{wrapper}(?:page\s+)?{page_number}(?:\s+of\s+\d+)?{wrapper}\s+",
        )
        end_patterns.insert(
            0,
            rf"\s+{wrapper}(?:page\s+)?{page_number}(?:\s+of\s+\d+)?{wrapper}$",
        )

    for pattern in start_patterns:
        cleaned = re.sub(pattern, "", cleaned, count=1, flags=re.IGNORECASE)
    for pattern in end_patterns:
        cleaned = re.sub(pattern, "", cleaned, count=1, flags=re.IGNORECASE)
    return cleaned.strip()


def _strip_pdf_page_number_lines(text: str, page_number: int | None = None) -> str:
    if not text:
        return ""

    normalized = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = normalized.split("\n")
    filtered: list[str] = []
    last_index = len(lines) - 1

    for idx, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            filtered.append(line)
            continue
        near_edge = idx < 2 or idx >= max(0, last_index - 1)
        if near_edge and _looks_like_pdf_page_number_line(stripped, page_number):
            continue
        filtered.append(line)

    return "\n".join(filtered)


def _drop_duplicate_leading_sentence(text: str) -> str:
    if not text:
        return ""

    segmenter = pysbd.Segmenter(language="en", clean=False)
    sentences = [s for s in segmenter.segment(text) if s and s.strip()]
    if len(sentences) < 2:
        return text.strip()

    first = sentences[0].strip()
    second = sentences[1].strip()
    if _normalize_sentence_compare(first) != _normalize_sentence_compare(second):
        return text.strip()

    start = text.find(second)
    if start <= 0:
        return text.strip()
    return text[start:].lstrip()


def _add_terminal_punctuation(text: str) -> str:
    """Add a period to lines that look like headings/titles without terminal punctuation.
    Only applies to short lines (<=80 chars) to avoid adding periods to
    soft-wrapped body text lines from PDF extraction.
    """
    terminal = frozenset({".", "!", "?", ":", ";", ","})
    result = []
    for line in text.split("\n"):
        stripped = line.rstrip()
        # Only add period to short lines — long lines are wrapped body text
        if stripped and len(stripped) <= 80 and stripped[-1] not in terminal:
            stripped = stripped + "."
        result.append(stripped)
    return "\n".join(result)
def _clean_pdf_chunk_text(text: str, page_number: int | None = None) -> str:
    cleaned = _strip_pdf_page_number_lines(text, page_number)
    # Add terminal punctuation BEFORE reflow so line structure is intact.
    # Titles without punctuation get a period here, giving TTS a pause cue.
    cleaned = _add_terminal_punctuation(cleaned)
    cleaned = _sanitize_text_for_db(_reflow_pdf_text(cleaned))
    cleaned = _strip_pdf_page_number_prefix(cleaned, page_number)
    cleaned = _strip_pdf_page_number_suffix(cleaned, page_number)
    cleaned = _strip_pdf_page_number_edge_tokens(cleaned, page_number)
    cleaned = _drop_duplicate_leading_sentence(cleaned)
    return _sanitize_text_for_db(cleaned).strip()
def _build_sentence_boundaries(text: str) -> list[list[int]]:
    if not text:
        return []
    segmenter = pysbd.Segmenter(language="en", clean=False)
    boundaries: list[list[int]] = []
    line_offset = 0
    for line in text.splitlines(keepends=True):
        line_text = line.rstrip("\r\n")
        if not line_text.strip():
            line_offset += len(line)
            continue
        sent_cursor = 0
        for sent in segmenter.segment(line_text):
            if not sent or not sent.strip():
                continue
            try:
                rel_start = line_text.index(sent, sent_cursor)
            except ValueError:
                continue
            rel_end = rel_start + len(sent)
            boundaries.append([line_offset + rel_start, line_offset + rel_end])
            sent_cursor = rel_end
        line_offset += len(line)
    return boundaries
router = APIRouter()

ALLOWED_EXTENSIONS = frozenset({".pdf", ".docx", ".txt", ".md", ".html"})
TEXT_EXTENSIONS = frozenset({".txt", ".md", ".html"})
TARGET_CHUNK_SIZE = 1500  # characters per chunk

def _extract_formatted_docx(file_bytes: bytes) -> tuple[str, list[dict]] | None:
    """Extract plain text AND formatted_content from a DOCX file.

    Returns (plain_text, formatted_content_list) or None on failure.
    """
    try:
        import docx  # python-docx
        from docx.enum.text import WD_ALIGN_PARAGRAPH  # noqa: F401

        doc = docx.Document(io.BytesIO(file_bytes))
        formatted: list[dict] = []
        plain_parts: list[str] = []

        for para in doc.paragraphs:
            para_text = (para.text or "").strip()
            if not para_text:
                continue

            # Determine paragraph type
            style_name = (para.style.name or "").lower() if para.style else ""
            ptype = "paragraph"
            level = None

            if style_name.startswith("heading"):
                ptype = "heading"
                # Extract level from style name like "Heading 1", "Heading 2"
                for ch in style_name:
                    if ch.isdigit():
                        level = int(ch)
                        break
                if level is None:
                    level = 1
            elif style_name.startswith("list") or style_name.startswith("bullet"):
                ptype = "list_item"

            # Extract runs with formatting
            runs: list[dict] = []
            for run in para.runs:
                run_text = run.text or ""
                if not run_text:
                    continue
                run_data: dict = {"text": run_text}
                if run.bold:
                    run_data["bold"] = True
                if run.italic:
                    run_data["italic"] = True
                if run.underline:
                    run_data["underline"] = True
                if run.font and run.font.size:
                    run_data["font_size"] = round(run.font.size.pt, 1)
                runs.append(run_data)

            # If no runs extracted (e.g. field codes), fall back to full text
            if not runs:
                runs = [{"text": para_text}]

            entry: dict = {"type": ptype, "runs": runs}
            if level is not None:
                entry["level"] = level
            formatted.append(entry)
            plain_parts.append(para_text)

        plain = "\n\n".join(plain_parts).strip()
        return (plain, formatted) if plain else None
    except Exception:
        logger.exception("docx.format_extract.failed")
        return None


def _extract_formatted_pdf(file_bytes: bytes) -> tuple[list[dict], list[list[dict]]] | None:
    """Extract page text AND per-page formatted_content from a PDF.

    Returns (pages_list, per_page_formatted) or None on failure.
    pages_list items: {"page_number": int, "text": str}
    per_page_formatted: list of formatted blocks per page.
    """
    try:
        from pypdf import PdfReader

        reader = PdfReader(io.BytesIO(file_bytes))
        pages: list[dict] = []
        per_page_formatted: list[list[dict]] = []

        for i, page in enumerate(reader.pages):
            raw = (page.extract_text() or "").strip()
            if not raw:
                continue
            clean = _clean_pdf_chunk_text(raw, i + 1)
            if not clean.strip():
                continue

            pages.append({"page_number": i + 1, "text": clean})

            # Build structured paragraphs from the reflowed text
            paragraphs = re.split(r"\n\s*\n", clean)
            page_blocks: list[dict] = []
            for para in paragraphs:
                para = para.strip()
                if not para:
                    continue
                # Heuristic: short all-caps or title-case lines may be headings
                ptype = "paragraph"
                level = None
                words = para.split()
                if (
                    len(words) <= 12
                    and not para.endswith(".")
                    and (para.isupper() or para.istitle())
                ):
                    ptype = "heading"
                    level = 1 if para.isupper() else 2

                entry: dict = {"type": ptype, "runs": [{"text": para}]}
                if level is not None:
                    entry["level"] = level
                page_blocks.append(entry)

            per_page_formatted.append(page_blocks)

        return (pages, per_page_formatted) if pages else None
    except Exception:
        logger.exception("pdf.format_extract.failed")
        return None


def _extract_text(file_bytes: bytes, extension: str) -> str | list[dict] | None:
    """Extract plain text from supported file types."""
    if extension in TEXT_EXTENSIONS:
        for encoding in ("utf-8", "latin-1", "cp1252"):
            try:
                return file_bytes.decode(encoding)
            except UnicodeDecodeError:
                continue

    if extension == ".docx":
        result = _extract_formatted_docx(file_bytes)
        if result:
            return result[0]  # plain text only for legacy path
        return None

    if extension == ".pdf":
        result = _extract_formatted_pdf(file_bytes)
        if result:
            return result[0]  # pages list only for legacy path
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
            chunks.append({"title": title, "text": body, "seq": seq})
            seq += 1
            continue

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


def _chunk_by_pages(pages: list[dict]) -> list[dict]:
    """Split PDF pages into chunks — one page = one chunk.

    If a page exceeds 5000 characters it is split into sub-chunks.
    Each chunk dict has: title, text, seq, page_number.
    """
    chunks: list[dict] = []
    seq = 0
    max_chars = 5000

    for page in pages:
        page_num = page["page_number"]
        page_text = page["text"]

        if len(page_text) <= max_chars:
            chunks.append({
                "title": f"Page {page_num}",
                "text": page_text,
                "seq": seq,
                "page_number": page_num,
            })
            seq += 1
        else:
            # Split oversized page on paragraph boundaries
            paragraphs = re.split(r"\n\s*\n", page_text)
            buffer = ""
            part = 1
            for para in paragraphs:
                para = para.strip()
                if not para:
                    continue
                if buffer and len(buffer) + len(para) > max_chars:
                    chunks.append({
                        "title": f"Page {page_num} (part {part})",
                        "text": buffer.strip(),
                        "seq": seq,
                        "page_number": page_num,
                    })
                    seq += 1
                    part += 1
                    buffer = para + "\n\n"
                else:
                    buffer += para + "\n\n"
            if buffer.strip():
                chunks.append({
                    "title": f"Page {page_num} (part {part})" if part > 1 else f"Page {page_num}",
                    "text": buffer.strip(),
                    "seq": seq,
                    "page_number": page_num,
                })
                seq += 1

    return chunks


async def _process_document(
    doc_id: UUID,
    file_bytes: bytes,
    extension: str,
    db: AsyncSession,
) -> int:
    """Extract text, chunk, and insert into document_chunks. Returns chunk count."""

    # ── Extract formatted content alongside plain text ──────────────────
    formatted_by_chunk: dict[int, list[dict]] = {}  # seq -> formatted blocks

    if extension == ".docx":
        docx_result = _extract_formatted_docx(file_bytes)
        if docx_result is None:
            logger.warning("document.process.unsupported", doc_id=str(doc_id), ext=extension)
            return 0
        plain_text, all_formatted = docx_result
        raw_text = _sanitize_text_for_db(plain_text)
        chunks = _chunk_markdown(raw_text)
        page_count = len(chunks)
        all_text = raw_text

        # Map formatted blocks to chunks by matching text content
        # Each chunk gets the formatted blocks whose text falls within it
        fmt_cursor = 0
        for chunk in chunks:
            chunk_blocks: list[dict] = []
            chunk_plain = chunk["text"]
            chars_remaining = len(chunk_plain)
            while fmt_cursor < len(all_formatted) and chars_remaining > 0:
                block = all_formatted[fmt_cursor]
                block_text = "".join(r["text"] for r in block["runs"])
                chars_remaining -= len(block_text) + 2  # +2 for \n\n separator
                chunk_blocks.append(block)
                fmt_cursor += 1
            formatted_by_chunk[chunk["seq"]] = chunk_blocks

    elif extension == ".pdf":
        pdf_result = _extract_formatted_pdf(file_bytes)
        if pdf_result is None:
            logger.warning("document.process.unsupported", doc_id=str(doc_id), ext=extension)
            return 0
        pages, per_page_formatted = pdf_result
        chunks = _chunk_by_pages(pages)
        page_count = len(pages)
        all_text = " ".join(p["text"] for p in pages)

        # Map formatted blocks by page number -> chunk seq
        page_fmt: dict[int, list[dict]] = {}
        for pg, fmt_blocks in zip(pages, per_page_formatted):
            page_fmt[pg["page_number"]] = fmt_blocks
        for chunk in chunks:
            pn = chunk.get("page_number", 1)
            if pn in page_fmt:
                formatted_by_chunk[chunk["seq"]] = page_fmt[pn]

    else:
        extracted = _extract_text(file_bytes, extension)
        if extracted is None:
            logger.warning("document.process.unsupported", doc_id=str(doc_id), ext=extension)
            return 0
        raw_text = _sanitize_text_for_db(extracted)
        chunks = _chunk_markdown(raw_text)
        page_count = len(chunks)
        all_text = raw_text

    if not chunks:
        return 0

    word_count = len([w for w in re.split(r"\s+", all_text.strip()) if w])

    insert_chunk_sql = text(
        "INSERT INTO document_chunks "
        "(id, document_id, sequence_index, chunk_type, text_content, tone, page_number, character_count, metadata_json, formatted_content) "
        "VALUES (:id, :doc_id, :seq, :ctype, :txt, :tone, :page, :chars, :meta, :fmt)"
    )

    for chunk in chunks:
        chunk_id = uuid4()
        chunk_text = chunk["text"]
        boundaries = _build_sentence_boundaries(chunk_text)
        existing_meta = chunk.get("metadata_json") or {}
        existing_meta["sentence_boundaries"] = boundaries
        chunk["metadata_json"] = existing_meta
        meta_json = json.dumps({"title": chunk["title"], **chunk["metadata_json"]})

        fmt_content = formatted_by_chunk.get(chunk["seq"])
        fmt_json = json.dumps(fmt_content, ensure_ascii=False) if fmt_content else None

        await db.execute(
            insert_chunk_sql,
            {
                "id": chunk_id,
                "doc_id": doc_id,
                "seq": chunk["seq"],
                "ctype": "text",
                "txt": chunk["text"],
                "tone": "neutral",
                "page": chunk.get("page_number", 1),
                "chars": len(chunk["text"]),
                "meta": meta_json,
                "fmt": fmt_json,
            },
        )

    await db.execute(
        text(
            "UPDATE documents "
            "SET status = :st, page_count = :pc, word_count = :wc, updated_at = NOW() "
            "WHERE id = :did"
        ),
        {"st": "ready", "pc": page_count, "wc": word_count, "did": doc_id},
    )

    logger.info("document.processed", doc_id=str(doc_id), chunks=len(chunks))
    return len(chunks)


@router.post("/blank/", status_code=status.HTTP_201_CREATED)
async def create_blank_document(
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Create a blank document with a single empty chunk for direct writing."""
    from psitta.services.subscription_service import check_and_increment_doc_quota

    await check_and_increment_doc_quota(db, user_id)

    doc_id = uuid4()
    chunk_id = uuid4()
    now = datetime.now(timezone.utc)

    await db.execute(
        text(
            "INSERT INTO documents "
            "(id, user_id, title, source_type, status, file_size_bytes, storage_key, page_count, word_count, created_at, updated_at) "
            "VALUES "
            "(:id, :user_id, :title, :source_type, :status, 0, '', 1, 0, :now, :now)"
        ),
        {
            "id": doc_id,
            "user_id": str(user_id),
            "title": "Untitled Sheet",
            "source_type": "blank",
            "status": "ready",
            "now": now,
        },
    )

    await db.execute(
        text(
            "INSERT INTO document_chunks "
            "(id, document_id, sequence_index, text_content, character_count, created_at) "
            "VALUES "
            "(:id, :doc_id, 0, '', 0, :now)"
        ),
        {
            "id": chunk_id,
            "doc_id": doc_id,
            "now": now,
        },
    )

    logger.info("document.blank.created", doc_id=str(doc_id), chunk_id=str(chunk_id))

    return {
        "id": str(doc_id),
        "chunk_id": str(chunk_id),
        "title": "Untitled Sheet",
        "status": "ready",
        "source_type": "blank",
        "created_at": now.isoformat(),
    }


@router.post("/", status_code=status.HTTP_202_ACCEPTED)
async def upload_document(
    file: UploadFile,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    filename = file.filename or "unknown"
    extension = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""

    logger.info(
        "upload.trace.documents.upload.begin",
        filename=filename,
        extension=extension,
        user_id=str(user_id),
    )

    if extension not in ALLOWED_EXTENSIONS:
        logger.warning(
            "upload.trace.documents.upload.unsupported_extension",
            filename=filename,
            extension=extension,
            allowed_extensions=sorted(ALLOWED_EXTENSIONS),
        )
        raise HTTPException(status_code=415, detail="Unsupported file type")

    file_bytes = await file.read()
    file_size = len(file_bytes)

    doc_id = uuid4()
    logger.info(
        "upload.trace.documents.upload.file_read",
        filename=filename,
        extension=extension,
        file_size_bytes=file_size,
        doc_id=str(doc_id),
    )

    from psitta.services.audio_cache import put_raw_file
    try:
        logger.info(
            "upload.trace.documents.raw_persist.begin",
            doc_id=str(doc_id),
            filename=filename,
            extension=extension,
            file_size_bytes=file_size,
        )
        await put_raw_file(str(doc_id), extension, file_bytes)
        logger.info(
            "upload.trace.documents.raw_persist.end",
            doc_id=str(doc_id),
            filename=filename,
            extension=extension,
            file_size_bytes=file_size,
        )
    except Exception as e:
        logger.error(
            "upload.trace.documents.upload.abort",
            doc_id=str(doc_id),
            filename=filename,
            extension=extension,
            exception_type=type(e).__name__,
            exception_message=str(e),
        )
        logger.exception(
            "document.upload.raw_persist_failed",
            doc_id=str(doc_id),
            filename=filename,
            error=str(e),
        )
        raise HTTPException(
            status_code=503,
            detail="Original file storage unavailable. Upload aborted.",
        ) from e

    from psitta.services.subscription_service import check_and_increment_doc_quota
    await check_and_increment_doc_quota(db, user_id)

    title = filename.rsplit(".", 1)[0] if "." in filename else filename
    source_type = extension.lstrip(".")
    storage_key = f"uploads/{doc_id}{extension}"
    now = datetime.now(timezone.utc)

    await db.execute(
        text(
            "INSERT INTO documents "
            "(id, user_id, title, source_type, status, file_size_bytes, storage_key, page_count, word_count, created_at, updated_at) "
            "VALUES "
            "(:id, :user_id, :title, :source_type, :status, :file_size_bytes, :storage_key, :page_count, :word_count, :created_at, :updated_at)"
        ),
        {
            "id": doc_id,
            "user_id": str(user_id),
            "title": title,
            "source_type": source_type,
            "status": "uploaded",
            "file_size_bytes": file_size,
            "storage_key": storage_key,
            "page_count": 0,
            "word_count": 0,
            "created_at": now,
            "updated_at": now,
        },
    )

    chunk_count = await _process_document(doc_id, file_bytes, extension, db)
    doc_status = "ready" if chunk_count > 0 else "uploaded"
    if chunk_count > 0:
        background_tasks.add_task(_eager_synthesize_chunks, doc_id)
        logger.info("tts.eager_synthesis.queued", doc_id=str(doc_id), chunks=chunk_count)

    logger.info("document.upload.accepted", doc_id=str(doc_id), title=title, chunks=chunk_count)
    logger.info(
        "upload.trace.documents.upload.complete",
        doc_id=str(doc_id),
        title=title,
        source_type=source_type,
        status=doc_status,
        chunk_count=chunk_count,
    )

    return {
        "id": str(doc_id),
        "title": title,
        "status": doc_status,
        "source_type": source_type,
        "page_count": chunk_count,
        "created_at": now.isoformat(),
        "cover_type": None,
        "cover_value": None,
    }


@router.get("/")
async def list_documents(
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    show_archived: bool = False,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    offset = (page - 1) * size

    count_result = await db.execute(
        text(
            "SELECT COUNT(*) FROM documents WHERE user_id = :uid "
            "AND status != 'deleted' AND (:show_archived OR status != 'archived')"
        ),
        {"uid": str(user_id), "show_archived": show_archived},
    )
    total = count_result.scalar() or 0

    rows = await db.execute(
        text(
            "SELECT id, title, status, source_type, page_count, word_count, created_at, project_id, cover_type, cover_value "
            "FROM documents WHERE user_id = :uid "
            "AND status != 'deleted' AND (:show_archived OR status != 'archived') "
            "ORDER BY created_at DESC LIMIT :lim OFFSET :off"
        ),
        {"uid": str(user_id), "show_archived": show_archived, "lim": size, "off": offset},
    )

    items = [
        {
            "id": str(r.id),
            "title": r.title,
            "status": r.status,
            "source_type": r.source_type,
            "page_count": r.page_count,
            "word_count": getattr(r, "word_count", 0),
            "created_at": r.created_at.isoformat() if r.created_at else None,
            "project_id": str(r.project_id) if r.project_id else None,
            "cover_type": r.cover_type,
            "cover_value": r.cover_value,
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
        text(
            "SELECT id, title, status, source_type, page_count, word_count, file_size_bytes, created_at, cover_type, cover_value "
            "FROM documents WHERE id = :did"
        ),
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
        "word_count": getattr(row, "word_count", 0),
        "file_size_bytes": row.file_size_bytes,
        "created_at": row.created_at.isoformat() if row.created_at else None,
        "cover_type": row.cover_type,
        "cover_value": row.cover_value,
    }


@router.get("/{document_id}/chunks")
async def get_document_chunks(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Return all chunks for a document, ordered by sequence."""
    doc_result = await db.execute(
        text("SELECT id, status, source_type FROM documents WHERE id = :did"),
        {"did": document_id},
    )
    doc = doc_result.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    rows = await db.execute(
        text(
            "SELECT id, sequence_index, chunk_type, text_content, tone, page_number, character_count, metadata_json, "
            "is_edited, edited_at, original_text, formatted_content "
            "FROM document_chunks WHERE document_id = :did "
            "ORDER BY sequence_index"
        ),
        {"did": document_id},
    )

    chunks = []
    is_pdf_document = (getattr(doc, "source_type", "") or "").lower() == "pdf"
    for r in rows:
        meta = r.metadata_json if isinstance(r.metadata_json, dict) else {}
        text_content = r.text_content
        sentence_boundaries = meta.get("sentence_boundaries")
        character_count = r.character_count
        if is_pdf_document:
            text_content = _clean_pdf_chunk_text(r.text_content or "", r.page_number)
            sentence_boundaries = _build_sentence_boundaries(text_content)
            character_count = len(text_content)
        chunks.append(
            {
                "id": str(r.id),
                "sequence_index": r.sequence_index,
                "chunk_type": r.chunk_type,
                "title": meta.get("title", f"Section {r.sequence_index + 1}"),
                "text_content": text_content,
                "tone": r.tone,
                "page_number": r.page_number,
                "character_count": character_count,
                "is_edited": getattr(r, "is_edited", False),
                "edited_at": r.edited_at.isoformat() if getattr(r, "edited_at", None) else None,
                "original_text": getattr(r, "original_text", None),
                "sentence_boundaries": sentence_boundaries,
                "formatted_content": r.formatted_content if hasattr(r, "formatted_content") else None,
            }
        )

    return {
        "document_id": str(document_id),
        "status": doc.status,
        "total_chunks": len(chunks),
        "chunks": chunks,
    }


@router.get("/{document_id}/chunks/{chunk_id}/audio")
async def get_chunk_audio(
    document_id: UUID,
    chunk_id: UUID,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    db: AsyncSession = Depends(get_db_session),
) -> None:
    """Stream audio for a specific chunk. Auto-synthesizes on cache miss."""
    from fastapi.responses import FileResponse

    from psitta.services.audio_cache import get_mp3, put_mp3, s3_key_mp3

    # Get chunk text
    chunk_result = await db.execute(
        text(
            "SELECT c.text_content, c.page_number, d.source_type "
            "FROM document_chunks c "
            "JOIN documents d ON d.id = c.document_id "
            "WHERE c.id = :cid AND c.document_id = :did"
        ),
        {"cid": chunk_id, "did": document_id},
    )
    chunk_row = chunk_result.first()
    if not chunk_row or not chunk_row.text_content:
        raise HTTPException(status_code=404, detail="Chunk not found")

    source_type = (getattr(chunk_row, "source_type", "") or "").lower()
    chunk_text = chunk_row.text_content
    if source_type == "pdf":
        chunk_text = _clean_pdf_chunk_text(chunk_text, getattr(chunk_row, "page_number", None))

    cached = await get_mp3(str(chunk_id), voice_id)
    if cached and chunk_text == chunk_row.text_content:
        return FileResponse(cached, media_type="audio/mpeg", filename=f"{chunk_id}.mp3")

    logger.info("audio.cache_miss", chunk_id=str(chunk_id), voice_id=voice_id)

    # Synthesize
    from psitta.providers.tts_router import TTSRouter
    tts = TTSRouter()
    try:
        audio_bytes = await tts.synthesize(chunk_text, voice_id)
    except Exception as e:
        logger.error("audio.synthesize_failed", error=str(e), voice_id=voice_id)
        raise HTTPException(status_code=502, detail=f"TTS synthesis failed: {e}")

    # Save to local + S3
    local_path = await put_mp3(str(chunk_id), voice_id, audio_bytes)
    storage_key = s3_key_mp3(str(chunk_id), voice_id)

    # Insert cache record (delete stale row first to avoid unique constraint)
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

    return FileResponse(local_path, media_type="audio/mpeg", filename=f"{chunk_id}.mp3")


@router.get("/{document_id}/chunks/{chunk_id}/alignment")
async def get_chunk_alignment(
    document_id: UUID,
    chunk_id: UUID,
    voice_id: str = "21m00Tcm4TlvDq8ikWAM",
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Return alignment (timing) metadata for a chunk+voice.

    This does NOT change the /audio endpoint content-type.
    Alignment is stored as a sidecar JSON file next to the cached mp3.

    Path:
      S3: audio/{chunk_id}_{voice_id}.alignment.json
      Local cache: /tmp/psitta_audio/{chunk_id}_{voice_id}.alignment.json (ephemeral)
    """
    import json

    from psitta.services.audio_cache import get_alignment, put_alignment, put_mp3, s3_key_mp3

    # Non-ElevenLabs voices cannot produce alignment data.
    # Skip synthesis entirely and cache a null-alignment payload.
    if voice_id.startswith("en-") and voice_id.endswith("Neural"):
        payload = {
            "document_id": str(document_id),
            "chunk_id": str(chunk_id),
            "voice_id": voice_id,
            "provider": "azure",
            "alignment": None,
        }
        await put_alignment(str(chunk_id), voice_id, payload)
        return payload

    # Load chunk text
    chunk_result = await db.execute(
        text(
            "SELECT c.text_content, c.page_number, d.source_type "
            "FROM document_chunks c "
            "JOIN documents d ON d.id = c.document_id "
            "WHERE c.id = :cid AND c.document_id = :did"
        ),
        {"cid": chunk_id, "did": document_id},
    )
    chunk_row = chunk_result.first()
    if not chunk_row or not chunk_row.text_content:
        raise HTTPException(status_code=404, detail="Chunk not found")

    source_type = (getattr(chunk_row, "source_type", "") or "").lower()
    chunk_text = chunk_row.text_content
    if source_type == "pdf":
        chunk_text = _clean_pdf_chunk_text(chunk_text, getattr(chunk_row, "page_number", None))

    cached = await get_alignment(str(chunk_id), voice_id)
    if cached and chunk_text == chunk_row.text_content:
        return cached

    # Synthesize with optional alignment
    from psitta.providers.tts_router import TTSRouter

    tts = TTSRouter()
    try:
        audio_bytes, alignment, provider = await tts.synthesize_with_alignment(
            chunk_text,
            voice_id,
        )
    except Exception as e:
        logger.error("audio.alignment_failed", error=str(e), voice_id=voice_id)
        raise HTTPException(status_code=502, detail=f"TTS alignment failed: {e}")

    # Only ElevenLabs produces valid alignment timestamps.
    # If a fallback provider was used, discard alignment to prevent
    # mismatched timestamps against audio from a different provider.
    if provider != "elevenlabs" and alignment is not None:
        logger.warning(
            "audio.alignment_discarded",
            provider=provider,
            voice_id=voice_id,
            reason="alignment only valid for elevenlabs",
        )
        alignment = None

    # Persist mp3 + alignment to local + S3
    await put_mp3(str(chunk_id), voice_id, audio_bytes)

    payload = {
        "document_id": str(document_id),
        "chunk_id": str(chunk_id),
        "voice_id": voice_id,
        "provider": provider,
        "alignment": alignment,
    }
    await put_alignment(str(chunk_id), voice_id, payload)

    # Ensure audio_segments cache record exists/updated (best-effort).
    # We keep the existing schema; duration is approximate if unknown.
    try:
        result = await db.execute(
            text("SELECT storage_key FROM audio_segments WHERE chunk_id = :cid AND voice_id = :vid"),
            {"cid": chunk_id, "vid": voice_id},
        )
        row = result.first()
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
                "key": s3_key_mp3(str(chunk_id), voice_id),
                "dur": int(len(audio_bytes) / 24),
                "size": len(audio_bytes),
                "fmt": "mp3",
            },
        )
        await db.commit()
    except Exception as e:
        logger.warning("audio.alignment_cache_db_failed", error=str(e), chunk_id=str(chunk_id), voice_id=voice_id)

    return payload


async def _invalidate_chunk_audio_cache(chunk_id: UUID, db: AsyncSession) -> None:
    """Delete all audio_segments rows for a chunk so next request re-synthesizes.

    Clears all three cache layers:
      1. S3/MinIO objects (mp3 + alignment sidecar)
      2. Local /tmp cache files
      3. Database audio_segments rows
    """
    import glob as _glob
    import os
    from psitta.services.audio_cache import AUDIO_DIR

    logger.info("cache_invalidation.start", chunk_id=str(chunk_id))

    # 1. Delete ALL S3 objects with prefix audio/{chunk_id}_
    #    This doesn't depend on audio_segments DB rows existing.
    try:
        from psitta.config import get_settings
        from psitta.providers.storage_s3 import S3StorageProvider
        s3 = S3StorageProvider(get_settings())
        bucket = get_settings().S3_BUCKET_NAME
        prefix = f"audio/{chunk_id}_"
        deleted_count = await s3.delete_by_prefix(bucket, prefix)
        logger.info("cache_invalidation.s3_done", chunk_id=str(chunk_id), prefix=prefix, deleted=deleted_count)
    except Exception as e:
        logger.error("cache_invalidation.s3_failed", chunk_id=str(chunk_id), error=str(e))

    # 2. Delete local cache files
    pattern = os.path.join(AUDIO_DIR, f"{chunk_id}_*")
    matched = _glob.glob(pattern)
    logger.info("cache_invalidation.local_files", pattern=pattern, matched=matched)
    for path in matched:
        try:
            os.remove(path)
        except OSError as e:
            logger.error("cache_invalidation.local_delete_failed", path=path, error=str(e))

    # 3. Delete DB rows
    result = await db.execute(
        text("DELETE FROM audio_segments WHERE chunk_id = :cid"),
        {"cid": chunk_id},
    )
    logger.info("cache_invalidation.db_delete", chunk_id=str(chunk_id), rows_deleted=result.rowcount)


def _rebuild_formatted_content_for_chunk(
    text_content: str,
    existing_formatted: list[dict] | None,
) -> list[dict]:
    paragraphs = [p.strip() for p in re.split(r"\n\s*\n", text_content) if p.strip()]
    if not paragraphs:
        return []

    existing_blocks = existing_formatted if isinstance(existing_formatted, list) else []
    rebuilt: list[dict] = []

    for index, paragraph in enumerate(paragraphs):
        previous = existing_blocks[index] if index < len(existing_blocks) and isinstance(existing_blocks[index], dict) else {}
        previous_runs = previous.get("runs") if isinstance(previous.get("runs"), list) else []
        first_run = previous_runs[0] if previous_runs and isinstance(previous_runs[0], dict) else {}

        block_type = previous.get("type", "paragraph")
        block: dict = {
            "type": block_type,
            "runs": [{
                "text": paragraph,
                "bold": bool(first_run.get("bold", False)),
                "italic": bool(first_run.get("italic", False)),
                "underline": bool(first_run.get("underline", False)),
                "font_size": first_run.get("font_size"),
            }],
        }
        if previous.get("level") is not None:
            block["level"] = previous["level"]
        rebuilt.append(block)

    return rebuilt


@router.patch("/{document_id}/chunks/{chunk_id}", response_model=ChunkResponse)
async def update_chunk_text(
    document_id: UUID,
    chunk_id: UUID,
    request: ChunkUpdateRequest,
    db: AsyncSession = Depends(get_db_session),
) -> ChunkResponse:
    """Update the text content of a chunk. Stores original text on first edit."""
    result = await db.execute(
        text(
            "SELECT id, sequence_index, chunk_type, text_content, tone, page_number, "
            "character_count, is_edited, edited_at, original_text, metadata_json, formatted_content "
            "FROM document_chunks WHERE id = :cid AND document_id = :did"
        ),
        {"cid": chunk_id, "did": document_id},
    )
    chunk = result.first()
    if not chunk:
        raise HTTPException(status_code=404, detail="Chunk not found")

    import re as _re
    import unicodedata

    # Normalize unicode, remove invisible characters that break TTS
    new_text = request.text.strip()
    new_text = new_text.replace('\u200B', '').replace('\u200C', '')
    new_text = new_text.replace('\u200D', '').replace('\u00AD', '')
    new_text = new_text.replace('\uFEFF', '').replace('\u00A0', ' ')
    new_text = _re.sub(r' {2,}', ' ', new_text)
    new_text = unicodedata.normalize('NFC', new_text)

    now = datetime.now(timezone.utc)
    existing_meta = chunk.metadata_json if isinstance(chunk.metadata_json, dict) else {}
    segmenter = pysbd.Segmenter(language="en", clean=False)
    sentences = segmenter.segment(new_text)
    boundaries: list[list[int]] = []
    cursor = 0
    for sentence in sentences:
        start = new_text.index(sentence, cursor)
        end = start + len(sentence)
        boundaries.append([start, end])
        cursor = end

    updated_meta = {**existing_meta, "sentence_boundaries": boundaries}
    updated_formatted = _rebuild_formatted_content_for_chunk(
        new_text,
        chunk.formatted_content if isinstance(chunk.formatted_content, list) else None,
    )
    meta_json = json.dumps(updated_meta, ensure_ascii=False)
    fmt_json = json.dumps(updated_formatted, ensure_ascii=False) if updated_formatted else None

    # Store original text on first edit only
    if not chunk.is_edited:
        await db.execute(
            text(
                "UPDATE document_chunks "
                "SET text_content = :txt, character_count = :chars, "
                "metadata_json = CAST(:meta AS jsonb), "
                "formatted_content = CAST(:fmt AS jsonb), "
                "is_edited = true, edited_at = :now, original_text = :orig "
                "WHERE id = :cid"
            ),
            {
                "cid": chunk_id,
                "txt": new_text,
                "chars": len(new_text),
                "meta": meta_json,
                "fmt": fmt_json,
                "now": now,
                "orig": chunk.text_content,
            },
        )
    else:
        await db.execute(
            text(
                "UPDATE document_chunks "
                "SET text_content = :txt, character_count = :chars, "
                "metadata_json = CAST(:meta AS jsonb), "
                "formatted_content = CAST(:fmt AS jsonb), "
                "edited_at = :now "
                "WHERE id = :cid"
            ),
            {
                "cid": chunk_id,
                "txt": new_text,
                "chars": len(new_text),
                "meta": meta_json,
                "fmt": fmt_json,
                "now": now,
            },
        )

    # Invalidate audio cache for this chunk
    await _invalidate_chunk_audio_cache(chunk_id, db)

    await db.commit()

    logger.info("chunk.updated", chunk_id=str(chunk_id), document_id=str(document_id))

    return ChunkResponse(
        id=str(chunk.id),
        sequence_index=chunk.sequence_index,
        chunk_type=chunk.chunk_type if isinstance(chunk.chunk_type, str) else str(chunk.chunk_type),
        text_content=new_text,
        tone=chunk.tone if isinstance(chunk.tone, str) else str(chunk.tone),
        page_number=chunk.page_number,
        character_count=len(new_text),
        is_edited=True,
        edited_at=now,
        original_text=chunk.original_text if chunk.is_edited else chunk.text_content,
    )


@router.post("/{document_id}/chunks/{chunk_id}/resynthesize", response_model=ResynthesizeResponse)
async def resynthesize_chunk(
    document_id: UUID,
    chunk_id: UUID,
    voice_id: str = Query(default="21m00Tcm4TlvDq8ikWAM"),
    speed: float = Query(default=1.0),
    db: AsyncSession = Depends(get_db_session),
) -> ResynthesizeResponse:
    """Re-synthesize audio for an edited chunk using its current text_content."""
    result = await db.execute(
        text(
            "SELECT id FROM document_chunks WHERE id = :cid AND document_id = :did"
        ),
        {"cid": chunk_id, "did": document_id},
    )
    if not result.first():
        raise HTTPException(status_code=404, detail="Chunk not found")

    # Invalidate cache so next audio request re-synthesizes
    await _invalidate_chunk_audio_cache(chunk_id, db)
    await db.commit()

    audio_url = f"/api/v1/documents/{document_id}/chunks/{chunk_id}/audio?voice_id={voice_id}&speed={speed}"

    logger.info("chunk.resynthesize", chunk_id=str(chunk_id), voice_id=voice_id)

    return ResynthesizeResponse(
        chunk_id=str(chunk_id),
        audio_url=audio_url,
        message="Cache invalidated. Next audio request will re-synthesize with updated text.",
    )


class DocumentUpdateRequest(BaseModel):
    title: str | None = Field(None, min_length=1, max_length=200)
    cover_type: str | None = None
    cover_value: str | None = None


@router.patch("/{document_id}")
async def update_document(
    document_id: UUID,
    payload: DocumentUpdateRequest,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Update editable document fields (title, cover_type, cover_value)."""
    # Build dynamic SET clause based on provided fields
    set_parts: list[str] = []
    params: dict = {"did": document_id, "uid": str(user_id)}
    updated_fields: list[str] = []

    if payload.title is not None:
        set_parts.append("title = :title")
        params["title"] = payload.title.strip()
        updated_fields.append("title")

    # Use model_fields_set to detect explicitly-sent fields (including null for "remove")
    cover_type_sent = 'cover_type' in payload.model_fields_set
    cover_value_sent = 'cover_value' in payload.model_fields_set

    if cover_type_sent or cover_value_sent:
        # Fetch current cover info to check if we need to delete old uploaded cover
        cur_result = await db.execute(
            text("SELECT cover_type, cover_value FROM documents WHERE id = :did AND user_id = :uid AND status != 'deleted'"),
            {"did": document_id, "uid": str(user_id)},
        )
        cur_row = cur_result.first()
        if not cur_row:
            raise HTTPException(status_code=404, detail="Document not found")

        old_cover_type = cur_row.cover_type
        old_cover_value = cur_row.cover_value

        if cover_type_sent:
            set_parts.append("cover_type = :cover_type")
            params["cover_type"] = payload.cover_type
            updated_fields.append("cover_type")

        if cover_value_sent:
            set_parts.append("cover_value = :cover_value")
            params["cover_value"] = payload.cover_value
            updated_fields.append("cover_value")

        # If old cover was uploaded and we're changing away from it, delete from S3
        new_cover_type = payload.cover_type if cover_type_sent else old_cover_type
        if old_cover_type == "uploaded" and new_cover_type != "uploaded" and old_cover_value:
            try:
                from psitta.config import get_settings
                from psitta.providers.storage_s3 import S3StorageProvider
                settings = get_settings()
                s3 = S3StorageProvider(settings)
                bucket = settings.S3_BUCKET_NAME
                await s3.delete_by_prefix(bucket, f"covers/{document_id}.")
                logger.info("document.cover.s3_deleted", doc_id=str(document_id))
            except Exception as e:
                logger.error("document.cover.s3_delete_failed", doc_id=str(document_id), error=str(e))

    if not set_parts:
        raise HTTPException(status_code=400, detail="No fields to update")

    set_parts.append("updated_at = NOW()")
    set_clause = ", ".join(set_parts)

    result = await db.execute(
        text(
            f"UPDATE documents SET {set_clause} "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        params,
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Document not found")

    await db.commit()

    row = await db.execute(
        text(
            "SELECT id, user_id, title, status, source_type, page_count, word_count, "
            "file_size_bytes, created_at, updated_at, cover_type, cover_value "
            "FROM documents WHERE id = :did"
        ),
        {"did": document_id},
    )
    doc = row.first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    logger.info("document.updated", doc_id=str(document_id), fields=updated_fields)

    return {
        "id": str(doc.id),
        "title": doc.title,
        "status": doc.status,
        "source_type": doc.source_type,
        "page_count": doc.page_count,
        "word_count": getattr(doc, "word_count", 0),
        "file_size_bytes": doc.file_size_bytes,
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
        "updated_at": doc.updated_at.isoformat() if doc.updated_at else None,
        "cover_type": doc.cover_type,
        "cover_value": doc.cover_value,
    }


@router.post("/{document_id}/cover")
async def upload_cover(
    document_id: UUID,
    file: UploadFile,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Upload a cover image for a document."""
    # Validate document exists
    doc_result = await db.execute(
        text(
            "SELECT id, cover_type, cover_value FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    doc_row = doc_result.first()
    if not doc_row:
        raise HTTPException(status_code=404, detail="Document not found")

    # Validate file type by extension
    filename = file.filename or "unknown"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    allowed_image_exts = {"jpeg", "jpg", "gif", "png"}
    if ext not in allowed_image_exts:
        raise HTTPException(status_code=415, detail="Unsupported image type. Allowed: jpeg, jpg, gif, png")

    # Validate content type
    content_type = file.content_type or ""
    allowed_content_types = {"image/jpeg", "image/jpg", "image/gif", "image/png"}
    if content_type not in allowed_content_types:
        raise HTTPException(status_code=415, detail=f"Unsupported content type: {content_type}")

    # Read and validate size (max 2MB)
    file_bytes = await file.read()
    max_size = 2 * 1024 * 1024
    if len(file_bytes) > max_size:
        raise HTTPException(status_code=413, detail="Image too large. Please use an image under 2MB.")

    # Always resize with Pillow (max 400x400, maintain aspect ratio)
    try:
        from PIL import Image

        img = Image.open(io.BytesIO(file_bytes))

        # GIF: extract first frame only, convert to RGBA then save as PNG
        if ext == "gif":
            img = img.convert("RGBA")
            ext = "png"

        # Fit within 400x400 box maintaining aspect ratio
        max_dim = 400
        if img.width > max_dim or img.height > max_dim:
            img.thumbnail((max_dim, max_dim), Image.LANCZOS)

        buf = io.BytesIO()
        out_format = "PNG" if ext == "png" else "JPEG"
        save_kwargs = {"quality": 80} if out_format == "JPEG" else {}
        if out_format == "JPEG" and img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        img.save(buf, format=out_format, **save_kwargs)
        file_bytes = buf.getvalue()
        logger.info("document.cover.resized", doc_id=str(document_id),
                     width=img.width, height=img.height, format=out_format,
                     size=len(file_bytes))
    except ImportError:
        logger.warning("document.cover.pillow_unavailable", doc_id=str(document_id))
    except Exception as e:
        logger.warning("document.cover.resize_failed", doc_id=str(document_id), error=str(e))

    # Delete old cover from S3 if it existed
    old_cover_type = doc_row.cover_type
    old_cover_value = doc_row.cover_value
    if old_cover_type == "uploaded" and old_cover_value:
        try:
            from psitta.config import get_settings
            from psitta.providers.storage_s3 import S3StorageProvider
            settings = get_settings()
            s3 = S3StorageProvider(settings)
            bucket = settings.S3_BUCKET_NAME
            await s3.delete_by_prefix(bucket, f"covers/{document_id}.")
            logger.info("document.cover.old_deleted", doc_id=str(document_id))
        except Exception as e:
            logger.error("document.cover.old_delete_failed", doc_id=str(document_id), error=str(e))

    # Store in S3
    storage_key = f"covers/{document_id}.{ext}"
    content_type_map = {"jpeg": "image/jpeg", "jpg": "image/jpeg", "gif": "image/gif", "png": "image/png"}

    from psitta.config import get_settings
    from psitta.providers.storage_s3 import S3StorageProvider
    settings = get_settings()
    s3 = S3StorageProvider(settings)
    bucket = settings.S3_BUCKET_NAME
    await s3.put_object(bucket, storage_key, file_bytes, content_type=content_type_map.get(ext, "image/jpeg"))

    # Update document record
    await db.execute(
        text(
            "UPDATE documents SET cover_type = :ct, cover_value = :cv, updated_at = NOW() "
            "WHERE id = :did"
        ),
        {"ct": "uploaded", "cv": storage_key, "did": document_id},
    )
    await db.commit()

    logger.info("document.cover.uploaded", doc_id=str(document_id), key=storage_key, size=len(file_bytes))

    # Return updated document dict
    row = await db.execute(
        text(
            "SELECT id, title, status, source_type, page_count, word_count, "
            "file_size_bytes, created_at, updated_at, cover_type, cover_value "
            "FROM documents WHERE id = :did"
        ),
        {"did": document_id},
    )
    doc = row.first()
    return {
        "id": str(doc.id),
        "title": doc.title,
        "status": doc.status,
        "source_type": doc.source_type,
        "page_count": doc.page_count,
        "word_count": getattr(doc, "word_count", 0),
        "file_size_bytes": doc.file_size_bytes,
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
        "updated_at": doc.updated_at.isoformat() if doc.updated_at else None,
        "cover_type": doc.cover_type,
        "cover_value": doc.cover_value,
    }


@router.get("/{document_id}/cover")
async def get_cover(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Serve the uploaded cover image for a document."""
    from fastapi.responses import Response

    result = await db.execute(
        text(
            "SELECT cover_type, cover_value FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    if row.cover_type != "uploaded" or not row.cover_value:
        raise HTTPException(status_code=404, detail="No uploaded cover image")

    # Fetch from S3
    from psitta.config import get_settings
    from psitta.providers.storage_s3 import S3StorageProvider
    settings = get_settings()
    s3 = S3StorageProvider(settings)
    bucket = settings.S3_BUCKET_NAME

    try:
        image_bytes = await s3.get_object(bucket, row.cover_value)
    except Exception as e:
        logger.error("document.cover.fetch_failed", doc_id=str(document_id), error=str(e))
        raise HTTPException(status_code=404, detail="Cover image not found in storage")

    # Determine content type from key extension
    ext = row.cover_value.rsplit(".", 1)[-1].lower() if "." in row.cover_value else "jpeg"
    content_type_map = {"jpeg": "image/jpeg", "jpg": "image/jpeg", "gif": "image/gif", "png": "image/png"}
    media_type = content_type_map.get(ext, "image/jpeg")

    return Response(
        content=image_bytes,
        media_type=media_type,
        headers={"Cache-Control": "max-age=3600"},
    )


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> None:
    result = await db.execute(
        text(
            "UPDATE documents SET status = 'deleted', updated_at = NOW() "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Document not found")
    logger.info("document.deleted", doc_id=str(document_id))


@router.patch("/{document_id}/archive", status_code=status.HTTP_200_OK)
async def archive_document(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Toggle document between archived and ready status."""
    result = await db.execute(
        text(
            "SELECT status FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")
    new_status = "ready" if row.status == "archived" else "archived"
    await db.execute(
        text(
            "UPDATE documents SET status = :st, updated_at = NOW() "
            "WHERE id = :did AND user_id = :uid"
        ),
        {"st": new_status, "did": document_id, "uid": str(user_id)},
    )
    await db.commit()
    logger.info("document.archived", doc_id=str(document_id), new_status=new_status)
    return {"id": str(document_id), "status": new_status}


@router.patch("/{document_id}/project")
async def assign_project(
    document_id: str,
    body: dict,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Assign or remove a document from a project.
    Body: {"project_id": "<uuid>"} to assign, {"project_id": null} to remove.
    """
    project_id = body.get("project_id")
    # Verify document exists and belongs to authenticated user
    row = await db.execute(
        text("SELECT id FROM documents WHERE id = :id AND user_id = :uid AND status != 'deleted'"),
        {"id": document_id, "uid": str(user_id)},
    )
    if not row.mappings().first():
        raise HTTPException(status_code=404, detail="Document not found")
    # Verify project exists if assigning
    if project_id is not None:
        proj_row = await db.execute(
            text("SELECT id FROM projects WHERE id = :id AND user_id = :uid"),
            {"id": project_id, "uid": str(user_id)},
        )
        if not proj_row.mappings().first():
            raise HTTPException(status_code=404, detail="Project not found")
    await db.execute(
        text("UPDATE documents SET project_id = :pid WHERE id = :id"),
        {"pid": project_id, "id": document_id},
    )
    await db.commit()
    return {"id": document_id, "project_id": project_id}


@router.get("/{document_id}/download")
async def download_document(
    document_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> FileResponse:
    """Serve the original uploaded file for download."""
    result = await db.execute(
        text(
            "SELECT title, source_type, storage_key FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    from psitta.services.audio_cache import get_raw_file

    if not row.storage_key:
        raise HTTPException(status_code=404, detail="Original file not available for download")

    file_path = await get_raw_file(row.storage_key)
    if not file_path:
        raise HTTPException(status_code=404, detail="Original file not available for download")

    filename = f"{row.title}.{row.source_type}"
    return FileResponse(
        file_path,
        media_type="application/octet-stream",
        filename=filename,
    )


# ── Branded DOCX export ──────────────────────────────────────────────────────

_LOGO_PATH = Path(__file__).resolve().parents[1] / "assets" / "logo.png"


def _build_branded_docx(
    *,
    title: str,
    chunks: list[dict],
    project_name: str | None,
    include_cover: bool,
    include_footer: bool,
) -> bytes:
    """Build a branded DOCX from document chunks and return raw bytes."""
    from docx import Document as DocxDocument
    from docx.shared import Pt, Inches, RGBColor, Cm
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.oxml.ns import qn

    doc = DocxDocument()

    # ── Style defaults ────────────────────────────────────────────────
    style = doc.styles["Normal"]
    style.font.size = Pt(11)
    style.font.name = "Calibri"
    style.paragraph_format.space_after = Pt(6)

    has_logo = _LOGO_PATH.exists()

    # ── Cover page ────────────────────────────────────────────────────
    if include_cover:
        # Spacer at top
        for _ in range(6):
            doc.add_paragraph()

        # Logo
        if has_logo:
            logo_para = doc.add_paragraph()
            logo_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            logo_run = logo_para.add_run()
            logo_run.add_picture(str(_LOGO_PATH), width=Inches(2.0))

            doc.add_paragraph()

        # Title
        title_para = doc.add_paragraph()
        title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        title_run = title_para.add_run(title)
        title_run.bold = True
        title_run.font.size = Pt(26)
        title_run.font.color.rgb = RGBColor(0x2B, 0x2B, 0x2B)

        # Project / author
        if project_name:
            proj_para = doc.add_paragraph()
            proj_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            proj_run = proj_para.add_run(project_name)
            proj_run.font.size = Pt(14)
            proj_run.font.color.rgb = RGBColor(0x66, 0x66, 0x66)

        # Date
        date_para = doc.add_paragraph()
        date_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        date_run = date_para.add_run(datetime.now(timezone.utc).strftime("%B %d, %Y"))
        date_run.font.size = Pt(12)
        date_run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

        # Bottom branding
        for _ in range(4):
            doc.add_paragraph()
        brand_para = doc.add_paragraph()
        brand_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        brand_run = brand_para.add_run("Processed by Psitta")
        brand_run.font.size = Pt(10)
        brand_run.font.italic = True
        brand_run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

        # Page break after cover
        doc.add_page_break()

    # ── Document content ──────────────────────────────────────────────
    for chunk in chunks:
        chunk_title = chunk.get("title", "")
        chunk_text = chunk.get("text_content", "")

        if chunk_title:
            heading = doc.add_heading(chunk_title, level=2)
            for run in heading.runs:
                run.font.color.rgb = RGBColor(0x2B, 0x2B, 0x2B)

        for para_text in chunk_text.split("\n"):
            stripped = para_text.strip()
            if stripped:
                doc.add_paragraph(stripped)

    # ── Footer on every section ───────────────────────────────────────
    if include_footer:
        for section in doc.sections:
            footer = section.footer
            footer.is_linked_to_previous = False
            footer_para = footer.paragraphs[0] if footer.paragraphs else footer.add_paragraph()
            footer_para.clear()

            # Tab stops: left at 0, right at page width - margins
            page_width = section.page_width - section.left_margin - section.right_margin
            pPr = footer_para._p.get_or_add_pPr()
            tabs_elem = pPr.makeelement(qn("w:tabs"), {})
            # Right-aligned tab at the page width
            tab_right = tabs_elem.makeelement(qn("w:tab"), {
                qn("w:val"): "right",
                qn("w:pos"): str(int(page_width)),
            })
            tabs_elem.append(tab_right)
            pPr.append(tabs_elem)

            # Left side: branding text
            brand_run = footer_para.add_run("Processed by Psitta — Reading to Listening")
            brand_run.font.size = Pt(8)
            brand_run.font.italic = True
            brand_run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)

            # Tab to right side
            tab_run = footer_para.add_run("\t")
            tab_run.font.size = Pt(8)

            # Page number field
            page_run = footer_para.add_run()
            page_run.font.size = Pt(8)
            page_run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
            fld_char_begin = page_run._r.makeelement(qn("w:fldChar"), {qn("w:fldCharType"): "begin"})
            page_run._r.append(fld_char_begin)

            instr_run = footer_para.add_run()
            instr_run.font.size = Pt(8)
            instr_run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
            instr_text = instr_run._r.makeelement(qn("w:instrText"), {})
            instr_text.text = " PAGE "
            instr_run._r.append(instr_text)

            end_run = footer_para.add_run()
            end_run.font.size = Pt(8)
            fld_char_end = end_run._r.makeelement(qn("w:fldChar"), {qn("w:fldCharType"): "end"})
            end_run._r.append(fld_char_end)

    # ── Serialize to bytes ────────────────────────────────────────────
    buf = io.BytesIO()
    doc.save(buf)
    return buf.getvalue()


@router.get("/{document_id}/export")
async def export_document(
    document_id: UUID,
    include_cover: bool = Query(True, alias="cover"),
    include_footer: bool = Query(True, alias="footer"),
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
):
    """Export document as a branded DOCX file."""
    # Fetch document metadata
    result = await db.execute(
        text(
            "SELECT title, project_id FROM documents "
            "WHERE id = :did AND user_id = :uid AND status != 'deleted'"
        ),
        {"did": document_id, "uid": str(user_id)},
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="Document not found")

    doc_title = row["title"]
    project_id = row["project_id"]

    # Resolve project name
    project_name = None
    if project_id:
        proj_result = await db.execute(
            text("SELECT name FROM projects WHERE id = :pid"),
            {"pid": project_id},
        )
        proj_row = proj_result.mappings().first()
        if proj_row:
            project_name = proj_row["name"]

    # Fetch chunks
    chunks_result = await db.execute(
        text(
            "SELECT sequence_index, text_content, metadata_json "
            "FROM document_chunks WHERE document_id = :did "
            "ORDER BY sequence_index"
        ),
        {"did": document_id},
    )
    chunks = []
    for r in chunks_result.mappings():
        meta = r["metadata_json"] if isinstance(r["metadata_json"], dict) else {}
        chunks.append({
            "title": meta.get("title", f"Section {r['sequence_index'] + 1}"),
            "text_content": r["text_content"] or "",
        })

    if not chunks:
        raise HTTPException(status_code=404, detail="No content to export")

    docx_bytes = _build_branded_docx(
        title=doc_title,
        chunks=chunks,
        project_name=project_name,
        include_cover=include_cover,
        include_footer=include_footer,
    )

    filename = f"{doc_title}.docx"
    return StreamingResponse(
        io.BytesIO(docx_bytes),
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


async def _eager_synthesize_chunks(doc_id: UUID) -> None:
    """Pre-synthesize all chunks in background after upload."""
    import asyncio
    DEFAULT_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"
    await asyncio.sleep(2)
    try:
        from psitta.db.session import async_session_factory
        from psitta.providers.tts_router import TTSRouter
        from psitta.services.audio_cache import get_mp3, put_mp3
        logger.info("tts.eager_synthesis.start", doc_id=str(doc_id))
        async with async_session_factory() as db:
            result = await db.execute(
                text(
                    "SELECT id, text_content FROM document_chunks "
                    "WHERE document_id = :doc_id ORDER BY sequence_index"
                ),
                {"doc_id": doc_id},
            )
            chunks = result.fetchall()
        if not chunks:
            logger.warning("tts.eager_synthesis.no_chunks", doc_id=str(doc_id))
            return
        logger.info("tts.eager_synthesis.chunks_found", doc_id=str(doc_id), count=len(chunks))
        tts = TTSRouter()
        synthesized = 0
        skipped = 0
        failed = 0
        for row in chunks:
            chunk_id = str(row[0])
            chunk_text = row[1] or ""
            if not chunk_text.strip():
                skipped += 1
                continue
            cached = await get_mp3(chunk_id, DEFAULT_VOICE_ID)
            if cached:
                skipped += 1
                continue
            try:
                audio_bytes = await tts.synthesize(chunk_text, DEFAULT_VOICE_ID)
                await put_mp3(chunk_id, DEFAULT_VOICE_ID, audio_bytes)
                synthesized += 1
                logger.info("tts.eager_synthesis.chunk_done", doc_id=str(doc_id), chunk_id=chunk_id, size=len(audio_bytes))
            except Exception as e:
                failed += 1
                logger.warning("tts.eager_synthesis.chunk_failed", doc_id=str(doc_id), chunk_id=chunk_id, error=str(e))
        logger.info("tts.eager_synthesis.complete", doc_id=str(doc_id), synthesized=synthesized, skipped=skipped, failed=failed)
    except Exception as e:
        logger.error("tts.eager_synthesis.fatal", doc_id=str(doc_id), error=str(e))
