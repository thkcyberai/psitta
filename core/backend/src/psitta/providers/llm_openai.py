"""Psitta — OpenAI LLM provider for Summarize-it (WD-B1).

Mirrors the httpx pattern in providers/tts_elevenlabs.py.
Callers should catch LlmProviderError for any network or API failure.
"""

from __future__ import annotations

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
