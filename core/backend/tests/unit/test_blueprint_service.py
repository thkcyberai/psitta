"""Unit tests for the Blueprint read service (no database).

Covers the two pieces of logic that don't need Postgres:

  - ``_build_parts_tree`` — flat, ``sort_order``-ordered rows → nested tree,
    with sibling order preserved and a defensive orphan-parent fallback.
  - ``get_blueprint`` — a query that returns no row (unknown id, or a
    foreign-owned blueprint excluded by the visibility WHERE clause) maps to
    ``None``. The WHERE clause itself is exercised against real data in the
    integration suite.
"""

from __future__ import annotations

from decimal import Decimal
from types import SimpleNamespace
from uuid import uuid4

import pytest

from psitta.services.blueprint_service import (
    _GAP,
    _build_parts_tree,
    _compute_sort_order,
    _descendant_ids,
    _GapExhaustedError,
    _remap_cloned_parts,
    get_blueprint,
)


def _part(name, sort_order, parent_id=None):
    """A BlueprintPart-shaped stand-in (only the attrs the builder reads)."""
    return SimpleNamespace(
        id=uuid4(),
        name=name,
        description=None,
        sort_order=Decimal(str(sort_order)),
        parent_part_id=parent_id,
    )


class TestBuildPartsTree:
    def test_nesting_and_sibling_order(self):
        # Flat input, already ordered by sort_order (as the real query returns).
        root1 = _part("Root 1", 100)
        root2 = _part("Root 2", 200)
        child_a = _part("Child A", 300, parent_id=root2.id)
        child_b = _part("Child B", 400, parent_id=root2.id)
        grandchild = _part("Grandchild", 500, parent_id=child_b.id)
        flat = [root1, root2, child_a, child_b, grandchild]

        tree = _build_parts_tree(flat)

        # Two roots, in sort_order order.
        assert [n.id for n in tree] == [root1.id, root2.id]
        assert tree[0].children == []

        # Root 2's two children, in ascending sort_order.
        kids = tree[1].children
        assert [k.id for k in kids] == [child_a.id, child_b.id]
        assert kids[0].sort_order < kids[1].sort_order
        assert kids[0].sort_order == 300.0

        # Depth > 1 is preserved.
        assert [g.id for g in kids[1].children] == [grandchild.id]

    def test_sort_order_is_float(self):
        tree = _build_parts_tree([_part("Only", 100)])
        assert isinstance(tree[0].sort_order, float)

    def test_orphan_parent_is_treated_as_root(self):
        # parent_part_id points at an id not in the set → defensive root.
        orphan = _part("Orphan", 100, parent_id=uuid4())
        tree = _build_parts_tree([orphan])
        assert [n.id for n in tree] == [orphan.id]

    def test_empty_input(self):
        assert _build_parts_tree([]) == []


class _NoRowResult:
    def scalar_one_or_none(self):
        return None


class _FakeDB:
    """Minimal async session: every execute() yields a no-row result."""

    async def execute(self, _stmt):
        return _NoRowResult()


class TestGetBlueprintVisibility:
    @pytest.mark.asyncio
    async def test_unknown_or_foreign_row_maps_to_none(self):
        result = await get_blueprint(_FakeDB(), uuid4(), uuid4())
        assert result is None


class TestComputeSortOrder:
    """The gapped-numeric midpoint math (pure; siblings ascending, self excluded)."""

    def test_empty_group_gets_gap(self):
        assert _compute_sort_order([], None) == _GAP

    def test_first_child_is_half_of_first(self):
        sibs = [_part("A", 1000), _part("B", 2000)]
        assert _compute_sort_order(sibs, None) == Decimal(500)

    def test_between_two_siblings_is_midpoint(self):
        a = _part("A", 1000)
        b = _part("B", 2000)
        assert _compute_sort_order([a, b], a.id) == Decimal(1500)

    def test_after_last_is_last_plus_gap(self):
        a = _part("A", 1000)
        b = _part("B", 2000)
        assert _compute_sort_order([a, b], b.id) == Decimal(2000) + _GAP

    def test_collapsed_gap_raises_gap_exhausted(self):
        # Two siblings closer than _MIN_GAP ⇒ no usable midpoint between them.
        a = _part("A", "1.00000")
        b = _part("B", "1.00001")
        with pytest.raises(_GapExhaustedError):
            _compute_sort_order([a, b], a.id)

    def test_tiny_first_raises_gap_exhausted(self):
        # First sibling already below _MIN_GAP ⇒ can't halve to a usable first slot.
        only = _part("Only", "0.00001")
        with pytest.raises(_GapExhaustedError):
            _compute_sort_order([only], None)


class TestDescendantIds:
    def test_collects_full_subtree_exclusive_of_root(self):
        root = _part("Root", 100)
        child_a = _part("Child A", 100, parent_id=root.id)
        child_b = _part("Child B", 200, parent_id=root.id)
        grandchild = _part("Grandchild", 100, parent_id=child_b.id)
        other = _part("Other root", 300)
        parts = [root, child_a, child_b, grandchild, other]

        desc = _descendant_ids(parts, root.id)

        assert desc == {child_a.id, child_b.id, grandchild.id}
        assert root.id not in desc
        assert other.id not in desc

    def test_leaf_has_no_descendants(self):
        leaf = _part("Leaf", 100)
        assert _descendant_ids([leaf], leaf.id) == set()


class TestRemapClonedParts:
    def test_deep_copy_remaps_parents_and_preserves_order(self):
        # Synthetic 3-level source tree, ordered by sort_order.
        root = _part("Root", 100)
        child_a = _part("Child A", 100, parent_id=root.id)
        child_b = _part("Child B", 200, parent_id=root.id)
        grandchild = _part("Grandchild", 100, parent_id=child_b.id)
        source = [root, child_a, child_b, grandchild]
        new_blueprint_id = uuid4()

        out = _remap_cloned_parts(source, new_blueprint_id)

        assert len(out) == len(source)
        src_ids = {s.id for s in source}
        src_to_new = {s.id: o.id for s, o in zip(source, out, strict=True)}

        # Every new id is fresh, unique, and belongs to the new blueprint.
        assert len({o.id for o in out}) == len(out)
        for o in out:
            assert o.id not in src_ids
            assert o.blueprint_id == new_blueprint_id

        # Parents remap to the NEW parent id (never a source id), order + names
        # preserved, roots stay None — i.e. the tree shape is unchanged.
        for s, o in zip(source, out, strict=True):
            assert o.sort_order == s.sort_order
            assert o.name == s.name
            if s.parent_part_id is None:
                assert o.parent_part_id is None
            else:
                assert o.parent_part_id == src_to_new[s.parent_part_id]
                assert o.parent_part_id not in src_ids
