"""
Dependency injection and provider initialization.

All providers are registered at startup and injected via FastAPI dependencies.
"""

from __future__ import annotations

from typing import Annotated

import structlog
from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from psitta.config import Settings, get_settings
from psitta.db.session import get_db_session
from psitta.providers.interfaces.contracts import (
    ProviderRegistry,
    registry,
)

logger = structlog.get_logger()


async def setup_providers(settings: Settings) -> None:
    """
    Initialize and register all providers at application startup.

    Core providers are always registered.
    Extension providers are loaded dynamically if available.
    """
    # Import core implementations (lazy to avoid circular imports)
    from psitta.providers.storage_s3 import S3StorageProvider
    from psitta.providers.tts_azure import AzureTTSProvider
    from psitta.providers.voice_catalog_static import StaticVoiceCatalogProvider
    from psitta.providers.tone_rule_based import RuleBasedToneClassifier

    # ── Core providers (always available) ────────────────────────
    registry.register_storage(
        S3StorageProvider(
            endpoint_url=settings.s3_endpoint_url,
            bucket_name=settings.s3_bucket_name,
            region=settings.s3_region,
            access_key_id=settings.s3_access_key_id,
            secret_access_key=settings.s3_secret_access_key,
        )
    )
    logger.info("provider_registered", provider="storage", impl="s3")

    registry.register_tts(
        AzureTTSProvider(
            key=settings.azure_tts_key,
            region=settings.azure_tts_region,
        )
    )
    logger.info("provider_registered", provider="tts", impl="azure")

    registry.register_voice_catalog(StaticVoiceCatalogProvider())
    logger.info("provider_registered", provider="voice_catalog", impl="static")

    registry.register_tone_classifier(RuleBasedToneClassifier())
    logger.info("provider_registered", provider="tone_classifier", impl="rule_based")

    # ── Extension providers (loaded if configured) ───────────────
    _load_extension_providers(settings)


def _load_extension_providers(settings: Settings) -> None:
    """Attempt to load extension providers if available."""
    # ElevenLabs premium voices
    if settings.elevenlabs_api_key:
        try:
            from psitta_extensions.premium_voices import ElevenLabsTTSProvider  # type: ignore[import-untyped]

            registry.register_tts(
                ElevenLabsTTSProvider(api_key=settings.elevenlabs_api_key)
            )
            logger.info("extension_loaded", extension="premium_voices", provider="elevenlabs")
        except ImportError:
            logger.debug("extension_not_available", extension="premium_voices")

    # Vision description
    if settings.anthropic_api_key:
        try:
            from psitta.providers.vision_anthropic import AnthropicVisionProvider

            registry.register_vision(
                AnthropicVisionProvider(api_key=settings.anthropic_api_key)
            )
            logger.info("provider_registered", provider="vision", impl="anthropic")
        except ImportError:
            logger.warning("vision_provider_not_available", impl="anthropic")


# ── FastAPI Dependencies ─────────────────────────────────────────────


def get_registry() -> ProviderRegistry:
    """Get the provider registry singleton."""
    return registry


def get_current_user_id(request: Request) -> str:
    """
    Extract and validate the authenticated user ID from the request.

    In production, this verifies the JWT via the AuthProvider.
    For development, accepts a header-based user ID.
    """
    settings = get_settings()

    if not settings.is_production:
        # Development mode: accept X-Dev-User-ID header
        dev_user_id = request.headers.get("X-Dev-User-ID")
        if dev_user_id:
            return dev_user_id

    # Production: verify JWT
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Token verification would be handled by AuthProvider
    # For now, this is the interface — concrete impl in provider
    token = auth_header.removeprefix("Bearer ")
    # TODO: registry.auth.verify_token(token)
    # Return user external_id from claims
    return token  # Placeholder


# Type aliases for cleaner dependency injection
DbSession = Annotated[AsyncSession, Depends(get_db_session)]
Providers = Annotated[ProviderRegistry, Depends(get_registry)]
CurrentUserId = Annotated[str, Depends(get_current_user_id)]
