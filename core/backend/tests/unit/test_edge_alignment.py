"""Tests for psitta.providers.edge_alignment.expand.

The contract is the ElevenLabs sidecar shape consumed by the Flutter
_charIndexAtMs path: parallel arrays of single-char strings, start
seconds, and end seconds — same length as the input text, monotonic
starts, starts <= ends.
"""

from __future__ import annotations

import pytest

from psitta.providers.edge_alignment import expand


def _block(out: dict, key: str = "normalized_alignment") -> dict:
    return out[key]


def _assert_invariants(out: dict, text: str) -> None:
    for key in ("alignment", "normalized_alignment"):
        block = _block(out, key)
        assert set(block.keys()) == {
            "characters",
            "character_start_times_seconds",
            "character_end_times_seconds",
        }
        chars = block["characters"]
        starts = block["character_start_times_seconds"]
        ends = block["character_end_times_seconds"]
        assert len(chars) == len(text), f"{key}: len(chars)={len(chars)} != len(text)={len(text)}"
        assert len(starts) == len(text)
        assert len(ends) == len(text)
        assert "".join(chars) == text
        assert all(isinstance(c, str) and len(c) == 1 for c in chars)
        assert all(isinstance(t, (int, float)) for t in starts)
        assert all(isinstance(t, (int, float)) for t in ends)
        for i in range(len(starts) - 1):
            assert starts[i] <= starts[i + 1], f"{key}: starts not monotonic at {i}"
        for i in range(len(starts)):
            assert starts[i] <= ends[i], f"{key}: start > end at {i}"


def test_basic_two_words_with_space():
    text = "hello world"
    boundaries = [
        {"text": "hello", "offset_ms": 0, "duration_ms": 500},
        {"text": "world", "offset_ms": 600, "duration_ms": 500},
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)

    block = _block(out)
    # "h" of "hello" at chunk start
    assert block["character_start_times_seconds"][0] == 0.0
    # last char of "world" ends near 1.1
    assert block["character_end_times_seconds"][-1] == pytest.approx(1.1, abs=0.01)
    # space at index 5 should be in the gap (0.5 → 0.6)
    assert 0.5 <= block["character_start_times_seconds"][5] <= 0.6


def test_empty_text():
    out = expand("", [{"text": "hello", "offset_ms": 0, "duration_ms": 500}])
    assert out["alignment"]["characters"] == []
    assert out["normalized_alignment"]["characters"] == []
    assert out["alignment"]["character_start_times_seconds"] == []


def test_no_boundaries_falls_back_to_proportional_tail():
    text = "hello"
    out = expand(text, [])
    _assert_invariants(out, text)
    # All five chars filled by trailing-pad path
    assert _block(out)["character_end_times_seconds"][-1] > 0.0


def test_case_insensitive_word_match():
    text = "Hello world"
    boundaries = [
        {"text": "hello", "offset_ms": 0, "duration_ms": 500},
        {"text": "world", "offset_ms": 600, "duration_ms": 400},
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)
    # Capital "H" gets the start of word time
    assert _block(out)["characters"][0] == "H"
    assert _block(out)["character_start_times_seconds"][0] == 0.0


def test_orphan_boundary_skipped():
    text = "alpha beta"
    boundaries = [
        {"text": "alpha", "offset_ms": 0, "duration_ms": 300},
        {"text": "xyzzy", "offset_ms": 350, "duration_ms": 200},  # not in text
        {"text": "beta", "offset_ms": 600, "duration_ms": 300},
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)
    # "alpha" and "beta" still aligned; orphan absorbed by gap
    assert _block(out)["character_start_times_seconds"][0] == 0.0


def test_punctuation_belongs_to_gap_or_tail():
    text = "Hello, world!"
    boundaries = [
        {"text": "Hello", "offset_ms": 0, "duration_ms": 400},
        {"text": "world", "offset_ms": 500, "duration_ms": 400},
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)
    block = _block(out)
    # Final "!" gets a non-zero, post-word timestamp
    assert block["character_start_times_seconds"][-1] >= 0.9
    # Comma at index 5 sits between "Hello" end (0.4) and "world" start (0.5)
    comma_start = block["character_start_times_seconds"][5]
    assert 0.4 <= comma_start <= 0.5


def test_backward_offset_clamped_to_monotonic():
    text = "hello world"
    boundaries = [
        {"text": "hello", "offset_ms": 1000, "duration_ms": 300},
        {"text": "world", "offset_ms": 500, "duration_ms": 300},  # backward!
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)


def test_schema_keys_match_elevenlabs():
    text = "test"
    boundaries = [{"text": "test", "offset_ms": 0, "duration_ms": 300}]
    out = expand(text, boundaries)
    assert set(out.keys()) == {"alignment", "normalized_alignment"}
    for key in ("alignment", "normalized_alignment"):
        assert set(out[key].keys()) == {
            "characters",
            "character_start_times_seconds",
            "character_end_times_seconds",
        }


def test_long_text_no_drift_at_each_word_start():
    text = "one two three four five"
    boundaries = [
        {"text": "one",   "offset_ms": 0,    "duration_ms": 200},
        {"text": "two",   "offset_ms": 250,  "duration_ms": 200},
        {"text": "three", "offset_ms": 500,  "duration_ms": 300},
        {"text": "four",  "offset_ms": 850,  "duration_ms": 250},
        {"text": "five",  "offset_ms": 1150, "duration_ms": 300},
    ]
    out = expand(text, boundaries)
    _assert_invariants(out, text)
    block = _block(out)
    # The first character of each word should land at that word's offset
    word_start_offsets = [(0, 0.0), (4, 0.25), (8, 0.5), (14, 0.85), (19, 1.15)]
    for char_idx, expected_s in word_start_offsets:
        assert block["character_start_times_seconds"][char_idx] == pytest.approx(expected_s, abs=0.01)


def test_normalized_alignment_independent_of_alignment():
    """Mutating one block must not mutate the other."""
    text = "hello"
    boundaries = [{"text": "hello", "offset_ms": 0, "duration_ms": 300}]
    out = expand(text, boundaries)
    out["alignment"]["characters"][0] = "X"
    assert out["normalized_alignment"]["characters"][0] == "h"
