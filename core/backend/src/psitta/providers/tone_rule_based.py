"""
Rule-based tone classifier — core implementation.

Classifies text into emotional tones using heuristics:
punctuation patterns, keyword presence, and document type context.
LLM-based classifier is the v2 extension.
"""

from __future__ import annotations

import re

from psitta.providers.interfaces.contracts import ToneClassification


# Document types that force neutral tone
NEUTRAL_FORCED_TYPES = {"legal", "medical", "technical", "financial", "scientific"}

# Keyword-to-tone mapping (lowercase)
TONE_KEYWORDS: dict[str, list[str]] = {
    "excited": ["amazing", "incredible", "breakthrough", "revolutionary", "exciting", "wow"],
    "somber": ["unfortunately", "tragic", "loss", "grief", "mourn", "devastating"],
    "formal": ["hereby", "pursuant", "whereas", "notwithstanding", "herein", "thereof"],
    "conversational": ["hey", "cool", "awesome", "gonna", "wanna", "btw", "lol"],
}

# SSML parameter presets per tone
SSML_PRESETS: dict[str, dict[str, float]] = {
    "neutral": {"rate": 0.0, "pitch": 0.0, "volume": 0.0},
    "excited": {"rate": 0.05, "pitch": 0.02, "volume": 0.05},
    "somber": {"rate": -0.1, "pitch": -0.02, "volume": -0.05},
    "formal": {"rate": -0.05, "pitch": 0.0, "volume": 0.0},
    "conversational": {"rate": 0.03, "pitch": 0.01, "volume": 0.0},
}


class RuleBasedToneClassifier:
    """Heuristic tone classification based on text patterns."""

    async def classify(self, text: str, document_type: str = "") -> ToneClassification:
        # Force neutral for sensitive document types
        if document_type.lower() in NEUTRAL_FORCED_TYPES:
            return ToneClassification(
                tone="neutral",
                confidence=1.0,
                suggested_ssml_params=SSML_PRESETS["neutral"],
            )

        text_lower = text.lower()
        scores: dict[str, float] = {tone: 0.0 for tone in SSML_PRESETS}

        # Keyword matching
        for tone, keywords in TONE_KEYWORDS.items():
            for keyword in keywords:
                if keyword in text_lower:
                    scores[tone] += 1.0

        # Punctuation patterns
        exclamation_count = text.count("!")
        question_count = text.count("?")
        ellipsis_count = text.count("...")

        if exclamation_count >= 2:
            scores["excited"] += 2.0
        if question_count >= 3:
            scores["conversational"] += 1.0
        if ellipsis_count >= 2:
            scores["somber"] += 1.0

        # Sentence length (long formal sentences)
        sentences = re.split(r"[.!?]+", text)
        avg_length = sum(len(s.split()) for s in sentences if s.strip()) / max(len(sentences), 1)
        if avg_length > 25:
            scores["formal"] += 1.5

        # Find winning tone
        best_tone = max(scores, key=lambda t: scores[t])
        best_score = scores[best_tone]

        # Default to neutral if no strong signal
        if best_score < 1.0:
            best_tone = "neutral"
            confidence = 0.9
        else:
            total = sum(scores.values()) or 1.0
            confidence = min(best_score / total, 0.95)

        return ToneClassification(
            tone=best_tone,
            confidence=confidence,
            suggested_ssml_params=SSML_PRESETS.get(best_tone, SSML_PRESETS["neutral"]),
        )
