"""
Azure Cognitive Services TTS provider.

Core (free-tier) TTS implementation using Azure Neural Voices.
"""

from __future__ import annotations

from typing import AsyncIterator

import httpx
import structlog

from psitta.providers.interfaces.contracts import (
    AudioChunk,
    AudioFormat,
    CostEstimate,
    TTSOptions,
    TTSProvider,
)

logger = structlog.get_logger()

# Azure TTS pricing: ~$16 per 1M characters (neural voices)
COST_PER_MILLION_CHARS_USD = 16.0


class AzureTTSProvider:
    """Azure Cognitive Services Neural TTS implementation."""

    def __init__(self, key: str, region: str = "eastus") -> None:
        self._key = key
        self._region = region
        self._endpoint = f"https://{region}.tts.speech.microsoft.com"
        self._token_url = f"https://{region}.api.cognitive.microsoft.com/sts/v1.0/issueToken"

    async def _get_token(self) -> str:
        """Fetch a short-lived auth token from Azure."""
        async with httpx.AsyncClient() as client:
            response = await client.post(
                self._token_url,
                headers={"Ocp-Apim-Subscription-Key": self._key},
            )
            response.raise_for_status()
            return response.text

    async def synthesize(
        self, text: str, voice_id: str, options: TTSOptions
    ) -> AsyncIterator[AudioChunk]:
        """Synthesize text to audio using Azure Neural TTS."""
        ssml = self._build_ssml(text, voice_id, options)
        yield await self._call_tts_api(ssml, options.output_format)

    async def synthesize_ssml(
        self, ssml: str, voice_id: str, options: TTSOptions
    ) -> AsyncIterator[AudioChunk]:
        """Synthesize pre-built SSML."""
        yield await self._call_tts_api(ssml, options.output_format)

    async def _call_tts_api(
        self, ssml: str, output_format: AudioFormat
    ) -> AudioChunk:
        """Make the actual TTS API call."""
        token = await self._get_token()

        format_map = {
            AudioFormat.MP3: "audio-24khz-96kbitrate-mono-mp3",
            AudioFormat.WAV: "riff-24khz-16bit-mono-pcm",
            AudioFormat.OGG: "ogg-24khz-16bit-mono-opus",
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self._endpoint}/cognitiveservices/v1",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/ssml+xml",
                    "X-Microsoft-OutputFormat": format_map.get(
                        output_format, "audio-24khz-96kbitrate-mono-mp3"
                    ),
                },
                content=ssml.encode("utf-8"),
            )
            response.raise_for_status()

            return AudioChunk(
                data=response.content,
                format=output_format,
                duration_ms=0,  # Calculate from audio metadata
                sequence_num=0,
                is_last=True,
            )

    def _build_ssml(self, text: str, voice_id: str, options: TTSOptions) -> str:
        """Build SSML with prosody controls."""
        rate = f"{int(options.speed * 100)}%"
        pitch = f"{int(options.pitch)}%"
        volume = f"{int(options.volume * 100)}%"

        return f"""<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
    xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="en-US">
  <voice name="{voice_id}">
    <prosody rate="{rate}" pitch="{pitch}" volume="{volume}">
      {text}
    </prosody>
  </voice>
</speak>"""

    async def estimate_cost(self, char_count: int, voice_id: str) -> CostEstimate:
        return CostEstimate(
            character_count=char_count,
            estimated_cost_usd=(char_count / 1_000_000) * COST_PER_MILLION_CHARS_USD,
            provider="azure",
            voice_id=voice_id,
        )

    async def health_check(self) -> bool:
        try:
            await self._get_token()
            return True
        except Exception:
            logger.warning("azure_tts_health_check_failed")
            return False
