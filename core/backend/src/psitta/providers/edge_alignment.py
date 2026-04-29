"""Psitta - Edge TTS word→character alignment expansion.

Edge TTS emits per-word boundaries (offset+duration in ms). The frontend's
_charIndexAtMs path consumes character-level alignment in ElevenLabs's
schema. This module bridges the two by walking the original chunk text
and producing parallel char-level arrays with linearly-interpolated
timestamps within each word, plus proportional gap fills for whitespace
and punctuation between words.

Output shape (matches ElevenLabs byte-for-byte):
  {
    "alignment":            {"characters", "character_start_times_seconds", "character_end_times_seconds"},
    "normalized_alignment": {"characters", "character_start_times_seconds", "character_end_times_seconds"},
  }

Length invariant: len(characters) == len(input_text).
"""

from __future__ import annotations

import structlog

logger = structlog.get_logger(__name__)

_TAIL_SECONDS_PER_CHAR = 0.050  # used only when boundaries don't cover the trailing chars
_FIND_HORIZON = 200             # max chars to look ahead when locating a boundary's word


def _find_word(text: str, cursor: int, word: str) -> tuple[int, int] | None:
    """Locate `word` in `text` starting at `cursor`. Exact match first,
    then case-insensitive. Returns (start, end) or None."""
    if not word:
        return None
    horizon = min(len(text), cursor + _FIND_HORIZON + len(word))
    haystack = text[cursor:horizon]

    idx = haystack.find(word)
    if idx >= 0:
        return cursor + idx, cursor + idx + len(word)

    idx_ci = haystack.lower().find(word.lower())
    if idx_ci >= 0:
        return cursor + idx_ci, cursor + idx_ci + len(word)

    return None


def _fill_range(
    chars: list[str],
    starts: list[float],
    ends: list[float],
    text: str,
    lo: int,
    hi: int,
    t_lo_s: float,
    t_hi_s: float,
) -> None:
    n = hi - lo
    if n <= 0:
        return
    span = max(0.0, t_hi_s - t_lo_s)
    for i in range(n):
        s = t_lo_s + (span * i) / n
        e = t_lo_s + (span * (i + 1)) / n
        idx = lo + i
        chars.append(text[idx])
        starts.append(round(s, 3))
        ends.append(round(e, 3))


def expand(text: str, boundaries: list[dict]) -> dict:
    """Convert Edge WordBoundary list to ElevenLabs-shape alignment dict."""
    chars: list[str] = []
    starts: list[float] = []
    ends: list[float] = []

    if not text:
        empty = {
            "characters": [],
            "character_start_times_seconds": [],
            "character_end_times_seconds": [],
        }
        return {"alignment": empty, "normalized_alignment": dict(empty)}

    cursor = 0
    last_end_s = 0.0
    matched = 0

    for b in boundaries:
        word = (b.get("text") or "").strip()
        offset_s = max(0.0, b.get("offset_ms", 0) / 1000.0)
        duration_s = max(0.0, b.get("duration_ms", 0) / 1000.0)

        # Monotonicity guard — Edge has been observed to emit slightly
        # backward offsets when WordBoundary chunks race.
        if offset_s < last_end_s:
            offset_s = last_end_s
        word_end_s = offset_s + duration_s

        loc = _find_word(text, cursor, word) if word else None
        if loc is None:
            continue

        w_start, w_end = loc

        if w_start > cursor:
            _fill_range(chars, starts, ends, text, cursor, w_start, last_end_s, offset_s)

        _fill_range(chars, starts, ends, text, w_start, w_end, offset_s, word_end_s)

        cursor = w_end
        last_end_s = word_end_s
        matched += 1

    if cursor < len(text):
        # Trailing tail (e.g. final punctuation, or remainder when Edge
        # dropped boundaries near end-of-utterance). Pad ~50 ms per char.
        tail_end = last_end_s + _TAIL_SECONDS_PER_CHAR * (len(text) - cursor)
        _fill_range(chars, starts, ends, text, cursor, len(text), last_end_s, tail_end)

    if len(chars) != len(text):
        logger.warning(
            "edge_alignment.length_mismatch",
            expected=len(text),
            got=len(chars),
            boundaries_total=len(boundaries),
            boundaries_matched=matched,
        )

    # If nothing matched, every char came from the 50ms/char tail path.
    # That used to ship silently — until 2026-04-29 production showed 35s
    # alignment over 21.4s audio because edge_tts defaulted to
    # SentenceBoundary. Emit a loud warning so future regressions of the
    # same shape are visible in CloudWatch instead of just-feeling-fast.
    if matched == 0 and len(text) > 0:
        logger.warning(
            "edge_alignment.no_boundaries_matched",
            boundaries_total=len(boundaries),
            text_length=len(text),
        )

    block = {
        "characters": chars,
        "character_start_times_seconds": starts,
        "character_end_times_seconds": ends,
    }
    return {
        "alignment": block,
        "normalized_alignment": {
            "characters": list(chars),
            "character_start_times_seconds": list(starts),
            "character_end_times_seconds": list(ends),
        },
    }
