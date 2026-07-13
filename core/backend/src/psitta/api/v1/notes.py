"""
Psitta — Scribbles (notes) CRUD.

Short, colored text snippets for quick idea capture. User-scoped; every query
filters by ``user_id`` so a writer only ever sees their own notes.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID, uuid4

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.dependencies import get_current_user_id, get_db_session

logger = structlog.get_logger(__name__)

router = APIRouter()

_ALLOWED_COLORS = {"yellow", "pink", "blue", "green", "purple"}
_MAX_LEN = 5000


def _color(value: str | None) -> str:
    return value if value in _ALLOWED_COLORS else "yellow"


def _row_to_note(r) -> dict:
    return {
        "id": str(r.id),
        "content": r.content,
        "color": r.color,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "updated_at": r.updated_at.isoformat() if r.updated_at else None,
    }


class NoteCreate(BaseModel):
    content: str = Field(default="", max_length=_MAX_LEN)
    color: str = Field(default="yellow")


class NoteUpdate(BaseModel):
    content: str | None = Field(default=None, max_length=_MAX_LEN)
    color: str | None = None


@router.get("/", tags=["notes"])
async def list_notes(
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """List the writer's scribbles, most recently edited first."""
    rows = await db.execute(
        text(
            "SELECT id, content, color, created_at, updated_at FROM notes "
            "WHERE user_id = :uid ORDER BY updated_at DESC"
        ),
        {"uid": str(user_id)},
    )
    return {"items": [_row_to_note(r) for r in rows]}


@router.post("/", status_code=status.HTTP_201_CREATED, tags=["notes"])
async def create_note(
    body: NoteCreate,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Create a new scribble."""
    note_id = uuid4()
    now = datetime.now(timezone.utc)
    content = body.content[:_MAX_LEN]
    color = _color(body.color)
    await db.execute(
        text(
            "INSERT INTO notes (id, user_id, content, color, created_at, "
            "updated_at) VALUES (:id, :uid, :content, :color, :now, :now)"
        ),
        {
            "id": note_id,
            "uid": str(user_id),
            "content": content,
            "color": color,
            "now": now,
        },
    )
    await db.commit()
    logger.info("notes.created", user_id=str(user_id), note_id=str(note_id))
    return {
        "id": str(note_id),
        "content": content,
        "color": color,
        "created_at": now.isoformat(),
        "updated_at": now.isoformat(),
    }


@router.patch("/{note_id}", tags=["notes"])
async def update_note(
    note_id: UUID,
    body: NoteUpdate,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    """Update a scribble's text and/or color (owner only)."""
    updates: dict = {}
    if body.content is not None:
        updates["content"] = body.content[:_MAX_LEN]
    if body.color is not None:
        updates["color"] = _color(body.color)
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    # Column names are fixed literals (not user input); values are bound.
    set_clause = ", ".join(f"{k} = :{k}" for k in updates)
    result = await db.execute(
        text(  # noqa: S608 — fixed column names, params bound
            f"UPDATE notes SET {set_clause}, updated_at = NOW() "
            "WHERE id = :id AND user_id = :uid "
            "RETURNING id, content, color, created_at, updated_at"
        ),
        {**updates, "id": note_id, "uid": str(user_id)},
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Note not found")
    await db.commit()
    return _row_to_note(row)


@router.delete(
    "/{note_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["notes"],
    response_model=None,
)
async def delete_note(
    note_id: UUID,
    db: AsyncSession = Depends(get_db_session),
    user_id: UUID = Depends(get_current_user_id),
) -> None:
    """Permanently delete a scribble (owner only)."""
    result = await db.execute(
        text("DELETE FROM notes WHERE id = :id AND user_id = :uid"),
        {"id": note_id, "uid": str(user_id)},
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Note not found")
    await db.commit()
