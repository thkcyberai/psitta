"""Psitta — Blueprint Service (read surface, Phase 2B).

Module-level async free functions (mirrors ``audit_service`` /
``subscription_service``), argument order ``(db, user_id, ...)``. Read-only:
no writes, no audit. Visibility rule for every read is the same — a caller
sees system templates (``is_system AND user_id IS NULL``) plus their own
blueprints, and nothing else.

The parts tree is assembled in Python from a single flat, ``sort_order``-ordered
query. The recursive-CTE walk is deliberately reserved for the 2G coherence
engine; for a read of one blueprint's parts, a flat fetch + in-memory grouping
is simpler and cheaper.
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.models.blueprint import Blueprint, BlueprintPart
from psitta.schemas.api import PartNode


def _build_parts_tree(parts: list[BlueprintPart]) -> list[PartNode]:
    """Assemble flat, ``sort_order``-ordered parts into nested ``PartNode`` trees.

    ``parts`` must already be ordered by ``sort_order`` (ascending). Because the
    input is globally ordered, appending children as we encounter them preserves
    per-sibling order, and roots come out in order too. A part whose
    ``parent_part_id`` is missing from the set (should never happen given the
    composite same-blueprint FK) is defensively treated as a root.
    """
    nodes: dict[UUID, PartNode] = {
        p.id: PartNode(
            id=p.id,
            name=p.name,
            description=p.description,
            sort_order=float(p.sort_order),
            children=[],
        )
        for p in parts
    }
    roots: list[PartNode] = []
    for p in parts:
        node = nodes[p.id]
        if p.parent_part_id is None:
            roots.append(node)
            continue
        parent = nodes.get(p.parent_part_id)
        if parent is None:
            roots.append(node)
        else:
            parent.children.append(node)
    return roots


async def list_blueprints(
    db: AsyncSession,
    user_id: UUID,
    kind: str | None = None,
) -> list[Blueprint]:
    """Return blueprints visible to ``user_id``: system templates + own.

    ``kind`` is reserved for future filtering; by default both kinds are
    returned. ``"system"`` restricts to system templates, ``"user"`` to the
    caller's own blueprints. Ordered system-first, then by name.
    """
    stmt = select(Blueprint).where(
        or_(
            and_(Blueprint.is_system.is_(True), Blueprint.user_id.is_(None)),
            Blueprint.user_id == user_id,
        )
    )
    if kind == "system":
        stmt = stmt.where(Blueprint.is_system.is_(True))
    elif kind == "user":
        stmt = stmt.where(Blueprint.user_id == user_id)
    stmt = stmt.order_by(Blueprint.is_system.desc(), Blueprint.name)

    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_blueprint(
    db: AsyncSession,
    user_id: UUID,
    blueprint_id: UUID,
) -> tuple[Blueprint, list[PartNode]] | None:
    """Return ``(blueprint, parts_tree)`` visible to ``user_id``, else ``None``.

    Visible = the blueprint is a system template OR owned by the caller. A
    miss (absent, or present-but-foreign) returns ``None`` so the route can
    answer 404 identically in both cases (no existence disclosure).

    On a hit, the blueprint's parts are fetched flat (ordered by ``sort_order``)
    and assembled into nested ``PartNode`` trees, returned alongside the row.
    The ORM's flat ``.parts`` relationship is never read.
    """
    stmt = select(Blueprint).where(
        Blueprint.id == blueprint_id,
        or_(Blueprint.is_system.is_(True), Blueprint.user_id == user_id),
    )
    blueprint = (await db.execute(stmt)).scalar_one_or_none()
    if blueprint is None:
        return None

    parts_stmt = (
        select(BlueprintPart)
        .where(BlueprintPart.blueprint_id == blueprint_id)
        .order_by(BlueprintPart.sort_order)
    )
    parts = list((await db.execute(parts_stmt)).scalars().all())
    return blueprint, _build_parts_tree(parts)
