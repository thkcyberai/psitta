"""
Psitta — Static Voice Catalog Provider.

Implements the VoiceCatalogProvider protocol using a hardcoded
catalog of Azure Neural voices. This is the core (free) provider;
premium voice catalogs are loaded via extensions.

The static catalog avoids API calls for voice listing, reducing
latency and external dependencies during normal operation.
"""

from __future__ import annotations

import structlog

from psitta.models.domain import VoiceProfile

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# ── Static Voice Catalog ───────────────────────────────────────────────
_VOICES: list[VoiceProfile] = [
    VoiceProfile(
        id="en-US-AriaNeural",
        display_name="Aria",
        language="en-US",
        gender="female",
        provider="azure",
        tier="free",
        styles=["chat", "narration-professional", "newscast-formal"],
        description="Warm, versatile female voice. Great for general narration.",
    ),
    VoiceProfile(
        id="en-US-GuyNeural",
        display_name="Guy",
        language="en-US",
        gender="male",
        provider="azure",
        tier="free",
        styles=["narration-professional", "newscast"],
        description="Clear male voice suited for professional content.",
    ),
    VoiceProfile(
        id="en-US-JennyNeural",
        display_name="Jenny",
        language="en-US",
        gender="female",
        provider="azure",
        tier="free",
        styles=["chat", "cheerful", "empathetic"],
        description="Friendly female voice with expressive range.",
    ),
    VoiceProfile(
        id="en-US-DavisNeural",
        display_name="Davis",
        language="en-US",
        gender="male",
        provider="azure",
        tier="free",
        styles=["chat", "narration-professional"],
        description="Confident male voice for engaging content.",
    ),
    VoiceProfile(
        id="en-GB-SoniaNeural",
        display_name="Sonia",
        language="en-GB",
        gender="female",
        provider="azure",
        tier="free",
        styles=["cheerful", "sad"],
        description="British female voice with natural warmth.",
    ),
    VoiceProfile(
        id="en-GB-RyanNeural",
        display_name="Ryan",
        language="en-GB",
        gender="male",
        provider="azure",
        tier="free",
        styles=["chat", "cheerful"],
        description="British male voice for professional narration.",
    ),
]


class StaticVoiceCatalogProvider:
    """In-memory voice catalog backed by a static list.

    Satisfies the VoiceCatalogProvider protocol from contracts.py.
    Fast, zero-dependency, always available.
    """

    async def list_voices(
        self,
        language: str | None = None,
        tier: str | None = None,
    ) -> list[VoiceProfile]:
        """Return voices filtered by language and/or tier."""
        result = _VOICES

        if language:
            result = [v for v in result if v.language == language]

        if tier:
            result = [v for v in result if v.tier == tier]

        logger.info(
            "voice_catalog.list",
            language=language,
            tier=tier,
            count=len(result),
        )

        return result

    async def get_voice(self, voice_id: str) -> VoiceProfile | None:
        """Get a specific voice by ID."""
        for voice in _VOICES:
            if voice.id == voice_id:
                return voice
        return None

    async def get_preview_url(self, voice_id: str) -> str | None:
        """Return preview URL for a voice.

        TODO: Wire to S3 storage with pre-signed URLs for
        cached preview audio files.
        """
        voice = await self.get_voice(voice_id)
        if voice is None:
            return None

        # Placeholder — preview audio not yet stored
        return f"/api/v1/voices/{voice_id}/preview/audio"
