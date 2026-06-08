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
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.models.blueprint import Blueprint, BlueprintPart
from psitta.schemas.api import (
    BlueprintCreate,
    BlueprintStatusEnum,
    BlueprintUpdate,
    PartCreate,
    PartNode,
    PartUpdate,
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


# ── Parts (2D) ─────────────────────────────────────────────────────────────
# Gapped-numeric ordering: siblings (same blueprint + same parent_part_id) are
# ordered by ``sort_order``. New positions are midpoints (or last + _GAP). Because
# ``sort_order`` is NUMERIC, a single insert/move is one row write — UNLESS the
# usable gap collapses below _MIN_GAP, when the one sibling group is renormalized
# to evenly spaced multiples of _GAP and the midpoint is recomputed.

_GAP = Decimal(1000)
_MIN_GAP = Decimal("0.0001")


class PartValidationError(ValueError):
    """Service-level 400 — cross-blueprint parent, a cycle, or a bad after_part_id.

    Raised before any write; the route maps it to HTTP 400. Distinct from the
    404s (blueprint/part not owned or absent) which the route raises directly.
    """


class _GapExhaustedError(Exception):
    """Internal: the usable midpoint gap collapsed; renormalize and retry."""


def _descendant_ids(parts: list[BlueprintPart], root_id: UUID) -> set[UUID]:
    """All ids strictly below ``root_id`` in ``parts`` (its subtree, exclusive).

    Pure, iterative (no recursion-depth risk). Used for cycle prevention: a part
    may not be moved under itself or any of these.
    """
    children: dict[UUID | None, list[UUID]] = {}
    for p in parts:
        children.setdefault(p.parent_part_id, []).append(p.id)
    out: set[UUID] = set()
    stack = list(children.get(root_id, []))
    while stack:
        cur = stack.pop()
        if cur in out:
            continue
        out.add(cur)
        stack.extend(children.get(cur, []))
    return out


def _compute_sort_order(
    siblings: list[BlueprintPart], after_id: UUID | None
) -> Decimal:
    """Midpoint ``sort_order`` for a new/moved part among ``siblings``.

    ``siblings`` must be ascending by ``sort_order`` and must NOT include the
    moving part. ``after_id`` must already be validated as one of ``siblings``
    (or None ⇒ become the first child). Raises ``_GapExhaustedError`` when the gap
    collapses below ``_MIN_GAP`` so the caller can renormalize and retry.
    """
    if not siblings:
        return _GAP
    if after_id is None:
        first = siblings[0].sort_order
        candidate = first / 2
        if first <= _MIN_GAP or (first - candidate) < _MIN_GAP:
            raise _GapExhaustedError
        return candidate
    idx = next(i for i, s in enumerate(siblings) if s.id == after_id)
    cur = siblings[idx].sort_order
    if idx == len(siblings) - 1:
        return cur + _GAP
    nxt = siblings[idx + 1].sort_order
    if (nxt - cur) < _MIN_GAP:
        raise _GapExhaustedError
    candidate = (cur + nxt) / 2
    if candidate <= cur or candidate >= nxt:
        raise _GapExhaustedError
    return candidate


async def _assign_position(
    db: AsyncSession,
    parts: list[BlueprintPart],
    parent_id: UUID | None,
    after_id: UUID | None,
) -> Decimal:
    """Resolve the ``sort_order`` for placing a part after ``after_id``.

    ``parts`` is the full part set EXCLUDING the moving part. ``after_id``, if
    given, must be an existing sibling under ``parent_id`` (else 400). On gap
    exhaustion the sibling group is renormalized in place (one flush) and the
    midpoint is recomputed — guaranteed to succeed on the spaced-out group.
    """
    siblings = sorted(
        (p for p in parts if p.parent_part_id == parent_id),
        key=lambda p: p.sort_order,
    )
    if after_id is not None and not any(s.id == after_id for s in siblings):
        raise PartValidationError(
            "after_part_id is not a sibling under the target parent"
        )
    try:
        return _compute_sort_order(siblings, after_id)
    except _GapExhaustedError:
        for i, s in enumerate(siblings):
            s.sort_order = _GAP * (i + 1)
        await db.flush()
        return _compute_sort_order(siblings, after_id)


async def _fetch_parts(
    db: AsyncSession, blueprint_id: UUID
) -> list[BlueprintPart]:
    """All parts of a blueprint, flat and ascending by ``sort_order``."""
    stmt = (
        select(BlueprintPart)
        .where(BlueprintPart.blueprint_id == blueprint_id)
        .order_by(BlueprintPart.sort_order)
    )
    return list((await db.execute(stmt)).scalars().all())


async def load_part_by_id(
    db: AsyncSession, blueprint_id: UUID, part_id: UUID
) -> BlueprintPart | None:
    """Fetch one part scoped to ``blueprint_id`` (cross-blueprint id ⇒ None)."""
    stmt = select(BlueprintPart).where(
        BlueprintPart.id == part_id,
        BlueprintPart.blueprint_id == blueprint_id,
    )
    return (await db.execute(stmt)).scalar_one_or_none()


async def create_part(
    db: AsyncSession,
    user_id: UUID,
    blueprint: Blueprint,
    data: PartCreate,
    ip_address: str | None = None,
) -> BlueprintPart:
    """Add a part to an already-authorized user blueprint, audit, commit.

    ``parent_part_id`` (if any) must belong to this blueprint; the placement is
    a gapped-numeric midpoint under the resolved parent. Same-blueprint parent
    is validated here and backstopped by the composite FK.
    """
    parts = await _fetch_parts(db, blueprint.id)
    parent_id = data.parent_part_id
    if parent_id is not None and not any(p.id == parent_id for p in parts):
        raise PartValidationError("parent_part_id is not a part of this blueprint")

    sort_order = await _assign_position(db, parts, parent_id, data.after_part_id)
    part = BlueprintPart(
        blueprint_id=blueprint.id,
        parent_part_id=parent_id,
        name=data.name,
        description=data.description,
        sort_order=sort_order,
    )
    db.add(part)
    await db.flush()  # populate server-generated id
    await audit_service.log_event(
        db,
        action="blueprint_part.create",
        resource_type="blueprint_part",
        user_id=str(user_id),
        resource_id=str(part.id),
        details={
            "blueprint_id": str(blueprint.id),
            "parent_part_id": str(parent_id) if parent_id else None,
            "name": part.name,
        },
        ip_address=ip_address,
    )
    await db.commit()
    return part


async def update_part(  # noqa: PLR0913 -- (db, user_id, blueprint, part, data) are all distinct collaborators plus the optional ip_address; a params object would obscure the call site
    db: AsyncSession,
    user_id: UUID,
    blueprint: Blueprint,
    part: BlueprintPart,
    data: PartUpdate,
    ip_address: str | None = None,
) -> BlueprintPart:
    """Field-edit and/or reorder/nest an already-authorized part.

    Presence (``model_fields_set``) drives intent. Reparenting is cycle-checked
    (no moving a part under its own descendant) and same-blueprint-checked. If
    the parent changes without an ``after_part_id``, the part is appended to the
    end of the new parent's children.
    """
    fields_set = data.model_fields_set
    if "name" in fields_set and data.name is not None:
        part.name = data.name
    if "description" in fields_set:
        part.description = data.description

    reparenting = "parent_part_id" in fields_set
    repositioning = "after_part_id" in fields_set
    if reparenting or repositioning:
        parts = await _fetch_parts(db, blueprint.id)
        new_parent_id = data.parent_part_id if reparenting else part.parent_part_id
        if new_parent_id is not None and not any(
            p.id == new_parent_id for p in parts
        ):
            raise PartValidationError(
                "parent_part_id is not a part of this blueprint"
            )
        if new_parent_id is not None:
            if new_parent_id == part.id:
                raise PartValidationError("a part cannot be its own parent")
            if new_parent_id in _descendant_ids(parts, part.id):
                raise PartValidationError(
                    "cannot move a part under its own descendant"
                )

        others = [p for p in parts if p.id != part.id]
        after_id = data.after_part_id if repositioning else None
        if reparenting and not repositioning:
            new_siblings = sorted(
                (p for p in others if p.parent_part_id == new_parent_id),
                key=lambda p: p.sort_order,
            )
            after_id = new_siblings[-1].id if new_siblings else None

        new_order = await _assign_position(db, others, new_parent_id, after_id)
        part.parent_part_id = new_parent_id
        part.sort_order = new_order

    part.updated_at = datetime.now(UTC)
    await audit_service.log_event(
        db,
        action="blueprint_part.update",
        resource_type="blueprint_part",
        user_id=str(user_id),
        resource_id=str(part.id),
        details={
            "blueprint_id": str(blueprint.id),
            "fields": sorted(fields_set),
        },
        ip_address=ip_address,
    )
    await db.commit()
    return part


async def delete_part(
    db: AsyncSession,
    user_id: UUID,
    blueprint: Blueprint,
    part: BlueprintPart,
    ip_address: str | None = None,
) -> None:
    """Delete an already-authorized part; its subtree cascades at the DB.

    The composite ``(parent_part_id, blueprint_id)`` FK is ``ON DELETE
    CASCADE``, so deleting this row removes its descendant parts recursively,
    and ``part_documents.part_id`` (also CASCADE) removes their placements — no
    app-side recursion. ``subtree_size`` is recorded for the audit trail only.
    """
    parts = await _fetch_parts(db, blueprint.id)
    subtree_size = len(_descendant_ids(parts, part.id))
    pid = part.id
    pname = part.name
    await db.delete(part)
    await audit_service.log_event(
        db,
        action="blueprint_part.delete",
        resource_type="blueprint_part",
        user_id=str(user_id),
        resource_id=str(pid),
        details={
            "blueprint_id": str(blueprint.id),
            "name": pname,
            "subtree_size": subtree_size,
        },
        ip_address=ip_address,
    )
    await db.commit()
