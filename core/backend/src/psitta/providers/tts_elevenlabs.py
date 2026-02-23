"""Psitta - ElevenLabs TTS Provider."""

from __future__ import annotations

import httpx
import structlog

from psitta.config import get_settings
from psitta.providers.tts_errors import TTSProviderError

logger = structlog.get_logger(__name__)

ELEVENLABS_BASE = "https://api.elevenlabs.io/v1"

# ElevenLabs voice IDs mapped to display names
ELEVENLABS_VOICES = {
    "21m00Tcm4TlvDq8ikWAM": {"name": "Rachel", "gender": "female", "lang": "en-US", "tier": "free"},
    "29vD33N1CtxCmqQRPOHJ": {"name": "Drew", "gender": "male", "lang": "en-US", "tier": "free"},
    "2EiwWnXFnvU5JabPnv8n": {"name": "Clyde", "gender": "male", "lang": "en-US", "tier": "free"},
    "AZnzlk1XvdvUeBnXmlld": {"name": "Domi", "gender": "female", "lang": "en-US", "tier": "free"},
    "EXAVITQu4vr4xnSDxMaL": {"name": "Bella", "gender": "female", "lang": "en-US", "tier": "free"},
    "ErXwobaYiN019PkySvjV": {"name": "Antoni", "gender": "male", "lang": "en-US", "tier": "free"},
    "MF3mGyEYCl7XYWbV9V6O": {"name": "Elli", "gender": "female", "lang": "en-US", "tier": "free"},
    "TxGEqnHWrfWFTfGW9XjX": {"name": "Josh", "gender": "male", "lang": "en-US", "tier": "free"},
    "VR6AewLTigWG4xSOukaG": {"name": "Arnold", "gender": "male", "lang": "en-US", "tier": "free"},
    "pNInz6obpgDQGcFmaJgB": {"name": "Adam", "gender": "male", "lang": "en-US", "tier": "free"},
    "yoZ06aMxZJJ28mfd3POQ": {"name": "Sam", "gender": "male", "lang": "en-US", "tier": "free"},
    "jBpfuIE2acCO8z3wKNLl": {"name": "Gigi", "gender": "female", "lang": "en-US", "tier": "free"},
}


class ElevenLabsTTSProvider:
    """ElevenLabs text-to-speech provider."""

    def __init__(self) -> None:
        settings = get_settings()
        self.api_key = settings.ELEVENLABS_API_KEY.get_secret_value()
        self.model = settings.ELEVENLABS_MODEL

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        output_format: str = "mp3_44100_128",
    ) -> bytes:
        """Synthesize text to audio via ElevenLabs API."""
        if not self.api_key:
            raise RuntimeError("ELEVENLABS_API_KEY not configured")

        url = f"{ELEVENLABS_BASE}/text-to-speech/{voice_id}"
        headers = {
            "xi-api-key": self.api_key,
            "Content-Type": "application/json",
        }
        payload = {
            "text": text[:5000],
            "model_id": self.model,
            "voice_settings": {
                "stability": 0.5,
                "similarity_boost": 0.75,
                "speed": speed,
            },
        }
        params = {"output_format": output_format}

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                response = await client.post(url, json=payload, headers=headers, params=params)
        except httpx.RequestError as exc:
            logger.error("elevenlabs.synthesize.network_error", error=str(exc))
            raise TTSProviderError("elevenlabs", f"Network error: {exc}", status_code=None) from exc

        if response.status_code != 200:
            logger.error(
                "elevenlabs.synthesize.failed",
                status=response.status_code,
                body=response.text[:200],
            )
            raise TTSProviderError(
                "elevenlabs",
                f"ElevenLabs API error: {response.status_code}",
                status_code=response.status_code,
            )

        logger.info("elevenlabs.synthesize.ok", voice_id=voice_id, chars=len(text))
        return response.content

    async def get_voices(self) -> list[dict]:
        """Fetch available voices from ElevenLabs API."""
        if not self.api_key:
            return list(ELEVENLABS_VOICES.values())

        url = f"{ELEVENLABS_BASE}/voices"
        headers = {"xi-api-key": self.api_key}

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(url, headers=headers)
            if response.status_code != 200:
                logger.warning("elevenlabs.voices.failed", status=response.status_code)
                return list(ELEVENLABS_VOICES.values())

            data = response.json()
            return [
                {
                    "id": v["voice_id"],
                    "name": v["name"],
                    "gender": v.get("labels", {}).get("gender", "unknown"),
                    "lang": v.get("labels", {}).get("language", "en"),
                }
                for v in data.get("voices", [])
            ]

    async def health_check(self) -> bool:
        """Check ElevenLabs API connectivity."""
        if not self.api_key:
            return False
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                r = await client.get(
                    f"{ELEVENLABS_BASE}/user",
                    headers={"xi-api-key": self.api_key},
                )
                return r.status_code == 200
        except Exception:
            return False
