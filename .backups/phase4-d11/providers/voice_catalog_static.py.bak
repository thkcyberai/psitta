"""
Static voice catalog provider — ships with core.

Provides a curated set of high-quality neural voices from Azure.
Premium voices (ElevenLabs) are loaded via extension.
"""

from __future__ import annotations

from psitta.providers.interfaces.contracts import VoiceFilter, VoiceMeta, VoiceCatalogProvider

# Curated catalog of Azure Neural Voices meeting quality bar (MOS >= 4.0)
_VOICES: list[VoiceMeta] = [
    VoiceMeta(id="en-US-AriaNeural", name="Aria", language="en-US", gender="female",
              style="narrative", provider="azure", preview_url="", is_premium=False,
              quality_score=4.5, description="Warm and expressive narrator",
              supported_emotions=["neutral", "cheerful", "sad", "angry", "excited"]),
    VoiceMeta(id="en-US-GuyNeural", name="Guy", language="en-US", gender="male",
              style="narrative", provider="azure", preview_url="", is_premium=False,
              quality_score=4.4, description="Professional male narrator",
              supported_emotions=["neutral", "cheerful", "sad"]),
    VoiceMeta(id="en-US-JennyNeural", name="Jenny", language="en-US", gender="female",
              style="conversational", provider="azure", preview_url="", is_premium=False,
              quality_score=4.3, description="Friendly conversational voice",
              supported_emotions=["neutral", "cheerful", "excited"]),
    VoiceMeta(id="en-US-DavisNeural", name="Davis", language="en-US", gender="male",
              style="formal", provider="azure", preview_url="", is_premium=False,
              quality_score=4.3, description="Authoritative and clear",
              supported_emotions=["neutral"]),
    VoiceMeta(id="en-US-SaraNeural", name="Sara", language="en-US", gender="female",
              style="warm", provider="azure", preview_url="", is_premium=False,
              quality_score=4.2, description="Warm and approachable",
              supported_emotions=["neutral", "cheerful"]),
    VoiceMeta(id="en-GB-SoniaNeural", name="Sonia", language="en-GB", gender="female",
              style="narrative", provider="azure", preview_url="", is_premium=False,
              quality_score=4.4, description="British English narrator",
              supported_emotions=["neutral", "cheerful", "sad"]),
    VoiceMeta(id="en-GB-RyanNeural", name="Ryan", language="en-GB", gender="male",
              style="formal", provider="azure", preview_url="", is_premium=False,
              quality_score=4.3, description="British English formal voice",
              supported_emotions=["neutral"]),
    VoiceMeta(id="en-AU-NatashaNeural", name="Natasha", language="en-AU", gender="female",
              style="conversational", provider="azure", preview_url="", is_premium=False,
              quality_score=4.2, description="Australian English conversational",
              supported_emotions=["neutral", "cheerful"]),
]


class StaticVoiceCatalogProvider:
    """In-memory voice catalog backed by a curated JSON list."""

    def __init__(self, voices: list[VoiceMeta] | None = None) -> None:
        self._voices = voices or _VOICES

    async def list_voices(self, filters: VoiceFilter) -> list[VoiceMeta]:
        result = self._voices

        if filters.language:
            result = [v for v in result if v.language.startswith(filters.language)]
        if filters.gender:
            result = [v for v in result if v.gender == filters.gender]
        if filters.style:
            result = [v for v in result if v.style == filters.style]
        if filters.provider:
            result = [v for v in result if v.provider == filters.provider]
        if filters.is_premium is not None:
            result = [v for v in result if v.is_premium == filters.is_premium]

        return result

    async def get_voice(self, voice_id: str) -> VoiceMeta | None:
        return next((v for v in self._voices if v.id == voice_id), None)

    async def get_preview_audio(self, voice_id: str) -> bytes:
        """Return preview audio. In production, these are cached in S3."""
        # Placeholder: return empty bytes until preview generation is implemented
        return b""
