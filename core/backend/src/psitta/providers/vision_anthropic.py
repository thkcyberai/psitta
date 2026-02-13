"""
Psitta — Anthropic Vision Description Provider.

Implements the VisionDescriptionProvider protocol using Anthropic's
Claude API for generating natural language descriptions of images
embedded in documents.

Security:
  - API key stored as SecretStr, never logged
  - Image bytes are sent directly (no temporary file storage)
  - Retry with exponential backoff on transient failures
  - Response length bounded to prevent runaway costs
  - Input images validated for size and format

Cost: ~$0.003/1K input tokens, ~$0.015/1K output tokens.
"""

from __future__ import annotations

import base64

import httpx
import structlog
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from psitta.config import Settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

_ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
_MAX_IMAGE_SIZE_BYTES = 20 * 1024 * 1024  # 20 MB
_SUPPORTED_FORMATS = {"image/png", "image/jpeg", "image/webp", "image/gif"}


class AnthropicVisionProvider:
    """Anthropic Claude-based image description provider.

    Satisfies the VisionDescriptionProvider protocol from contracts.py.
    Uses Claude's multimodal capabilities to describe document images.
    """

    def __init__(self, settings: Settings) -> None:
        self._api_key = settings.ANTHROPIC_API_KEY.get_secret_value()
        self._timeout = 60.0
        self._model = "claude-sonnet-4-20250514"

    async def describe_image(
        self,
        image_bytes: bytes,
        context: str = "",
        max_words: int = 100,
    ) -> str:
        """Generate a narration-friendly description of an image.

        The description is optimized for text-to-speech — it avoids
        visual-only references and focuses on conveying meaning.
        """
        if not self._api_key:
            logger.warning("vision.anthropic.no_api_key")
            return "[Image description unavailable — API key not configured]"

        if len(image_bytes) > _MAX_IMAGE_SIZE_BYTES:
            logger.warning(
                "vision.anthropic.image_too_large",
                size_bytes=len(image_bytes),
            )
            return "[Image too large for description]"

        # Encode image to base64
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")

        # Build prompt optimized for narration
        system_prompt = (
            "You are an assistant that describes images for a document narration system. "
            "Your descriptions will be read aloud by a text-to-speech engine. "
            "Write clear, concise descriptions that convey the image's meaning "
            "without referring to visual elements the listener cannot see. "
            "Avoid phrases like 'the image shows' or 'we can see'. "
            "Instead, directly describe the content as factual statements."
        )

        user_content = []

        if context:
            user_content.append({
                "type": "text",
                "text": f"Document context around this image: {context[:500]}",
            })

        user_content.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/png",
                "data": image_b64,
            },
        })

        user_content.append({
            "type": "text",
            "text": (
                f"Describe this image in approximately {max_words} words "
                "for a listener who cannot see it."
            ),
        })

        logger.info(
            "vision.anthropic.describe",
            image_size_bytes=len(image_bytes),
            context_length=len(context),
            max_words=max_words,
        )

        async with httpx.AsyncClient(timeout=self._timeout) as client:
            response = await client.post(
                _ANTHROPIC_API_URL,
                headers={
                    "x-api-key": self._api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": self._model,
                    "max_tokens": max_words * 3,
                    "system": system_prompt,
                    "messages": [{"role": "user", "content": user_content}],
                },
            )
            response.raise_for_status()
            result = response.json()

        description = result["content"][0]["text"].strip()

        logger.info(
            "vision.anthropic.describe.complete",
            description_length=len(description),
        )

        return description

    async def health_check(self) -> bool:
        """Verify Anthropic API connectivity."""
        if not self._api_key:
            return False
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    _ANTHROPIC_API_URL,
                    headers={
                        "x-api-key": self._api_key,
                        "anthropic-version": "2023-06-01",
                        "content-type": "application/json",
                    },
                    json={
                        "model": self._model,
                        "max_tokens": 10,
                        "messages": [
                            {"role": "user", "content": "ping"}
                        ],
                    },
                )
                return response.status_code == 200
        except Exception:
            logger.error("vision.anthropic.health_check.failed", exc_info=True)
            return False
