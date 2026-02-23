"""
Psitta — Azure Cognitive TTS Provider.

Implements the TTSProvider protocol using Azure Cognitive Services
Speech SDK via REST API. Supports Neural voices with SSML prosody.

Security:
  - API key stored as SecretStr, never logged
  - SSML input is sanitized to prevent injection
  - Retry with exponential backoff on transient failures
  - Request timeout enforced (30 seconds)

Cost: ~$16/1M characters (Neural voices).
"""

from __future__ import annotations

import xml.sax.saxutils as saxutils

import httpx
import structlog
from tenacity import (
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)

from psitta.config import Settings
from psitta.models.domain import ToneCategory
from psitta.providers.tts_errors import TTSProviderError

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# Azure TTS REST endpoint template
_AZURE_TTS_URL = (
    "https://{region}.tts.speech.microsoft.com"
    "/cognitiveservices/v1"
)

# Map ToneCategory to SSML prosody style
_TONE_TO_SSML_STYLE: dict[ToneCategory, str] = {
    ToneCategory.NEUTRAL: "general",
    ToneCategory.FORMAL: "newscast-formal",
    ToneCategory.CONVERSATIONAL: "chat",
    ToneCategory.EMPHATIC: "empathetic",
    ToneCategory.NARRATIVE: "narration-professional",
    ToneCategory.TECHNICAL: "newscast-formal",
}


def _retry_on_tts_provider_error(exc: BaseException) -> bool:
    """
    Retry only on transient failures:
      - network/timeout (status_code=None)
      - 408, 429
      - 5xx
    """
    if not isinstance(exc, TTSProviderError):
        return False

    code = exc.status_code
    if code is None:
        return True
    if code in (408, 429):
        return True
    return 500 <= code < 600


class AzureTTSProvider:
    """Azure Cognitive Services TTS via REST API.

    Uses SSML for rich prosody control.
    """

    def __init__(self, settings: Settings) -> None:
        self._api_key = settings.AZURE_TTS_KEY.get_secret_value()
        self._region = settings.AZURE_TTS_REGION
        self._endpoint = _AZURE_TTS_URL.format(region=self._region)
        self._timeout = 30.0

    def _build_ssml(
        self,
        text: str,
        voice_id: str,
        speed: float,
        tone: ToneCategory,
    ) -> str:
        """Build SSML payload with prosody and style attributes.

        Security: Text is XML-escaped to prevent SSML injection.
        """
        safe_text = saxutils.escape(text)
        rate_pct = f"{int(speed * 100)}%"
        style = _TONE_TO_SSML_STYLE.get(tone, "general")

        return (
            '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
            'xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="en-US">'
            f'<voice name="{saxutils.escape(voice_id)}">'
            f'<mstts:express-as style="{style}">'
            f'<prosody rate="{rate_pct}">'
            f"{safe_text}"
            "</prosody>"
            "</mstts:express-as>"
            "</voice>"
            "</speak>"
        )

    @retry(
        retry=retry_if_exception(_retry_on_tts_provider_error),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
        reraise=True,
    )
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        tone: ToneCategory = ToneCategory.NEUTRAL,
        output_format: str = "mp3",
    ) -> bytes:
        """Synthesize text to audio via Azure Cognitive TTS REST API."""
        if len(text) > 5000:
            raise ValueError(f"Text length {len(text)} exceeds max 5000 characters")

        if not self._api_key:
            raise RuntimeError(
                "Azure TTS API key not configured. "
                "Set AZURE_TTS_KEY in environment variables."
            )

        ssml = self._build_ssml(text, voice_id, speed, tone)

        format_map = {
            "mp3": "audio-24khz-96kbitrate-mono-mp3",
            "opus": "ogg-24khz-16bit-mono-opus",
            "wav": "riff-24khz-16bit-mono-pcm",
        }
        output_fmt = format_map.get(output_format, format_map["mp3"])

        logger.info(
            "tts.azure.synthesize",
            voice_id=voice_id,
            text_length=len(text),
            speed=speed,
            tone=tone.value,
            format=output_format,
        )

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.post(
                    self._endpoint,
                    headers={
                        "Ocp-Apim-Subscription-Key": self._api_key,
                        "Content-Type": "application/ssml+xml",
                        "X-Microsoft-OutputFormat": output_fmt,
                        "User-Agent": "Psitta/0.1.0",
                    },
                    content=ssml.encode("utf-8"),
                )
                response.raise_for_status()
        except httpx.RequestError as exc:
            logger.error("tts.azure.network_error", error=str(exc))
            raise TTSProviderError("azure", f"Network error: {exc}", status_code=None) from exc
        except httpx.HTTPStatusError as exc:
            status = exc.response.status_code if exc.response is not None else None
            body_preview = ""
            try:
                body_preview = (exc.response.text or "")[:200] if exc.response is not None else ""
            except Exception:
                body_preview = ""
            logger.error("tts.azure.http_error", status=status, body=body_preview)
            raise TTSProviderError("azure", f"Azure TTS HTTP error: {status}", status_code=status) from exc

        audio_bytes = response.content
        logger.info(
            "tts.azure.synthesize.complete",
            audio_size_bytes=len(audio_bytes),
        )

        return audio_bytes

    async def get_supported_voices(self) -> list[str]:
        """Fetch available voices from Azure voices list endpoint."""
        voices_url = (
            f"https://{self._region}.tts.speech.microsoft.com"
            f"/cognitiveservices/voices/list"
        )

        try:
            async with httpx.AsyncClient(timeout=self._timeout) as client:
                response = await client.get(
                    voices_url,
                    headers={"Ocp-Apim-Subscription-Key": self._api_key},
                )
                response.raise_for_status()
                voices_data = response.json()
        except httpx.RequestError as exc:
            raise TTSProviderError("azure", f"Network error: {exc}", status_code=None) from exc
        except httpx.HTTPStatusError as exc:
            status = exc.response.status_code if exc.response is not None else None
            raise TTSProviderError("azure", f"Azure voices list HTTP error: {status}", status_code=status) from exc

        return [v["ShortName"] for v in voices_data]

    async def health_check(self) -> bool:
        """Verify Azure TTS connectivity."""
        if not self._api_key:
            return False
        try:
            voices = await self.get_supported_voices()
            return len(voices) > 0
        except Exception:
            logger.error("tts.azure.health_check.failed", exc_info=True)
            return False
