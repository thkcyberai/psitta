"""Psitta - TTS Provider Router with Failover."""

from __future__ import annotations

import structlog
from typing import Any

from psitta.config import Settings, get_settings
from psitta.providers.tts_errors import TTSProviderError

logger = structlog.get_logger(__name__)


class TTSRouter:
    """Routes TTS requests with provider selection + failover."""

    def __init__(self) -> None:
        settings = get_settings()
        self._settings = settings
        self._elevenlabs = None
        self._azure = None
        self._edge = None
        self._stub = _StubTTSProvider()
        self._provider_selected: str = "stub"
        self._fallback_selected: str | None = None
        self._configure(settings)

    def _configure(self, settings: Settings) -> None:
        self._init_providers(settings)
        self._provider_selected = self._resolve_provider(settings)
        self._fallback_selected = self._resolve_fallback(settings, self._provider_selected)
        logger.info(
            "tts_router.configured",
            provider=self._provider_selected,
            fallback=self._fallback_selected or "none",
        )

    def _init_providers(self, settings: Settings) -> None:
        el_key = settings.ELEVENLABS_API_KEY.get_secret_value()
        if el_key:
            try:
                from psitta.providers.tts_elevenlabs import ElevenLabsTTSProvider

                self._elevenlabs = ElevenLabsTTSProvider()
                logger.info("tts_router.elevenlabs.ready")
            except Exception as e:
                logger.warning("tts_router.elevenlabs.init_failed", error=str(e))

        az_key = settings.AZURE_TTS_KEY.get_secret_value()
        if az_key and settings.AZURE_TTS_REGION:
            try:
                from psitta.providers.tts_azure import AzureTTSProvider

                self._azure = AzureTTSProvider(settings)
                logger.info("tts_router.azure.ready", region=settings.AZURE_TTS_REGION)
            except Exception as e:
                logger.warning("tts_router.azure.init_failed", error=str(e))

        try:
            from psitta.providers.tts_edge import EdgeTTSProvider

            self._edge = EdgeTTSProvider()
            logger.info("tts_router.edge.ready")
        except Exception as e:
            logger.warning("tts_router.edge.init_failed", error=str(e))

    def _resolve_provider(self, settings: Settings) -> str:
        provider = settings.TTS_PROVIDER

        if provider == "auto":
            if self._elevenlabs:
                return "elevenlabs"
            if self._azure:
                return "azure"
            if self._edge:
                return "edge"
            if settings.ENVIRONMENT != "production":
                return "stub"
            raise RuntimeError(
                "No TTS provider configured in production. "
                "Set ELEVENLABS_API_KEY or AZURE_TTS_KEY/AZURE_TTS_REGION, "
                "or set TTS_PROVIDER=edge."
            )

        if provider == "elevenlabs" and not self._elevenlabs:
            raise RuntimeError("TTS_PROVIDER=elevenlabs but ELEVENLABS_API_KEY is missing")
        if provider == "azure" and not self._azure:
            raise RuntimeError("TTS_PROVIDER=azure but AZURE_TTS_KEY/AZURE_TTS_REGION is missing")
        if provider == "edge" and not self._edge:
            raise RuntimeError("TTS_PROVIDER=edge but Edge TTS is unavailable")
        if provider == "stub" and settings.ENVIRONMENT == "production":
            raise RuntimeError("TTS_PROVIDER=stub is not allowed in production")

        return provider

    def _resolve_fallback(self, settings: Settings, provider: str) -> str | None:
        if provider == "edge" or provider == "stub":
            return None
        if settings.TTS_FALLBACK == "none":
            return None
        if settings.TTS_FALLBACK == "azure" and self._azure:
            return "azure"
        if settings.TTS_FALLBACK == "edge" and self._edge:
            return "edge"
        if self._edge:
            return "edge"
        return None

    def _get_provider(self, name: str):
        if name == "elevenlabs":
            return self._elevenlabs
        if name == "azure":
            return self._azure
        if name == "edge":
            return self._edge
        if name == "stub":
            return self._stub
        return None

    @property
    def has_provider(self) -> bool:
        """At least one TTS provider is configured."""
        return self._get_provider(self._provider_selected) is not None

    @property
    def providers_status(self) -> dict:
        """Status of all providers for health/debug endpoints."""
        return {
            "elevenlabs": "ready" if self._elevenlabs else "not configured",
            "azure": "ready" if self._azure else "not configured",
            "edge": "ready" if self._edge else "not available",
            "stub": "ready" if self._stub else "not available",
        }

    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        output_format: str = "mp3_44100_128",
    ) -> bytes:
        """Synthesize text with provider selection + failover (audio only)."""
        primary = self._provider_selected
        provider = self._get_provider(primary)
        if provider is None:
            raise RuntimeError(f"No TTS provider configured (selected={primary})")

        try:
            return await self._synthesize_with_provider(
                provider=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
        except TTSProviderError as e:
            logger.warning(
                "tts_router.primary_failed",
                provider=primary,
                status_code=e.status_code,
                error=str(e),
            )
            audio, _ = await self._fallback_synthesize(
                primary=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
            return audio

    async def synthesize_with_alignment(
        self,
        text: str,
        voice_id: str,
        output_format: str = "mp3_44100_128",
    ) -> tuple[bytes, dict[str, Any] | None, str]:
        """Synthesize text and return optional alignment data.

        Contract:
          - audio_bytes always returned on success
          - alignment is provider-specific JSON or None
          - provider_name indicates which provider produced the result

        For now:
          - ElevenLabs uses /with-timestamps (character-level alignment)
          - Edge captures WordBoundary events and expands to char-level
            alignment in the ElevenLabs schema
          - Azure returns alignment=None
        """
        primary = self._provider_selected
        provider = self._get_provider(primary)
        if provider is None:
            raise RuntimeError(f"No TTS provider configured (selected={primary})")

        if primary == "elevenlabs" and self._elevenlabs:
            try:
                audio, alignment = await self._elevenlabs.synthesize_with_timestamps(
                    text=text,
                    voice_id=voice_id,
                    output_format=output_format,
                )
                if not audio:
                    # Treat empty audio as a failure to keep invariants tight.
                    raise RuntimeError("ElevenLabs returned empty audio for timestamps synthesis")
                logger.info(
                    "tts_router.ok",
                    provider="elevenlabs",
                    voice_id=voice_id,
                    size=len(audio),
                    alignment="yes" if alignment else "no",
                )
                return audio, alignment, "elevenlabs"
            except TTSProviderError as e:
                logger.warning(
                    "tts_router.primary_failed",
                    provider="elevenlabs",
                    status_code=e.status_code,
                    error=str(e),
                )
                # Fallback to audio-only path
            except Exception as e:
                logger.warning("tts_router.timestamps_failed", provider="elevenlabs", error=str(e))

        # Edge primary: capture WordBoundary chunks and expand to ElevenLabs
        # char-level shape so the frontend's _charIndexAtMs path works
        # without any client change.
        if primary == "edge" and self._edge:
            try:
                audio, alignment = await self._edge_with_alignment(text, voice_id)
                return audio, alignment, "edge"
            except Exception as e:
                logger.warning("tts_router.edge.primary_failed", error=str(e))

        # Fallback chain — also captures Edge alignment when fallback is Edge.
        audio, alignment, actual_provider = await self._fallback_synthesize_with_alignment(
            primary=primary, text=text, voice_id=voice_id,
            speed=1.0, output_format=output_format,
        )
        return audio, alignment, actual_provider

    async def _edge_with_alignment(
        self, text: str, voice_id: str
    ) -> tuple[bytes, dict[str, Any]]:
        from psitta.providers.edge_alignment import expand

        audio, boundaries = await self._edge.synthesize_with_timestamps(
            text=text,
            voice_id=voice_id,
        )
        alignment = expand(text, boundaries)
        logger.info(
            "tts_router.ok",
            provider="edge",
            voice_id=voice_id,
            size=len(audio),
            boundaries=len(boundaries),
            alignment="yes",
        )
        return audio, alignment

    async def _fallback_synthesize_with_alignment(
        self,
        primary: str,
        text: str,
        voice_id: str,
        speed: float,
        output_format: str,
    ) -> tuple[bytes, dict[str, Any] | None, str]:
        # Edge is preferred over the named TTS_FALLBACK because Edge is the
        # only fallback today that produces character-level alignment
        # (commit 7050182). The configured TTS_FALLBACK (Azure by default)
        # is the second-tier backstop for when Edge itself is unavailable.
        if primary != "edge" and self._edge:
            try:
                logger.info("tts_router.fallback", from_provider=primary, to_provider="edge")
                audio, alignment = await self._edge_with_alignment(text, voice_id)
                return audio, alignment, "edge"
            except Exception as e:
                logger.warning("tts_router.edge_failed", error=str(e))

        fallback = self._fallback_selected
        if fallback and fallback != "edge":
            provider = self._get_provider(fallback)
            if provider:
                try:
                    logger.info("tts_router.fallback", from_provider=primary, to_provider=fallback)
                    audio = await self._synthesize_with_provider(
                        provider=fallback,
                        text=text,
                        voice_id=voice_id,
                        speed=speed,
                        output_format=output_format,
                    )
                    return audio, None, fallback
                except Exception as e:
                    logger.warning("tts_router.fallback_failed", provider=fallback, error=str(e))

        raise RuntimeError(f"TTS failed: no fallback available (primary={primary})")

    async def _fallback_synthesize(
        self,
        primary: str,
        text: str,
        voice_id: str,
        speed: float,
        output_format: str,
    ) -> tuple[bytes, str]:
        # Mirror of _fallback_synthesize_with_alignment: Edge first, named
        # TTS_FALLBACK second. Audio-only path stays consistent with the
        # alignment path so the fallback chain a user observes is identical
        # whether they hit /audio or /alignment first.
        if primary != "edge" and self._edge:
            try:
                logger.info("tts_router.fallback", from_provider=primary, to_provider="edge")
                audio = await self._synthesize_with_provider(
                    provider="edge",
                    text=text,
                    voice_id=voice_id,
                    speed=speed,
                    output_format=output_format,
                )
                return audio, "edge"
            except Exception as e:
                logger.warning("tts_router.edge_failed", error=str(e))

        fallback = self._fallback_selected
        if fallback and fallback != "edge":
            provider = self._get_provider(fallback)
            if provider:
                try:
                    logger.info("tts_router.fallback", from_provider=primary, to_provider=fallback)
                    audio = await self._synthesize_with_provider(
                        provider=fallback,
                        text=text,
                        voice_id=voice_id,
                        speed=speed,
                        output_format=output_format,
                    )
                    return audio, fallback
                except Exception as e:
                    logger.warning("tts_router.fallback_failed", provider=fallback, error=str(e))

        raise RuntimeError(f"TTS failed: no fallback available (primary={primary})")

    async def _synthesize_with_provider(
        self,
        provider: str,
        text: str,
        voice_id: str,
        speed: float,
        output_format: str,
    ) -> bytes:
        if provider == "elevenlabs":
            audio = await self._elevenlabs.synthesize(
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
            logger.info("tts_router.ok", provider="elevenlabs", voice_id=voice_id, size=len(audio))
            return audio
        if provider == "azure":
            from psitta.models.domain import ToneCategory
            from psitta.providers.tts_router_maps import elevenlabs_to_azure

            azure_voice = elevenlabs_to_azure(voice_id)
            audio = await self._azure.synthesize(
                text=text,
                voice_id=azure_voice,
                speed=speed,
                tone=ToneCategory.NEUTRAL,
                output_format="mp3",
            )
            logger.info("tts_router.ok", provider="azure", azure_voice=azure_voice, size=len(audio))
            return audio
        if provider == "edge":
            audio = await self._edge.synthesize(
                text=text,
                voice_id=voice_id,
                speed=speed,
            )
            logger.info("tts_router.ok", provider="edge", voice_id=voice_id, size=len(audio))
            return audio
        if provider == "stub":
            return await self._stub.synthesize(text=text, voice_id=voice_id, speed=speed)
        raise RuntimeError(f"Unknown TTS provider: {provider}")

    async def health(self) -> dict:
        checks: dict[str, bool] = {}
        if self._elevenlabs:
            checks["elevenlabs"] = await self._elevenlabs.health_check()
        if self._azure:
            checks["azure"] = await self._azure.health_check()
        if self._edge:
            checks["edge"] = await self._edge.health_check()
        if self._provider_selected == "stub":
            checks["stub"] = False

        return {
            "provider_selected": self._provider_selected,
            "fallback": self._fallback_selected,
            "configured": {
                "elevenlabs": self._elevenlabs is not None,
                "azure": self._azure is not None,
                "edge": self._edge is not None,
                "stub": True,
            },
            "health": checks,
        }


class _StubTTSProvider:
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        speed: float = 1.0,
        output_format: str = "mp3_44100_128",
    ) -> bytes:
        raise RuntimeError("TTS provider is disabled (stub). Configure ELEVENLABS or AZURE.")
