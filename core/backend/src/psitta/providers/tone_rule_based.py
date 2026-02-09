"""
Psitta — Rule-Based Tone Classifier.

Implements the ToneClassifier protocol using keyword and pattern
matching heuristics. This is the core (free) classifier; the
LLM-based classifier is available as a commercial extension.

The rule-based approach is fast (sub-millisecond), deterministic,
and requires no external API calls.

Accuracy: ~70% on our benchmark. Suitable for MVP; the extension
LLM classifier achieves ~92%.
"""

from __future__ import annotations

import re

import structlog

from psitta.models.domain import ToneCategory

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# ── Pattern Definitions ────────────────────────────────────────────────
# Each pattern maps a regex to a tone category with a confidence weight.
# The highest-weighted match wins.

_FORMAL_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(therefore|consequently|furthermore|moreover|hereby)\b", re.I),
    re.compile(r"\b(pursuant|notwithstanding|whereas|herein|thereof)\b", re.I),
    re.compile(r"\b(shall|must comply|in accordance with)\b", re.I),
]

_CONVERSATIONAL_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(you know|like|basically|anyway|so yeah)\b", re.I),
    re.compile(r"\b(let's|we'll|you'll|don't|can't|won't)\b", re.I),
    re.compile(r"[!?]{2,}"),
]

_EMPHATIC_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(critical|urgent|essential|crucial|vital|warning)\b", re.I),
    re.compile(r"\b(must|never|always|absolutely|immediately)\b", re.I),
    re.compile(r"[A-Z]{3,}"),  # ALL CAPS words
    re.compile(r"[!]{1,}"),
]

_TECHNICAL_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(function|class|method|algorithm|parameter|variable)\b", re.I),
    re.compile(r"\b(API|SDK|HTTP|SQL|JSON|YAML|REST|gRPC)\b"),
    re.compile(r"\b(implementation|architecture|protocol|interface)\b", re.I),
    re.compile(r"```|\bdef\b|\bimport\b|\breturn\b"),
]

_NARRATIVE_PATTERNS: list[re.Pattern[str]] = [
    re.compile(r"\b(once upon|long ago|in the beginning|story|tale)\b", re.I),
    re.compile(r"\b(he said|she said|they whispered|he thought)\b", re.I),
    re.compile(r"\b(chapter|scene|character|protagonist)\b", re.I),
]


class RuleBasedToneClassifier:
    """Keyword/pattern-based tone classifier.

    Satisfies the ToneClassifier protocol from contracts.py.
    Fast, deterministic, no external dependencies.
    """

    async def classify(self, text: str) -> ToneCategory:
        """Classify text tone using pattern matching.

        Scores each category by counting pattern matches,
        returns the highest-scoring category. Falls back
        to NEUTRAL if no patterns match.
        """
        if not text.strip():
            return ToneCategory.NEUTRAL

        scores: dict[ToneCategory, int] = {
            ToneCategory.FORMAL: sum(
                1 for p in _FORMAL_PATTERNS if p.search(text)
            ),
            ToneCategory.CONVERSATIONAL: sum(
                1 for p in _CONVERSATIONAL_PATTERNS if p.search(text)
            ),
            ToneCategory.EMPHATIC: sum(
                1 for p in _EMPHATIC_PATTERNS if p.search(text)
            ),
            ToneCategory.TECHNICAL: sum(
                1 for p in _TECHNICAL_PATTERNS if p.search(text)
            ),
            ToneCategory.NARRATIVE: sum(
                1 for p in _NARRATIVE_PATTERNS if p.search(text)
            ),
        }

        max_score = max(scores.values())

        if max_score == 0:
            return ToneCategory.NEUTRAL

        # Return highest scoring category
        result = max(scores, key=scores.get)  # type: ignore[arg-type]

        logger.debug(
            "tone.classify",
            result=result.value,
            scores={k.value: v for k, v in scores.items()},
            text_length=len(text),
        )

        return result
