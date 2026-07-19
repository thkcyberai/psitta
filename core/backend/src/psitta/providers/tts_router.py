"""Psitta - TTS Provider Router with Failover."""

from __future__ import annotations

import time
from functools import lru_cache

import structlog
from typing import Any, AsyncIterator
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import Settings, get_settings
from psitta.providers.tts_errors import TTSProviderError
from psitta.providers.tts_router_maps import elevenlabs_to_azure

logger = structlog.get_logger(__name__)


@lru_cache(maxsize=None)
def _voice_provider(voice_id: str) -> str:
    """Resolve voice_id → catalog provider field. Returns 'elevenlabs',
    'azure', or 'unknown'. Cached per-process per-id; catalog is static
    so the lookup happens once per voice. Returning 'unknown' falls
    through to the legacy EL-primary path so any voice missing from the
    catalog (e.g., during a deploy where catalog and code are temporarily
    out of sync) preserves prior behavior."""
    from psitta.providers.voice_catalog_static import VOICE_CATALOG
    for v in VOICE_CATALOG:
        if v["id"] == voice_id:
            return v.get("provider", "unknown")
    return "unknown"


# ── ElevenLabs circuit breaker (TTS Perfection F1) ──────────────────────────
# When ElevenLabs fails (provider-side credit exhaustion, outage, timeout),
# every sentence-level synthesis still paid a doomed EL attempt before falling
# back to Edge — a per-sentence latency tax measured at seconds in QA. The
# breaker remembers the failure for a bounded cooldown and routes straight to
# the existing fallback chain. It FAILS OPEN: once the cooldown elapses the
# next request attempts ElevenLabs normally and, on success, closes the
# breaker. Module-level so it spans the per-request TTSRouter instances; a
# process restart naturally resets it. Entitlement, billing and quota
# semantics are untouched — the breaker only skips a call that was about to
# fail, and EL usage is still incremented only when EL actually serves.
_EL_BREAKER_COOLDOWN_SECONDS = 120.0
_el_breaker_open_until = 0.0
_el_breaker_last_reason = ""


def _el_breaker_should_skip(context: str) -> bool:
    """True while the breaker is open (logs the bypass). When a previous
    open period has elapsed, logs the retry and lets the request through."""
    now = time.monotonic()
    if now < _el_breaker_open_until:
        logger.info(
            "tts_router.el_breaker_bypass",
            context=context,
            remaining_seconds=round(_el_breaker_open_until - now, 1),
            reason=_el_breaker_last_reason,
        )
        return True
    if _el_breaker_open_until:
        # Cooldown elapsed — fail open: this request retries ElevenLabs.
        logger.info("tts_router.el_breaker_retry", context=context)
    return False


def _el_breaker_trip(reason: str) -> None:
    global _el_breaker_open_until, _el_breaker_last_reason
    _el_breaker_open_until = time.monotonic() + _EL_BREAKER_COOLDOWN_SECONDS
    _el_breaker_last_reason = reason[:200]
    logger.warning(
        "tts_router.el_breaker_open",
        cooldown_seconds=_EL_BREAKER_COOLDOWN_SECONDS,
        reason=_el_breaker_last_reason,
    )


def _el_breaker_note_success() -> None:
    global _el_breaker_open_until, _el_breaker_last_reason
    if _el_breaker_open_until:
        _el_breaker_open_until = 0.0
        logger.info(
            "tts_router.el_breaker_closed",
            recovered_from=_el_breaker_last_reason,
        )
        _el_breaker_last_reason = ""


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
    ) -> tuple[bytes, str]:
        """Synthesize text with provider selection + failover.

        Returns (audio_bytes, provider_name). provider_name lets callers
        attribute char usage to the actual serving provider — only EL
        counts against the per-period char quota (C.2).
        """
        if _voice_provider(voice_id) == "azure":
            return await self._dispatch_azure_voice(
                text=text, voice_id=voice_id, speed=speed,
                output_format=output_format,
            )
        primary = self._provider_selected
        provider = self._get_provider(primary)
        if provider is None:
            raise RuntimeError(f"No TTS provider configured (selected={primary})")

        # F1: while the EL breaker is open, skip the doomed attempt entirely.
        if primary == "elevenlabs" and _el_breaker_should_skip("synthesize"):
            return await self._fallback_synthesize(
                primary=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )

        try:
            audio = await self._synthesize_with_provider(
                provider=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
            if primary == "elevenlabs":
                _el_breaker_note_success()
            return audio, primary
        except TTSProviderError as e:
            if primary == "elevenlabs":
                _el_breaker_trip(f"synthesize:{e.status_code}:{e}")
            logger.warning(
                "tts_router.primary_failed",
                provider=primary,
                status_code=e.status_code,
                error=str(e),
            )
            return await self._fallback_synthesize(
                primary=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )

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
        if _voice_provider(voice_id) == "azure":
            return await self._dispatch_azure_voice_with_alignment(
                text=text, voice_id=voice_id, output_format=output_format,
            )
        primary = self._provider_selected
        provider = self._get_provider(primary)
        if provider is None:
            raise RuntimeError(f"No TTS provider configured (selected={primary})")

        if (
            primary == "elevenlabs"
            and self._elevenlabs
            # F1: while the EL breaker is open, skip the doomed attempt and
            # fall straight through to the alignment-aware fallback chain.
            and not _el_breaker_should_skip("with_alignment")
        ):
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
                    char_count=len(text),
                    alignment="yes" if alignment else "no",
                )
                _el_breaker_note_success()
                return audio, alignment, "elevenlabs"
            except TTSProviderError as e:
                _el_breaker_trip(f"with_alignment:{e.status_code}:{e}")
                logger.warning(
                    "tts_router.primary_failed",
                    provider="elevenlabs",
                    status_code=e.status_code,
                    error=str(e),
                )
                # Fallback to audio-only path
            except Exception as e:
                _el_breaker_trip(f"with_alignment:{e}")
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

    async def synthesize_with_quota(
        self,
        text: str,
        voice_id: str,
        user_id: UUID,
        db: AsyncSession,
        speed: float = 1.0,
        output_format: str = "mp3_44100_128",
    ) -> tuple[bytes, str]:
        """synthesize() wrapped with per-user EL char-quota enforcement.

        Pre-call: read (used, limit, period_start) from el_usage_counters
        + plan_limits. If used >= limit AND limit > 0 (i.e. plan grants
        EL access but cap reached), skip the EL primary and fall straight
        through to the Edge-first fallback chain. Audio always plays —
        the quota path is a graceful degrade, never a 402.

        Post-call: when EL actually served the request and the plan has
        a non-zero limit, increment the counter by len(text). EL bills
        by request character count, so len(text) is the canonical bill.
        """
        # Lazy imports — avoid circular risk if subscription_service ever
        # grows a TTS dependency.
        from psitta.services.plan_limits import _normalize_plan_id
        from psitta.services.subscription_service import (
            _get_active_plan_id,
            check_el_quota,
            increment_el_chars,
        )

        used, limit, period_start = await check_el_quota(db, user_id)
        char_count = len(text)
        primary = self._provider_selected

        if limit > 0 and used >= limit and primary == "elevenlabs":
            raw_plan_id = await _get_active_plan_id(db, user_id)
            plan = _normalize_plan_id(raw_plan_id)
            logger.info(
                "tts_router.quota_exhausted_fallback",
                user_id=str(user_id),
                plan=plan,
                used=used,
                limit=limit,
                period_start=period_start.isoformat() if period_start else None,
                char_count=char_count,
            )
            audio, provider_name = await self._fallback_synthesize(
                primary=primary,
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
            return audio, provider_name

        audio, provider_name = await self.synthesize(
            text=text,
            voice_id=voice_id,
            speed=speed,
            output_format=output_format,
        )
        if provider_name == "elevenlabs" and limit > 0:
            await increment_el_chars(db, user_id, period_start, char_count)
        return audio, provider_name

    async def synthesize_with_alignment_and_quota(
        self,
        text: str,
        voice_id: str,
        user_id: UUID,
        db: AsyncSession,
        output_format: str = "mp3_44100_128",
    ) -> tuple[bytes, dict[str, Any] | None, str]:
        """synthesize_with_alignment() wrapped with EL char-quota enforcement.

        Mirrors synthesize_with_quota but preserves the alignment payload
        produced by ElevenLabs (/with-timestamps) or Edge (WordBoundary
        events). When the EL quota is exhausted the call is forced into
        the alignment-aware fallback path which keeps Edge's char-level
        alignment available for SWH.
        """
        from psitta.services.plan_limits import _normalize_plan_id
        from psitta.services.subscription_service import (
            _get_active_plan_id,
            check_el_quota,
            increment_el_chars,
        )

        used, limit, period_start = await check_el_quota(db, user_id)
        char_count = len(text)
        primary = self._provider_selected

        if limit > 0 and used >= limit and primary == "elevenlabs":
            raw_plan_id = await _get_active_plan_id(db, user_id)
            plan = _normalize_plan_id(raw_plan_id)
            logger.info(
                "tts_router.quota_exhausted_fallback",
                user_id=str(user_id),
                plan=plan,
                used=used,
                limit=limit,
                period_start=period_start.isoformat() if period_start else None,
                char_count=char_count,
                with_alignment=True,
            )
            audio, alignment, provider_name = await self._fallback_synthesize_with_alignment(
                primary=primary,
                text=text,
                voice_id=voice_id,
                speed=1.0,
                output_format=output_format,
            )
            return audio, alignment, provider_name

        audio, alignment, provider_name = await self.synthesize_with_alignment(
            text=text,
            voice_id=voice_id,
            output_format=output_format,
        )
        if provider_name == "elevenlabs" and limit > 0:
            await increment_el_chars(db, user_id, period_start, char_count)
        return audio, alignment, provider_name

    async def stream_with_alignment(
        self,
        text: str,
        voice_id: str,
        *,
        allow_elevenlabs: bool,
        output_format: str = "mp3_44100_128",
    ) -> AsyncIterator[dict[str, Any]]:
        """Pure streaming source (NO database access).

        Yields audio as the model generates it, then exactly one final
        alignment event:
          {"type": "audio", "data": <bytes>}
          {"type": "alignment", "data": <dict|None>, "provider": <str>}

        The caller (the Writing-Nook streaming endpoint) is responsible for the
        EL-quota check (to set [allow_elevenlabs]), the post-stream char-count
        increment, and the cache write-through — all with a session whose
        lifetime spans the streamed response. Keeping DB work out of here avoids
        using a request-scoped session after it has been torn down.

        When [allow_elevenlabs] is false (quota exhausted) or the voice's
        primary provider is not ElevenLabs, this falls back to the
        alignment-aware Edge/Azure path (buffered, then re-chunked) so the
        endpoint behaves identically and never silently bills ElevenLabs.
        """
        primary = self._provider_selected
        if allow_elevenlabs and self._elevenlabs is not None and primary == "elevenlabs":
            async for ev in self._elevenlabs.stream_with_timestamps(
                text, voice_id, output_format=output_format
            ):
                if ev.get("type") == "alignment":
                    yield {**ev, "provider": "elevenlabs"}
                else:
                    yield ev
            return

        # Fallback: Edge-first alignment-aware synthesis (no ElevenLabs), then
        # re-chunk the buffered audio so the wire behaviour matches streaming.
        audio, alignment, provider_name = await self._fallback_synthesize_with_alignment(
            primary=primary,
            text=text,
            voice_id=voice_id,
            speed=1.0,
            output_format=output_format,
        )
        step = 16384
        for i in range(0, len(audio), step):
            yield {"type": "audio", "data": audio[i : i + step]}
        yield {"type": "alignment", "data": alignment, "provider": provider_name}

    async def _dispatch_azure_voice(
        self,
        text: str,
        voice_id: str,
        speed: float,
        output_format: str,
    ) -> tuple[bytes, str]:
        """Edge-first dispatch for catalog provider=azure voices.

        For native Microsoft voice IDs (e.g., 'en-US-AriaNeural'), the
        catalog id IS the Edge/Azure voice id — no translation required.
        Bypasses the elevenlabs_to_azure() translator's broken
        'unknown→Jenny' fallback. ElevenLabs is intentionally NOT in the
        chain for these voices: their ids are not valid at EL and would
        always 4xx, wasting a round trip and consuming EL rate budget.
        """
        if self._edge:
            try:
                audio = await self._edge.synthesize(
                    text=text, voice_id=voice_id, speed=speed,
                    output_format=output_format,
                )
                logger.info(
                    "tts_router.ok",
                    provider="edge", voice_id=voice_id,
                    size=len(audio), char_count=len(text),
                    dispatch="azure_voice",
                )
                return audio, "edge"
            except Exception as e:
                logger.warning(
                    "tts_router.azure_voice.edge_failed",
                    voice_id=voice_id, error=str(e),
                )
        if self._azure:
            try:
                from psitta.models.domain import ToneCategory
                audio = await self._azure.synthesize(
                    text=text, voice_id=voice_id, speed=speed,
                    tone=ToneCategory.NEUTRAL, output_format="mp3",
                )
                logger.info(
                    "tts_router.ok",
                    provider="azure", voice_id=voice_id,
                    size=len(audio), char_count=len(text),
                    dispatch="azure_voice",
                )
                return audio, "azure"
            except Exception as e:
                logger.warning(
                    "tts_router.azure_voice.azure_failed",
                    voice_id=voice_id, error=str(e),
                )
        raise RuntimeError(
            f"TTS failed for azure voice {voice_id}: "
            "Edge and Azure both unavailable"
        )

    async def _dispatch_azure_voice_with_alignment(
        self,
        text: str,
        voice_id: str,
        output_format: str,
    ) -> tuple[bytes, dict[str, Any] | None, str]:
        """Edge-first dispatch with alignment for provider=azure voices.

        Edge produces char-level alignment via WordBoundary expansion;
        Azure cannot, so the Azure failover returns alignment=None.
        """
        if self._edge:
            try:
                audio, alignment = await self._edge_with_alignment(
                    text, voice_id,
                )
                return audio, alignment, "edge"
            except Exception as e:
                logger.warning(
                    "tts_router.azure_voice.edge_failed",
                    voice_id=voice_id, error=str(e),
                )
        if self._azure:
            try:
                from psitta.models.domain import ToneCategory
                audio = await self._azure.synthesize(
                    text=text, voice_id=voice_id, speed=1.0,
                    tone=ToneCategory.NEUTRAL, output_format="mp3",
                )
                logger.info(
                    "tts_router.ok",
                    provider="azure", voice_id=voice_id,
                    size=len(audio), char_count=len(text),
                    alignment="no", dispatch="azure_voice",
                )
                return audio, None, "azure"
            except Exception as e:
                logger.warning(
                    "tts_router.azure_voice.azure_failed",
                    voice_id=voice_id, error=str(e),
                )
        raise RuntimeError(
            f"TTS failed for azure voice {voice_id}: "
            "Edge and Azure both unavailable"
        )

    async def _edge_with_alignment(
        self, text: str, voice_id: str
    ) -> tuple[bytes, dict[str, Any]]:
        from psitta.providers.edge_alignment import expand

        # Translate the requested voice to a catalog-verified Microsoft Neural
        # voice of the SAME language + gender. Without this, an ElevenLabs voice
        # id falling back to Edge (or any id outside Edge's 12-voice legacy map)
        # silently becomes en-US-JennyNeural — wrong language and gender on the
        # fallback clips. Native Microsoft ids pass through unchanged, so this is
        # a no-op on the Edge-primary and azure-voice paths.
        edge_voice_id = elevenlabs_to_azure(voice_id)
        audio, boundaries = await self._edge.synthesize_with_timestamps(
            text=text,
            voice_id=edge_voice_id,
        )
        alignment = expand(text, boundaries)
        logger.info(
            "tts_router.ok",
            provider="edge",
            voice_id=voice_id,
            edge_voice_id=edge_voice_id,
            size=len(audio),
            char_count=len(text),
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
        char_count = len(text)
        if provider == "elevenlabs":
            audio = await self._elevenlabs.synthesize(
                text=text,
                voice_id=voice_id,
                speed=speed,
                output_format=output_format,
            )
            logger.info(
                "tts_router.ok",
                provider="elevenlabs",
                voice_id=voice_id,
                size=len(audio),
                char_count=char_count,
            )
            return audio
        if provider == "azure":
            from psitta.models.domain import ToneCategory

            azure_voice = elevenlabs_to_azure(voice_id)
            audio = await self._azure.synthesize(
                text=text,
                voice_id=azure_voice,
                speed=speed,
                tone=ToneCategory.NEUTRAL,
                output_format="mp3",
            )
            logger.info(
                "tts_router.ok",
                provider="azure",
                azure_voice=azure_voice,
                size=len(audio),
                char_count=char_count,
            )
            return audio
        if provider == "edge":
            # Same-language/gender translation as the alignment path — keeps
            # audio-only fallback clips on the correct voice instead of Jenny.
            # Native Microsoft ids pass through unchanged (no-op for Edge
            # primary / azure voices).
            edge_voice_id = elevenlabs_to_azure(voice_id)
            audio = await self._edge.synthesize(
                text=text,
                voice_id=edge_voice_id,
                speed=speed,
            )
            logger.info(
                "tts_router.ok",
                provider="edge",
                voice_id=voice_id,
                edge_voice_id=edge_voice_id,
                size=len(audio),
                char_count=char_count,
            )
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
