"""
Unit tests for _summarize_formatted_content — the privacy-respecting
structural summarizer used by update_chunk_text's diagnostic logger.

These tests are pure-function, no fixtures, no DB. The CRITICAL invariant
asserted by `test_summary_never_leaks_run_text`: the summarizer must
NEVER include any text from runs in its output. Run text can contain
sensitive content (API keys typed by users, document body text); the
ops log must surface only structural metadata.

Co-evolves with documents.py — when run-level attributes are added or
removed (M13.4 color/alignment/etc.), this test enforces that the
summary remains text-free.
"""

from __future__ import annotations

import json

import pytest

from psitta.api.v1.documents import _summarize_formatted_content


# ── Single-block shape tests ───────────────────────────────────────────

class TestHeadingSummary:
    """Heading blocks surface type, level, level_runtime_type, runs_count,
    plus the M13.4 stable-shape fields (alignment + per-block has_color /
    has_strike / has_font_family flags) on every block."""

    def test_heading_block_emits_type_level_runs_count(self):
        out = _summarize_formatted_content([
            {"type": "heading", "level": 2, "runs": [{"text": "Hello"}]},
        ])
        assert out["total_blocks"] == 1
        assert out["blocks"] == [
            {
                "type": "heading",
                "runs_count": 1,
                "alignment": None,
                "has_color": False,
                "has_strike": False,
                "has_font_family": False,
                "level": 2,
                "level_runtime_type": "int",
            },
        ]

    def test_heading_with_string_level_records_runtime_type(self):
        # Diagnostic gold: if Flutter ever sends level as "2" instead of 2,
        # CloudWatch shows level_runtime_type='str' so we localize fast.
        out = _summarize_formatted_content([
            {"type": "heading", "level": "2", "runs": [{"text": "x"}]},
        ])
        assert out["blocks"][0]["level_runtime_type"] == "str"
        # level itself is None when not int (per the helper's contract)
        assert out["blocks"][0]["level"] is None

    def test_heading_with_null_level_records_nonetype(self):
        out = _summarize_formatted_content([
            {"type": "heading", "level": None, "runs": [{"text": "x"}]},
        ])
        assert out["blocks"][0]["level"] is None
        assert out["blocks"][0]["level_runtime_type"] == "NoneType"


class TestListItemSummary:
    """list_item blocks surface type, list_type, runs_count, plus the
    M13.4 stable-shape fields (alignment + run-attr flags)."""

    def test_bullet_list_item(self):
        out = _summarize_formatted_content([
            {"type": "list_item", "list_type": "bullet", "runs": [{"text": "x"}]},
        ])
        assert out["blocks"] == [
            {
                "type": "list_item",
                "runs_count": 1,
                "alignment": None,
                "has_color": False,
                "has_strike": False,
                "has_font_family": False,
                "list_type": "bullet",
            },
        ]

    def test_numbered_list_item(self):
        out = _summarize_formatted_content([
            {"type": "list_item", "list_type": "numbered", "runs": [{"text": "x"}]},
        ])
        assert out["blocks"] == [
            {
                "type": "list_item",
                "runs_count": 1,
                "alignment": None,
                "has_color": False,
                "has_strike": False,
                "has_font_family": False,
                "list_type": "numbered",
            },
        ]

    def test_list_item_missing_list_type_records_none(self):
        out = _summarize_formatted_content([
            {"type": "list_item", "runs": [{"text": "x"}]},
        ])
        assert out["blocks"][0]["list_type"] is None


class TestParagraphSummary:
    """Paragraph blocks surface type and runs_count, plus the M13.4
    stable-shape fields (alignment + run-attr flags)."""

    def test_paragraph_block(self):
        out = _summarize_formatted_content([
            {"type": "paragraph", "runs": [
                {"text": "a"}, {"text": "b"}, {"text": "c"},
            ]},
        ])
        assert out["blocks"] == [
            {
                "type": "paragraph",
                "runs_count": 3,
                "alignment": None,
                "has_color": False,
                "has_strike": False,
                "has_font_family": False,
            },
        ]

    def test_paragraph_default_when_type_missing(self):
        # block.get("type", "paragraph") falls through to paragraph.
        out = _summarize_formatted_content([
            {"runs": [{"text": "x"}]},
        ])
        assert out["blocks"][0]["type"] == "paragraph"


# ── None / empty / malformed input ────────────────────────────────────

class TestDefensiveInputHandling:
    """The helper must never raise on bad input — it returns the safe
    empty summary when the structure is unparseable. The outer caller's
    try/except is belt; this is suspenders."""

    def test_none_input(self):
        assert _summarize_formatted_content(None) == {"total_blocks": 0, "blocks": []}

    def test_empty_list_input(self):
        assert _summarize_formatted_content([]) == {"total_blocks": 0, "blocks": []}

    def test_non_list_input_returns_safe_empty(self):
        assert _summarize_formatted_content("not a list") == {  # type: ignore[arg-type]
            "total_blocks": 0,
            "blocks": [],
        }
        assert _summarize_formatted_content({"oops": "dict"}) == {  # type: ignore[arg-type]
            "total_blocks": 0,
            "blocks": [],
        }

    def test_non_dict_block_skipped(self):
        # Mixed list with a malformed (non-dict) entry — the helper
        # silently skips it but counts it in total_blocks (faithful to
        # what the client sent).
        out = _summarize_formatted_content([
            {"type": "paragraph", "runs": [{"text": "x"}]},
            "not-a-dict",  # type: ignore[list-item]
            {"type": "paragraph", "runs": [{"text": "y"}]},
        ])
        assert out["total_blocks"] == 3
        # Only the two valid dicts produce summary entries.
        assert len(out["blocks"]) == 2

    def test_non_list_runs_yields_zero_count(self):
        out = _summarize_formatted_content([
            {"type": "paragraph", "runs": "oops not a list"},
        ])
        assert out["blocks"][0]["runs_count"] == 0


# ── Truncation at 50 ──────────────────────────────────────────────────

class TestTruncation:
    """Large documents must not bloat the log — the blocks list is
    capped at 50 entries with a 'truncated_at' marker."""

    def test_one_hundred_blocks_truncates_at_fifty(self):
        blocks = [
            {"type": "paragraph", "runs": [{"text": f"para {i}"}]}
            for i in range(100)
        ]
        out = _summarize_formatted_content(blocks)
        assert out["total_blocks"] == 100
        assert len(out["blocks"]) == 50
        assert out["truncated_at"] == 50

    def test_exactly_fifty_blocks_no_truncation_marker(self):
        # Boundary: 50 fits, no marker; 51+ marker.
        blocks = [
            {"type": "paragraph", "runs": [{"text": f"p{i}"}]}
            for i in range(50)
        ]
        out = _summarize_formatted_content(blocks)
        assert out["total_blocks"] == 50
        assert len(out["blocks"]) == 50
        assert "truncated_at" not in out

    def test_fifty_one_blocks_marker_present(self):
        blocks = [
            {"type": "paragraph", "runs": [{"text": f"p{i}"}]}
            for i in range(51)
        ]
        out = _summarize_formatted_content(blocks)
        assert out["total_blocks"] == 51
        assert len(out["blocks"]) == 50
        assert out["truncated_at"] == 50


# ── CRITICAL: privacy invariant ────────────────────────────────────────

class TestPrivacyInvariant:
    """The summarizer must NEVER include run text content in its output.
    Run text can contain user document body, pasted secrets, or other
    sensitive material that must not reach CloudWatch.

    This test fails the build if any future change to the helper starts
    leaking text. It uses obviously-sensitive test strings so a leak is
    glaring in error output."""

    SENSITIVE_STRINGS = [
        "API_KEY=secret-do-not-log",
        "ssh-rsa AAAAB3NzaC1yc2EAAAA",
        "BEGIN PRIVATE KEY",
        "user-typed-confidential-doc-body",
        "credit-card 4111111111111111",
    ]

    def test_summary_never_leaks_run_text(self):
        # Build a document whose every block, run, and field could
        # leak text if the helper were buggy. Then JSON-encode the
        # entire summary and assert no sensitive substring survives.
        blocks = [
            {
                "type": "heading",
                "level": 1,
                "runs": [
                    {"text": self.SENSITIVE_STRINGS[0], "bold": True},
                    {"text": self.SENSITIVE_STRINGS[1]},
                ],
            },
            {
                "type": "list_item",
                "list_type": "numbered",
                "runs": [{"text": self.SENSITIVE_STRINGS[2]}],
            },
            {
                "type": "paragraph",
                "runs": [
                    {"text": self.SENSITIVE_STRINGS[3], "italic": True},
                    {"text": self.SENSITIVE_STRINGS[4], "underline": True},
                ],
            },
        ]
        out = _summarize_formatted_content(blocks)
        encoded = json.dumps(out)
        for s in self.SENSITIVE_STRINGS:
            assert s not in encoded, (
                f"PRIVACY LEAK: summarizer output contains run text {s!r}. "
                f"Full summary: {encoded}"
            )

    def test_summary_never_leaks_extra_run_attributes(self):
        # Even attributes that are not text — e.g. font_size set to a
        # PII-shaped value — should not appear. The helper only emits
        # structural counts/types, not run-level details.
        blocks = [
            {
                "type": "paragraph",
                "runs": [
                    {"text": "x", "font_size": 4242, "color": "#leak-me"},
                ],
            },
        ]
        encoded = json.dumps(_summarize_formatted_content(blocks))
        assert "4242" not in encoded
        assert "leak-me" not in encoded

    @pytest.mark.parametrize("sensitive", SENSITIVE_STRINGS)
    def test_each_sensitive_string_blocked_individually(self, sensitive):
        # Per-string parametrized variant for sharper failure messages.
        blocks = [
            {"type": "paragraph", "runs": [{"text": sensitive}]},
        ]
        encoded = json.dumps(_summarize_formatted_content(blocks))
        assert sensitive not in encoded
