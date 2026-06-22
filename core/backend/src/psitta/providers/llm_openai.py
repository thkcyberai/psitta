"""Psitta — OpenAI LLM provider for Summarize-it and the AI Story-Coach.

Mirrors the httpx pattern in providers/tts_elevenlabs.py.
Callers should catch LlmProviderError for any network or API failure.
"""

from __future__ import annotations

import json

import structlog
import httpx

from psitta.config import get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_SYSTEM_PROMPT = (
    "You are a skilled document summarizer. "
    "Provide a clear, concise summary that captures the key points and main arguments. "
    "Write in plain prose, 3 to 5 paragraphs. "
    "Do not include headings or bullet points."
)

# AI Story-Coach: judges whether a passage fits the writer's committed narrative.
_COACH_SYSTEM_PROMPT = (
    "You are a warm but discerning story-structure coach for a fiction writer. "
    "The writer committed to a narrative structure, an audience variant, and an "
    "ordered list of story beats. You will be given that commitment and a "
    "passage the writer just drafted. Decide whether the passage reads as "
    "coherent story material that plausibly belongs somewhere in that arc.\n"
    'Set "aligned": false when the passage does NOT fit the chosen narrative — '
    "for example: it is not narrative prose at all (instructions, notes, "
    "technical or factual text, lists, to-dos), it introduces content unrelated "
    "to the story or its beats, it lurches in tone or topic from one line to the "
    "next, or it resolves or jumps the arc badly out of order. "
    'Set "aligned": true when the passage is plausible story content for some '
    "beat of the arc — including early setup, mood, texture, or a minor "
    "digression. Do not nitpick legitimate creative choices.\n"
    "Respond with ONLY a JSON object, no prose, no code fences, with exactly "
    "these keys:\n"
    '  "aligned": boolean,\n'
    '  "suspected_beat": string — the beat this passage reads most like (from '
    "the provided list), or a short label if none fit,\n"
    '  "message": string — ONE short, kind sentence. If aligned, a light '
    "affirmation. If not, name the drift plainly and offer a gentle question, "
    "never a command. Address the writer as 'you'."
)


class LlmProviderError(Exception):
    """Raised when the LLM provider call fails."""


class LlmOpenAIProvider:
    """OpenAI chat completions provider for document summarization.

    Uses httpx.AsyncClient(timeout=60.0) — same pattern as tts_elevenlabs.py.
    API key and model are read from settings at construction time.
    """

    def __init__(self) -> None:
        settings = get_settings()
        self._api_key = settings.OPENAI_API_KEY.get_secret_value()
        self._model = settings.OPENAI_SUMMARIZE_MODEL

    async def summarize(
        self,
        text: str,
        doc_title: str,
    ) -> tuple[str, int, int]:
        """Summarize text via OpenAI chat completions.

        Args:
            text: Plain text of the document to summarize.
            doc_title: Document title included in the user prompt for context.

        Returns:
            (summary_text, prompt_tokens, completion_tokens)

        Raises:
            LlmProviderError on network errors or non-200 status codes.
        """
        payload = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": (
                        f"Please summarize the following document titled "
                        f"'{doc_title}':\n\n{text}"
                    ),
                },
            ],
            "max_tokens": 1024,
        }

        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    _CHAT_URL,
                    json=payload,
                    headers=headers,
                )
        except httpx.RequestError as exc:
            logger.error("llm.openai.request_error", error=str(exc))
            raise LlmProviderError(f"OpenAI request failed: {exc}") from exc

        if response.status_code != 200:
            logger.error(
                "llm.openai.error_status",
                status=response.status_code,
                body=response.text[:200],
            )
            raise LlmProviderError(
                f"OpenAI returned HTTP {response.status_code}"
            )

        data = response.json()
        summary: str = data["choices"][0]["message"]["content"]
        usage = data.get("usage", {})
        prompt_tokens: int = usage.get("prompt_tokens", 0)
        completion_tokens: int = usage.get("completion_tokens", 0)

        logger.info(
            "llm.openai.ok",
            model=self._model,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            summary_chars=len(summary),
        )

        return summary, prompt_tokens, completion_tokens

    async def check_narrative(
        self,
        *,
        passage: str,
        structure_name: str,
        variant: str | None,
        beats: list[str],
        beat_index: int | None = None,
    ) -> tuple[dict, int, int]:
        """Judge whether a drafted passage fits the writer's chosen narrative.

        Args:
            passage: The text the writer just drafted (never logged here).
            structure_name: Display name of the chosen structure.
            variant: The chosen audience/Best-For variant, if any.
            beats: Ordered beat names the writer committed to.
            beat_index: Optional 0-based hint for which beat the writer believes
                they are currently writing.

        Returns:
            (verdict, prompt_tokens, completion_tokens) where verdict is a dict
            with keys ``aligned`` (bool), ``message`` (str), ``suspected_beat``
            (str). The verdict is always coerced to a safe shape; a parse failure
            degrades to an aligned/no-op verdict rather than raising.

        Raises:
            LlmProviderError on network errors or non-200 status codes.
        """
        beat_lines = "\n".join(
            f"  {i + 1}. {b}" for i, b in enumerate(beats)
        ) or "  (no beats chosen)"
        arc_label = structure_name + (f" — {variant}" if variant else "")
        focus = (
            f"\nThe writer believes they are currently writing beat "
            f"#{beat_index + 1} ({beats[beat_index]})."
            if beat_index is not None and 0 <= beat_index < len(beats)
            else ""
        )
        user_content = (
            f"NARRATIVE: {arc_label}\n"
            f"BEATS (in order):\n{beat_lines}{focus}\n\n"
            f"PASSAGE:\n{passage}"
        )

        payload = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": _COACH_SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            "max_tokens": 220,
            "response_format": {"type": "json_object"},
        }

        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(
                    _CHAT_URL,
                    json=payload,
                    headers=headers,
                )
        except httpx.RequestError as exc:
            logger.error("llm.openai.coach.request_error", error=str(exc))
            raise LlmProviderError(f"OpenAI request failed: {exc}") from exc

        if response.status_code != 200:
            logger.error(
                "llm.openai.coach.error_status",
                status=response.status_code,
                body=response.text[:200],
            )
            raise LlmProviderError(f"OpenAI returned HTTP {response.status_code}")

        data = response.json()
        raw: str = data["choices"][0]["message"]["content"]
        usage = data.get("usage", {})
        prompt_tokens: int = usage.get("prompt_tokens", 0)
        completion_tokens: int = usage.get("completion_tokens", 0)

        # Coerce to a safe shape. A malformed model response must never crash the
        # coach — degrade to a no-op "aligned" verdict (never a false alarm).
        verdict = {"aligned": True, "message": "", "suspected_beat": ""}
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                verdict["aligned"] = bool(parsed.get("aligned", True))
                msg = parsed.get("message")
                verdict["message"] = msg if isinstance(msg, str) else ""
                sb = parsed.get("suspected_beat")
                verdict["suspected_beat"] = sb if isinstance(sb, str) else ""
        except (ValueError, TypeError) as exc:
            logger.warning("llm.openai.coach.parse_failed", error=str(exc))

        logger.info(
            "llm.openai.coach.ok",
            model=self._model,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            aligned=verdict["aligned"],
        )

        return verdict, prompt_tokens, completion_tokens
