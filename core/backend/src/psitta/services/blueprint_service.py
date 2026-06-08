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

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.models.blueprint import Blueprint, BlueprintPart
from psitta.schemas.api import (
    BlueprintCreate,
    BlueprintStatusEnum,
    BlueprintUpdate,
    PartNode,
)
from psitta.services import audit_service


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


async def load_blueprint_by_id(
    db: AsyncSession, blueprint_id: UUID
) -> Blueprint | None:
    """Fetch one blueprint by id with NO visibility filter.

    Ownership is classified by the route guard (system → 403, foreign → 404);
    this loader only answers "does the row exist".
    """
    stmt = select(Blueprint).where(Blueprint.id == blueprint_id)
    return (await db.execute(stmt)).scalar_one_or_none()


def _remap_cloned_parts(
    source_parts: list[BlueprintPart], new_blueprint_id: UUID
) -> list[BlueprintPart]:
    """Deep-copy parts into a new blueprint: fresh ids, parents remapped to the
    new ids, ``sort_order`` preserved. Pure (no DB); returns unpersisted rows.

    The same-blueprint composite FK guarantees every non-null
    ``parent_part_id`` is present in ``source_parts``, so the id map always
    resolves a parent.
    """
    id_map: dict[UUID, UUID] = {p.id: uuid4() for p in source_parts}
    cloned: list[BlueprintPart] = []
    for p in source_parts:
        cloned.append(
            BlueprintPart(
                id=id_map[p.id],
                blueprint_id=new_blueprint_id,
                parent_part_id=(
                    id_map[p.parent_part_id]
                    if p.parent_part_id is not None
                    else None
                ),
                name=p.name,
                description=p.description,
                sort_order=p.sort_order,
            )
        )
    return cloned


async def create_blueprint(
    db: AsyncSession,
    user_id: UUID,
    data: BlueprintCreate,
    ip_address: str | None = None,
) -> Blueprint:
    """Create an empty user-owned blueprint, audit, and commit atomically."""
    blueprint = Blueprint(
        user_id=user_id,
        is_system=False,
        name=data.name,
        description=data.description,
        genre=data.genre.value,
        status=data.status.value,
        source_template_id=None,
    )
    db.add(blueprint)
    await db.flush()  # populate server-generated id
    await audit_service.log_event(
        db,
        action="blueprint.create",
        resource_type="blueprint",
        user_id=str(user_id),
        resource_id=str(blueprint.id),
        details={"name": blueprint.name, "genre": blueprint.genre},
        ip_address=ip_address,
    )
    await db.commit()
    return blueprint


async def clone_blueprint(
    db: AsyncSession,
    user_id: UUID,
    blueprint_id: UUID,
    name: str | None = None,
    ip_address: str | None = None,
) -> tuple[Blueprint, list[PartNode]] | None:
    """Clone any blueprint visible to the caller into a user-owned copy.

    Returns ``None`` if the source is not visible (absent, or a foreign user
    blueprint) so the route answers 404; system templates ARE cloneable. The
    new blueprint is caller-owned, ``is_system`` False, ``status`` Draft, with
    ``source_template_id`` set to the source. Its full parts tree is deep-copied
    with new ids and ``parent_part_id`` remapped; ``sort_order`` is preserved.

    Atomicity: the new blueprint row, every copied part, and the audit row are
    all written on the one request-scoped session and committed once. Parts are
    inserted parents-before-children (the composite FK is immediate, and the ORM
    has no self-referential relationship to order them), flushing per level. Any
    pre-commit error triggers the get_db_session rollback — all-or-nothing.
    """
    src_stmt = select(Blueprint).where(
        Blueprint.id == blueprint_id,
        or_(Blueprint.is_system.is_(True), Blueprint.user_id == user_id),
    )
    source = (await db.execute(src_stmt)).scalar_one_or_none()
    if source is None:
        return None

    parts_stmt = (
        select(BlueprintPart)
        .where(BlueprintPart.blueprint_id == blueprint_id)
        .order_by(BlueprintPart.sort_order)
    )
    source_parts = list((await db.execute(parts_stmt)).scalars().all())

    new_blueprint = Blueprint(
        user_id=user_id,
        is_system=False,
        name=name or source.name,
        description=source.description,
        genre=source.genre,
        status=BlueprintStatusEnum.DRAFT.value,
        source_template_id=source.id,
    )
    db.add(new_blueprint)
    await db.flush()  # populate new_blueprint.id before remapping parts

    new_parts = _remap_cloned_parts(source_parts, new_blueprint.id)

    # Insert parents before children: the (parent_part_id, blueprint_id) FK is
    # immediate and SQLAlchemy has no relationship to infer the order, so flush
    # one level at a time (roots, then their children, ...).
    inserted: set[UUID] = set()
    pending = list(new_parts)
    while pending:
        ready = [
            p
            for p in pending
            if p.parent_part_id is None or p.parent_part_id in inserted
        ]
        if not ready:
            break  # safeguard: an impossible cycle would otherwise loop forever
        db.add_all(ready)
        await db.flush()
        inserted.update(p.id for p in ready)
        pending = [p for p in pending if p.id not in inserted]

    await audit_service.log_event(
        db,
        action="blueprint.clone",
        resource_type="blueprint",
        user_id=str(user_id),
        resource_id=str(new_blueprint.id),
        details={
            "source_template_id": str(source.id),
            "part_count": len(new_parts),
            "name": new_blueprint.name,
        },
        ip_address=ip_address,
    )
    await db.commit()
    return new_blueprint, _build_parts_tree(new_parts)


async def update_blueprint(
    db: AsyncSession,
    user_id: UUID,
    blueprint: Blueprint,
    data: BlueprintUpdate,
    ip_address: str | None = None,
) -> Blueprint:
    """Apply a partial update to an already-authorized user blueprint.

    Only fields the client actually sent are applied (``exclude_unset``);
    ``mode="json"`` yields plain strings for the enum fields. ``updated_at`` is
    set explicitly (the model has no ``onupdate``).
    """
    changes = data.model_dump(exclude_unset=True, mode="json")
    for field, value in changes.items():
        setattr(blueprint, field, value)
    blueprint.updated_at = datetime.now(UTC)
    await audit_service.log_event(
        db,
        action="blueprint.update",
        resource_type="blueprint",
        user_id=str(user_id),
        resource_id=str(blueprint.id),
        details={"fields": list(changes.keys())},
        ip_address=ip_address,
    )
    await db.commit()
    return blueprint


async def delete_blueprint(
    db: AsyncSession,
    user_id: UUID,
    blueprint: Blueprint,
    ip_address: str | None = None,
) -> None:
    """Delete an already-authorized user blueprint; parts cascade at the DB."""
    bp_id = blueprint.id
    bp_name = blueprint.name
    await db.delete(blueprint)
    await audit_service.log_event(
        db,
        action="blueprint.delete",
        resource_type="blueprint",
        user_id=str(user_id),
        resource_id=str(bp_id),
        details={"name": bp_name},
        ip_address=ip_address,
    )
    await db.commit()
