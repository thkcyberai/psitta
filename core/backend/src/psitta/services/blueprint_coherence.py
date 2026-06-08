"""Psitta — Blueprint Coherence Engine (read-only, Phase 2G).

A single read-only entrypoint, ``derive_overview``, that computes a project's
derived "blueprint overview": for each adopted blueprint, its parts tree
annotated with content counts and leaf-aware readiness, plus a leaf-based
progress figure (the project's headline progress is its primary blueprint's).

Everything here is derived ON READ and NEVER stored. Soft-deleted documents are
excluded from the counts (their ``part_documents`` placement rows survive); the
status filter lives in the JOIN ON clause so a part with zero non-deleted
documents still appears with ``document_count = 0``.

Derived semantics (Decision 2, leaf-aware):
  - ``document_count`` — non-deleted documents placed DIRECTLY in a part.
  - ``has_content``    — ``document_count > 0``.
  - ``readiness`` over a part:
      * leaf:      ``ready`` iff it has content, else ``empty``.
      * container: ``ready`` iff every child is ready (regardless of the
                   container's own direct content); ``empty`` iff no part in the
                   subtree has content; ``in_progress`` otherwise.
  - ``progress`` — ``leaves_with_content / total_leaves`` (leaf parts are the
    content slots); ``ratio`` is ``None`` when there are no leaves. For a flat
    blueprint this reduces to parts-with-content / total-parts.

No writes, no audit (reads). Project ownership is enforced by the route before
this is called; the recursive CTE is scoped to the project's adopted blueprints.
"""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.schemas.api import (
    BlueprintOverview,
    PartOverviewNode,
    ProgressInfo,
    ProjectBlueprintOverview,
    ReadinessEnum,
)
from psitta.services import blueprint_service

# Recursive CTE: walk each adopted blueprint's part tree from its roots and
# LEFT JOIN placements to non-deleted documents. The status filter is in the
# JOIN ON (not WHERE) so parts with zero live documents still return a row with
# ``document_count = 0``; COUNT(d.id) ignores the no-match / soft-deleted NULLs.
_OVERVIEW_CTE = text(
    """
    WITH RECURSIVE tree AS (
        SELECT id, blueprint_id, parent_part_id, name, description, sort_order,
               0 AS depth
        FROM blueprint_parts
        WHERE blueprint_id = ANY(:bids) AND parent_part_id IS NULL
        UNION ALL
        SELECT c.id, c.blueprint_id, c.parent_part_id, c.name, c.description,
               c.sort_order, t.depth + 1
        FROM blueprint_parts c
        JOIN tree t ON c.parent_part_id = t.id
    )
    SELECT t.id, t.blueprint_id, t.parent_part_id, t.name, t.description,
           t.sort_order, COUNT(d.id) AS document_count
    FROM tree t
    LEFT JOIN part_documents pd ON pd.part_id = t.id
    LEFT JOIN documents d ON d.id = pd.document_id AND d.status <> 'deleted'
    GROUP BY t.id, t.blueprint_id, t.parent_part_id, t.name, t.description,
             t.sort_order
    ORDER BY t.sort_order
    """
)


def _build_overview_node(
    raw: dict, children_by_parent: dict[UUID | None, list[dict]]
) -> PartOverviewNode:
    """Build one annotated node and its subtree (pure, post-order recursion).

    Children are ordered by ``sort_order``. Readiness is computed bottom-up from
    the already-built children, so a container inherits readiness from its
    children regardless of its own direct content.
    """
    kids_raw = sorted(
        children_by_parent.get(raw["id"], []), key=lambda r: r["sort_order"]
    )
    children = [_build_overview_node(k, children_by_parent) for k in kids_raw]
    has_content = raw["document_count"] > 0
    return PartOverviewNode(
        id=raw["id"],
        name=raw["name"],
        description=raw["description"],
        sort_order=float(raw["sort_order"]),
        document_count=raw["document_count"],
        has_content=has_content,
        readiness=_readiness(has_content, children),
        children=children,
    )


def _readiness(
    has_content: bool, children: list[PartOverviewNode]
) -> ReadinessEnum:
    """Leaf-aware readiness for a part given its (already-annotated) children.

    Leaf (no children): ``ready`` iff it has content, else ``empty``.
    Container: ``ready`` iff every child is ready; else ``empty`` iff nothing in
    the subtree has content; else ``in_progress``. A child's readiness being
    non-``empty`` is exactly "that child's subtree has content".
    """
    if not children:
        return ReadinessEnum.READY if has_content else ReadinessEnum.EMPTY
    if all(c.readiness == ReadinessEnum.READY for c in children):
        return ReadinessEnum.READY
    subtree_has_content = has_content or any(
        c.readiness != ReadinessEnum.EMPTY for c in children
    )
    return (
        ReadinessEnum.IN_PROGRESS if subtree_has_content else ReadinessEnum.EMPTY
    )


def _build_overview_tree(flat: list[dict]) -> list[PartOverviewNode]:
    """Assemble flat CTE rows (one blueprint) into annotated root nodes.

    Pure; mirrors ``blueprint_service._build_parts_tree``'s grouping but adds the
    derived counts/readiness. A row whose ``parent_part_id`` is not present in the
    set (cannot happen given the composite same-blueprint FK) is treated as a root.
    """
    ids = {r["id"] for r in flat}
    children_by_parent: dict[UUID | None, list[dict]] = {}
    for r in flat:
        parent = r["parent_part_id"]
        key = parent if parent in ids else None
        children_by_parent.setdefault(key, []).append(r)
    roots = sorted(
        children_by_parent.get(None, []), key=lambda r: r["sort_order"]
    )
    return [_build_overview_node(r, children_by_parent) for r in roots]


def _compute_progress(flat: list[dict]) -> ProgressInfo:
    """Leaf-based progress over one blueprint's flat parts (pure).

    A leaf is a part that is no other part's parent. ``ratio`` is ``None`` when
    the blueprint has no leaves (a zero-part blueprint, or — impossible here —
    a pure-cycle); otherwise ``leaves_with_content / total_leaves``.
    """
    parent_ids = {r["parent_part_id"] for r in flat if r["parent_part_id"]}
    leaves = [r for r in flat if r["id"] not in parent_ids]
    total_leaves = len(leaves)
    leaves_with_content = sum(1 for r in leaves if r["document_count"] > 0)
    ratio = leaves_with_content / total_leaves if total_leaves else None
    return ProgressInfo(
        leaves_with_content=leaves_with_content,
        total_leaves=total_leaves,
        ratio=ratio,
    )


async def derive_overview(
    db: AsyncSession, project_id: UUID
) -> ProjectBlueprintOverview:
    """Compute the derived coherence overview for a project's adopted blueprints.

    Project ownership is the route's responsibility (404 there). A project with
    no adopted blueprints returns an empty overview (``progress=None``). The
    project's headline ``progress`` is the PRIMARY blueprint's progress, or
    ``None`` when no adoption is primary; each blueprint carries its own.
    """
    adopted = await blueprint_service.list_project_blueprints(db, project_id)
    if not adopted:
        return ProjectBlueprintOverview(progress=None, blueprints=[])

    # Pass UUID objects (not strings): asyncpg binds the list as a Postgres
    # array and Postgres infers ``uuid[]`` from the ``blueprint_id = ANY(...)``
    # comparison — no inline ``::uuid[]`` cast (which SQLAlchemy's text() bind
    # regex would refuse to substitute, the ``::`` immediately following a param).
    blueprint_ids = [a.id for a in adopted]
    rows = await db.execute(_OVERVIEW_CTE, {"bids": blueprint_ids})
    flat_by_blueprint: dict[str, list[dict]] = {}
    for row in rows.mappings():
        flat_by_blueprint.setdefault(str(row["blueprint_id"]), []).append(dict(row))

    overviews: list[BlueprintOverview] = []
    project_progress: ProgressInfo | None = None
    for a in adopted:
        flat = flat_by_blueprint.get(str(a.id), [])
        progress = _compute_progress(flat)
        overviews.append(
            BlueprintOverview(
                **a.model_dump(),
                progress=progress,
                parts=_build_overview_tree(flat),
            )
        )
        if a.is_primary:
            project_progress = progress

    return ProjectBlueprintOverview(
        progress=project_progress, blueprints=overviews
    )
