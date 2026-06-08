"""Unit tests for the pure leaf-aware coherence rollup (Phase 2G).

Exercises ``blueprint_coherence`` rollup helpers directly on hand-built flat
"CTE rows" — no DB. Focus: the leaf-aware readiness rules (a container inherits
from its children, regardless of its own direct content) and leaf-based progress
(reducing to parts-with-content for a flat blueprint).
"""

from __future__ import annotations

from uuid import uuid4

from psitta.schemas.api import ReadinessEnum
from psitta.services.blueprint_coherence import (
    _build_overview_tree,
    _compute_progress,
)

_BID = uuid4()


def _row(part_id, parent_id, document_count, sort_order):
    """One flat CTE-shaped row for a single blueprint."""
    return {
        "id": part_id,
        "blueprint_id": _BID,
        "parent_part_id": parent_id,
        "name": f"P{sort_order}",
        "description": None,
        "sort_order": sort_order,
        "document_count": document_count,
    }


def _by_name(nodes):
    return {n.name: n for n in nodes}


class TestFlatBlueprint:
    def test_flat_reduces_to_parts_with_content(self):
        a, b, c = uuid4(), uuid4(), uuid4()
        flat = [
            _row(a, None, 1, 1000),
            _row(b, None, 0, 2000),
            _row(c, None, 2, 3000),
        ]
        roots = _build_overview_tree(flat)
        by_name = _by_name(roots)
        # Every flat part is a leaf: ready iff it has content, else empty.
        assert by_name["P1000"].readiness == ReadinessEnum.READY
        assert by_name["P2000"].readiness == ReadinessEnum.EMPTY
        assert by_name["P3000"].readiness == ReadinessEnum.READY
        assert by_name["P1000"].has_content is True
        assert by_name["P2000"].has_content is False

        progress = _compute_progress(flat)
        assert progress.total_leaves == 3
        assert progress.leaves_with_content == 2
        assert progress.ratio == 2 / 3


class TestContainerRollup:
    def test_container_all_children_filled_is_ready(self):
        root, x, y = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 0, 1000),  # container, no direct content
            _row(x, root, 1, 1000),
            _row(y, root, 3, 2000),
        ]
        roots = _build_overview_tree(flat)
        assert len(roots) == 1
        node = roots[0]
        # Container inherits READY from its children despite zero direct content.
        assert node.readiness == ReadinessEnum.READY
        assert node.has_content is False
        assert {c.readiness for c in node.children} == {ReadinessEnum.READY}

        progress = _compute_progress(flat)  # leaves are x, y
        assert (progress.total_leaves, progress.leaves_with_content) == (2, 2)
        assert progress.ratio == 1.0

    def test_container_one_empty_child_is_in_progress(self):
        root, x, y = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 0, 1000),
            _row(x, root, 1, 1000),  # filled
            _row(y, root, 0, 2000),  # empty
        ]
        node = _build_overview_tree(flat)[0]
        assert node.readiness == ReadinessEnum.IN_PROGRESS
        progress = _compute_progress(flat)
        assert (progress.total_leaves, progress.leaves_with_content) == (2, 1)
        assert progress.ratio == 0.5

    def test_all_empty_subtree_is_empty(self):
        root, x, y = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 0, 1000),
            _row(x, root, 0, 1000),
            _row(y, root, 0, 2000),
        ]
        node = _build_overview_tree(flat)[0]
        assert node.readiness == ReadinessEnum.EMPTY
        assert all(c.readiness == ReadinessEnum.EMPTY for c in node.children)
        progress = _compute_progress(flat)
        assert (progress.total_leaves, progress.leaves_with_content) == (2, 0)
        assert progress.ratio == 0.0

    def test_container_with_direct_content_but_empty_children_is_in_progress(self):
        # A container's OWN content keeps it out of EMPTY but cannot make it READY
        # (its children aren't ready), so it is IN_PROGRESS. It is not a leaf, so
        # its direct content does not count toward progress.
        root, x, y = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 5, 1000),  # direct content on the container
            _row(x, root, 0, 1000),
            _row(y, root, 0, 2000),
        ]
        node = _build_overview_tree(flat)[0]
        assert node.has_content is True
        assert node.readiness == ReadinessEnum.IN_PROGRESS
        progress = _compute_progress(flat)
        assert (progress.total_leaves, progress.leaves_with_content) == (2, 0)
        assert progress.ratio == 0.0


class TestDeepNesting:
    def test_three_levels_roll_up_ready(self):
        root, mid, leaf = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 0, 1000),
            _row(mid, root, 0, 1000),
            _row(leaf, mid, 1, 1000),  # only the deepest leaf has content
        ]
        node = _build_overview_tree(flat)[0]
        assert node.readiness == ReadinessEnum.READY
        assert node.children[0].readiness == ReadinessEnum.READY  # mid
        assert node.children[0].children[0].readiness == ReadinessEnum.READY
        progress = _compute_progress(flat)
        assert (progress.total_leaves, progress.leaves_with_content) == (1, 1)
        assert progress.ratio == 1.0

    def test_three_levels_empty_leaf_rolls_up_empty(self):
        root, mid, leaf = uuid4(), uuid4(), uuid4()
        flat = [
            _row(root, None, 0, 1000),
            _row(mid, root, 0, 1000),
            _row(leaf, mid, 0, 1000),
        ]
        node = _build_overview_tree(flat)[0]
        assert node.readiness == ReadinessEnum.EMPTY
        progress = _compute_progress(flat)
        assert (progress.total_leaves, progress.leaves_with_content) == (1, 0)
        assert progress.ratio == 0.0


class TestEmptyBlueprint:
    def test_zero_parts_gives_empty_tree_and_null_ratio(self):
        assert _build_overview_tree([]) == []
        progress = _compute_progress([])
        assert progress.total_leaves == 0
        assert progress.leaves_with_content == 0
        assert progress.ratio is None
