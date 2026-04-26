"""
Unit tests for _build_branded_docx — the /export endpoint's DOCX builder.

These tests are pure-function tests: _build_branded_docx is sync, takes
no DB/S3 dependencies, and returns raw DOCX bytes. We re-parse the output
with python-docx and assert the resulting paragraphs have the expected
Word style names.

This is the regression guard for the M13.3 heading-level round-trip. Any
change to _build_branded_docx that breaks heading style emission gets
caught here. The test localizes the bug:
  - H1/H2/H3 assertions PASS → bug is upstream (Flutter save path,
    Pydantic schema, or DB persistence).
  - H2/H3 assertions FAIL → bug is in _build_branded_docx or its
    python-docx interaction.
"""

from __future__ import annotations

import io

import pytest
from docx import Document as DocxDocument

from psitta.api.v1.documents import _build_branded_docx


# ── Helpers ────────────────────────────────────────────────────────────

def _build_simple_chunks(blocks: list[dict]) -> list[dict]:
    """Build a single-chunk export payload with no chunk title.

    `title` is omitted (defaults to empty) so _build_branded_docx skips
    the chunk-level Heading 2 wrapper that would otherwise prepend a
    "Section 1" heading above the formatted content. This keeps the
    output focused on the formatted_content blocks under test.
    """
    return [{
        "text_content": "ignored when formatted_content is present",
        "formatted_content": blocks,
    }]


def _heading_block(level, text: str) -> dict:
    return {
        "type": "heading",
        "level": level,
        "runs": [{"text": text}],
    }


def _build_and_parse(blocks: list[dict]) -> DocxDocument:
    """Call _build_branded_docx with cover/footer disabled and re-parse
    the resulting bytes with python-docx so we can assert on paragraph
    styles."""
    raw = _build_branded_docx(
        title="Test Doc",
        chunks=_build_simple_chunks(blocks),
        project_name=None,
        include_cover=False,
        include_footer=False,
    )
    return DocxDocument(io.BytesIO(raw))


# ── Test 1: H1/H2/H3 each get the correct Word style ──────────────────

class TestHeadingLevelStyleNames:
    """The /export builder must emit paragraphs whose .style.name is
    the corresponding 'Heading N' style for each level."""

    def test_h1_h2_h3_each_get_correct_style_name(self):
        out = _build_and_parse([
            _heading_block(1, "Heading One"),
            _heading_block(2, "Heading Two"),
            _heading_block(3, "Heading Three"),
        ])
        style_by_text = {
            p.text: (p.style.name if p.style is not None else None)
            for p in out.paragraphs
            if p.text in ("Heading One", "Heading Two", "Heading Three")
        }
        assert style_by_text.get("Heading One") == "Heading 1"
        assert style_by_text.get("Heading Two") == "Heading 2"
        assert style_by_text.get("Heading Three") == "Heading 3"


# ── Test 2: Full clamp range 1..6 ─────────────────────────────────────

class TestHeadingLevelFullRange:
    """Every level the export builder accepts (1..6) must emit the
    corresponding Word heading style."""

    @pytest.mark.parametrize("level", [1, 2, 3, 4, 5, 6])
    def test_each_level_emits_corresponding_heading_style(self, level):
        text = f"Level {level} heading"
        out = _build_and_parse([_heading_block(level, text)])
        para = next((p for p in out.paragraphs if p.text == text), None)
        assert para is not None, f"Heading paragraph not found for level={level}"
        assert para.style is not None
        assert para.style.name == f"Heading {level}"


# ── Test 3: String level coerced via int() ────────────────────────────

class TestHeadingLevelStringCoercion:
    """If a serialization path sends level as the string "2" instead of
    int 2, the export builder's `int(level)` cast must coerce it. This
    guards against a JSON-decode shape drift between front-end and
    back-end."""

    def test_string_level_2_still_renders_as_heading_2(self):
        out = _build_and_parse([{
            "type": "heading",
            "level": "2",
            "runs": [{"text": "Stringy Heading"}],
        }])
        para = next((p for p in out.paragraphs if p.text == "Stringy Heading"), None)
        assert para is not None
        assert para.style.name == "Heading 2"


# ── Test 4: Missing or null level falls back to default ───────────────

class TestHeadingLevelDefault:
    """When level is missing or explicitly null, the fallback must be
    Heading 2 (the export builder's documented default at the
    `block.get("level", 2)` + `try/except → level_int = 2` branch)."""

    def test_missing_level_defaults_to_heading_2(self):
        # block.get("level", 2) returns 2 when the key is absent.
        out = _build_and_parse([{
            "type": "heading",
            "runs": [{"text": "No-level Heading"}],
        }])
        para = next((p for p in out.paragraphs if p.text == "No-level Heading"), None)
        assert para is not None
        assert para.style.name == "Heading 2"

    def test_null_level_defaults_to_heading_2(self):
        # block.get("level", 2) returns None (NOT the default) when the
        # key is explicitly None. int(None) raises TypeError → caught →
        # level_int = 2. Net effect: same as missing.
        out = _build_and_parse([{
            "type": "heading",
            "level": None,
            "runs": [{"text": "Null-level Heading"}],
        }])
        para = next((p for p in out.paragraphs if p.text == "Null-level Heading"), None)
        assert para is not None
        assert para.style.name == "Heading 2"
