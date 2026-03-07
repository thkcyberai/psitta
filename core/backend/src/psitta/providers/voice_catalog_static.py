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
    # ── ElevenLabs Voices ──────────────────────────────────────────────
    VoiceProfile(
        id="21m00Tcm4TlvDq8ikWAM",
        display_name="Rachel",
        language="en-US",
        gender="female",
        provider="elevenlabs",
        tier="free",
        styles=["narration-professional", "calm"],
        description="Warm, clear female voice. Default for new documents.",
    ),
    VoiceProfile(
        id="EXAVITQu4vr4xnSDxMaL",
        display_name="Bella",
        language="en-US",
        gender="female",
        provider="elevenlabs",
        tier="free",
        styles=["chat", "soft"],
        description="Soft, friendly female voice with natural tone.",
    ),
    VoiceProfile(
        id="AZnzlk1XvdvUeBnXmlld",
        display_name="Domi",
        language="en-US",
        gender="female",
        provider="elevenlabs",
        tier="free",
        styles=["assertive", "narration"],
        description="Strong, assertive female voice.",
    ),
    VoiceProfile(
        id="MF3mGyEYCl7XYWbV9V6O",
        display_name="Elli",
        language="en-US",
        gender="female",
        provider="elevenlabs",
        tier="free",
        styles=["young", "cheerful"],
        description="Young, cheerful female voice.",
    ),
    VoiceProfile(
        id="z9fAnlkpzviPz146aGWa",
        display_name="Glinda",
        language="en-US",
        gender="female",
        provider="elevenlabs",
        tier="free",
        styles=["witch", "whimsical"],
        description="Whimsical, expressive female voice.",
    ),
    VoiceProfile(
        id="pNInz6obpgDQGcFmaJgB",
        display_name="Adam",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["narration-professional", "deep"],
        description="Deep, confident male voice for narration.",
    ),
    VoiceProfile(
        id="29vD33N1rvyd6jmgXNSe",
        display_name="Drew",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["well-rounded", "narration"],
        description="Well-rounded male voice.",
    ),
    VoiceProfile(
        id="ErXwobaYiN019PkySvjV",
        display_name="Antoni",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["well-rounded", "calm"],
        description="Calm, well-rounded male voice.",
    ),
    VoiceProfile(
        id="2EiwWnXFnvU5JabPnv8n",
        display_name="Clyde",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["war-veteran", "deep"],
        description="Deep, gravelly male voice.",
    ),
    VoiceProfile(
        id="TxGEqnHWrfWFTfGW9XjX",
        display_name="Josh",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["young", "deep"],
        description="Young, deep male voice.",
    ),
    VoiceProfile(
        id="VR6AewLTigWG4xSOukaG",
        display_name="Arnold",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["crisp", "narration"],
        description="Crisp, authoritative male voice.",
    ),
    VoiceProfile(
        id="yoZ06aMxZJJ28mfd3POQ",
        display_name="Sam",
        language="en-US",
        gender="male",
        provider="elevenlabs",
        tier="free",
        styles=["raspy", "young"],
        description="Raspy, youthful male voice.",
    ),
    # ── Azure Voices (fallback) ────────────────────────────────────────
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
