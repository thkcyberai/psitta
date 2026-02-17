"""Psitta - TTS Provider Router with Failover.

Routes TTS requests through a priority chain of providers:
  1. Primary: ElevenLabs (premium quality, paid)
  2. Fallback: Azure Neural (high quality, paid/$0 free tier)
  3. Free fallback: Edge TTS (same Azure Neural voices, always free)

On quota exhaustion, API errors, or missing keys, automatically
falls back to the next available provider.
"""

from __future__ import annotations

import structlog
from psitta.config import get_settings

logger = structlog.get_logger(__name__)


class TTSRouter:
    """Routes TTS requests with automatic failover.

    Priority: ElevenLabs -> Azure Neural -> Edge TTS (free)
    Falls back on any exception from a provider.
    """

    def __init__(self) -> None:
        settings = get_settings()
        self._elevenlabs = None
        self._azure = None
        self._edge = None

        # Initialize ElevenLabs if key is set
        el_key = settings.ELEVENLABS_API_KEY.get_secret_value()
        if el_key:
            try:
                from psitta.providers.tts_elevenlabs import ElevenLabsTTSProvider
                self._elevenlabs = ElevenLabsTTSProvider()
                logger.info("tts_router.elevenlabs.ready")
            except Exception as e:
                logger.warning("tts_router.elevenlabs.init_failed", error=str(e))

        # Initialize Azure if key is set
        az_key = settings.AZURE_TTS_KEY.get_secret_value()
        if az_key:
            try:
                from psitta.providers.tts_azure import AzureTTSProvider
                self._azure = AzureTTSProvider(settings)
                logger.info("tts_router.azure.ready", region=settings.AZURE_TTS_REGION)
            except Exception as e:
                logger.warning("tts_router.azure.init_failed", error=str(e))

        # Edge TTS is always available (no key needed)
        try:
            from psitta.providers.tts_edge import EdgeTTSProvider
            self._edge = EdgeTTSProvider()
            logger.info("tts_router.edge.ready")
        except Exception as e:
            logger.warning("tts_router.edge.init_failed", error=str(e))

    @property
    def has_provider(self) -> bool:
        """At least one TTS provider is configured."""
        return any([self._elevenlabs, self._azure, self._edge])

    @property
    def providers_status(self) -> dict:
        """Status of all providers for health/debug endpoints."""
        return {
            "elevenlabs": "ready" if self._elevenlabs else "not configured",
            "azure": "ready" if self._azure else "not configured",
            "edge": "ready" if self._edge else "not available",
        }

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        output_format: str = "mp3_44100_128",
    ) -> bytes:
        """Synthesize text with automatic provider failover.

        Tries: ElevenLabs -> Azure -> Edge TTS
        Returns audio bytes on success, raises RuntimeError if all fail.
        """
        errors: list[str] = []

        # -- Try ElevenLabs (primary) --
        if self._elevenlabs:
            try:
                audio = await self._elevenlabs.synthesize(
                    text=text, voice_id=voice_id, speed=speed,
                    output_format=output_format,
                )
                logger.info("tts_router.ok", provider="elevenlabs", voice_id=voice_id, size=len(audio))
                return audio
            except Exception as e:
                errors.append(f"elevenlabs: {e}")
                logger.warning("tts_router.elevenlabs.failed", error=str(e), fallback="azure")

        # -- Try Azure (second) --
        if self._azure:
            try:
                from psitta.providers.tts_router_maps import elevenlabs_to_azure
                azure_voice = elevenlabs_to_azure(voice_id)
                from psitta.models.domain import ToneCategory
                audio = await self._azure.synthesize(
                    text=text, voice_id=azure_voice, speed=speed,
                    tone=ToneCategory.NEUTRAL, output_format="mp3",
                )
                logger.info("tts_router.ok", provider="azure", azure_voice=azure_voice, size=len(audio))
                return audio
            except Exception as e:
                errors.append(f"azure: {e}")
                logger.warning("tts_router.azure.failed", error=str(e), fallback="edge")

        # -- Try Edge TTS (free fallback) --
        if self._edge:
            try:
                audio = await self._edge.synthesize(
                    text=text, voice_id=voice_id, speed=speed,
                )
                logger.info("tts_router.ok", provider="edge", voice_id=voice_id, size=len(audio))
                return audio
            except Exception as e:
                errors.append(f"edge: {e}")
                logger.error("tts_router.edge.failed", error=str(e))

        # -- All failed --
        error_summary = "; ".join(errors) if errors else "No TTS providers available"
        logger.error("tts_router.all_failed", errors=error_summary)
        raise RuntimeError(f"All TTS providers failed: {error_summary}")
