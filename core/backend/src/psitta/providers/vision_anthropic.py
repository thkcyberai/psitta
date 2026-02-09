"""
Anthropic Claude vision description provider.

Generates natural-language descriptions of images, charts, and tables
using Claude's multimodal capabilities.
"""

from __future__ import annotations

import base64
import uuid

import httpx
import structlog

from psitta.providers.interfaces.contracts import VisualDescription, VisionDescriptionProvider

logger = structlog.get_logger()


class AnthropicVisionProvider:
    """Anthropic Claude-based visual element description."""

    def __init__(self, api_key: str, model: str = "claude-sonnet-4-20250514") -> None:
        self._api_key = api_key
        self._model = model
        self._base_url = "https://api.anthropic.com/v1/messages"

    async def _call_api(self, image_data: bytes, prompt: str) -> str:
        """Make a multimodal API call to Claude."""
        b64_image = base64.b64encode(image_data).decode("utf-8")

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                self._base_url,
                headers={
                    "x-api-key": self._api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json",
                },
                json={
                    "model": self._model,
                    "max_tokens": 500,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image",
                                    "source": {
                                        "type": "base64",
                                        "media_type": "image/png",
                                        "data": b64_image,
                                    },
                                },
                                {"type": "text", "text": prompt},
                            ],
                        }
                    ],
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["content"][0]["text"]

    async def describe(self, image_data: bytes, context: str = "") -> VisualDescription:
        prompt = (
            "Describe this image concisely for someone who cannot see it. "
            "Focus on the key information conveyed. Keep it under 3 sentences. "
            f"Context: {context}" if context else
            "Describe this image concisely for someone who cannot see it. "
            "Focus on the key information conveyed. Keep it under 3 sentences."
        )
        description = await self._call_api(image_data, prompt)
        return VisualDescription(
            element_id=str(uuid.uuid4()),
            description=description,
            confidence=0.85,
            alt_text=description[:250],
        )

    async def describe_chart(self, image_data: bytes, context: str = "") -> VisualDescription:
        prompt = (
            "This is a chart or graph from a document. Describe: "
            "1) The type of chart, 2) What data it shows, 3) Key trends or takeaways. "
            "Be concise and factual."
        )
        description = await self._call_api(image_data, prompt)
        return VisualDescription(
            element_id=str(uuid.uuid4()),
            description=description,
            confidence=0.80,
            alt_text=description[:250],
        )

    async def describe_table(self, image_data: bytes, context: str = "") -> VisualDescription:
        prompt = (
            "This is a table from a document. Describe: "
            "1) What the table contains (columns, rows), "
            "2) Key data points or patterns. "
            "Summarize rather than reading every cell."
        )
        description = await self._call_api(image_data, prompt)
        return VisualDescription(
            element_id=str(uuid.uuid4()),
            description=description,
            confidence=0.80,
            alt_text=description[:250],
        )
