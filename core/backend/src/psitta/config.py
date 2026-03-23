"""
Psitta — Application Configuration.

Centralized settings loaded from environment variables with validation.
Uses Pydantic Settings for type-safe configuration with .env file support.

Security: Secrets are marked with SecretStr to prevent accidental logging.
"""

from __future__ import annotations

import json
import os
from functools import lru_cache
from typing import Literal

from pydantic import AliasChoices, Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    All secrets use SecretStr to prevent leaking in logs/tracebacks.
    Defaults are safe for local development only.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # ── Application ────────────────────────────────────────────────────
    ENVIRONMENT: Literal["development", "staging", "production"] = "development"
    APP_VERSION: str = "0.1.0"
    LOG_LEVEL: Literal["debug", "info", "warning", "error", "critical"] = "info"
    SECRET_KEY: SecretStr = SecretStr("CHANGE-ME-TO-RANDOM-64-CHAR-STRING")

    # ── API Server ─────────────────────────────────────────────────────
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_WORKERS: int = 1
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # ── PostgreSQL ─────────────────────────────────────────────────────
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "psitta"
    POSTGRES_USER: str = "psitta"
    POSTGRES_PASSWORD: SecretStr = SecretStr("psitta_dev_password")
    DATABASE_POOL_SIZE: int = 10
    DATABASE_POOL_OVERFLOW: int = 5

    # ── Redis ──────────────────────────────────────────────────────────
    REDIS_HOST: str = "localhost"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: SecretStr = SecretStr("")
    REDIS_CACHE_TTL: int = 3600

    # ── S3 / MinIO ─────────────────────────────────────────────────────
    S3_ENDPOINT_URL: str = "http://localhost:9000"
    S3_BUCKET_NAME: str = "psitta-documents"
    S3_REGION: str = "us-east-1"
    AWS_ACCESS_KEY_ID: SecretStr = SecretStr("minioadmin")
    AWS_SECRET_ACCESS_KEY: SecretStr = SecretStr("minioadmin")

    # ── TTS Provider ───────────────────────────────────────────────────
    TTS_PROVIDER: Literal["auto", "elevenlabs", "azure", "edge", "stub"] = "auto"
    TTS_FALLBACK: Literal["azure", "edge", "none"] = "azure"
    ELEVENLABS_API_KEY: SecretStr = SecretStr("")
    ELEVENLABS_MODEL: str = "eleven_multilingual_v2"
    AZURE_TTS_KEY: SecretStr = Field(
        default=SecretStr(""),
        validation_alias=AliasChoices("AZURE_TTS_KEY", "SPEECH_KEY"),
    )
    AZURE_TTS_REGION: str = Field(
        default="eastus",
        validation_alias=AliasChoices("AZURE_TTS_REGION", "SPEECH_REGION"),
    )

    # ── Vision Provider ────────────────────────────────────────────────
    VISION_PROVIDER: Literal["anthropic", "stub"] = "stub"
    ANTHROPIC_API_KEY: SecretStr = SecretStr("")

    # ── Auth0 ───────────────────────────────────────────────────────────
    AUTH0_DOMAIN: str = "dev-8wmplwcxsoyhlcw1.us.auth0.com"
    AUTH0_AUDIENCE: str = "https://api.psitta.app"
    AUTH0_ALGORITHMS: str = "RS256"
    AUTH0_ISSUER: str = ""  # Computed from domain if empty

    @property
    def auth0_issuer(self) -> str:
        """Build Auth0 issuer URL from domain."""
        if self.AUTH0_ISSUER:
            return self.AUTH0_ISSUER
        return f"https://{self.AUTH0_DOMAIN}/"

    @property
    def auth0_jwks_url(self) -> str:
        """Build Auth0 JWKS endpoint URL."""
        return f"https://{self.AUTH0_DOMAIN}/.well-known/jwks.json"

    # ── Rate Limiting ──────────────────────────────────────────────────
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    # ── Document Processing ────────────────────────────────────────────
    MAX_DOCUMENT_SIZE_MB: int = 50
    MAX_DOCUMENT_PAGES: int = 500
    DOCUMENT_TTL_DAYS: int = 60

    # ── Computed Properties ────────────────────────────────────────────
    @property
    def database_url(self) -> str:
        """Build async database URL from individual components."""
        pwd = self.POSTGRES_PASSWORD.get_secret_value()
        return (
            f"postgresql+asyncpg://{self.POSTGRES_USER}:{pwd}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def database_url_sync(self) -> str:
        """Build sync database URL for Alembic migrations."""
        pwd = self.POSTGRES_PASSWORD.get_secret_value()
        return (
            f"postgresql://{self.POSTGRES_USER}:{pwd}"
            f"@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
        )

    @property
    def redis_url(self) -> str:
        """Build Redis URL from individual components."""
        pwd = self.REDIS_PASSWORD.get_secret_value()
        auth = f":{pwd}@" if pwd else ""
        return f"redis://{auth}{self.REDIS_HOST}:{self.REDIS_PORT}/0"

    @property
    def allowed_origins_list(self) -> list[str]:
        """Parse comma-separated origins into a list."""
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    # ── Validators ─────────────────────────────────────────────────────
    @field_validator("SECRET_KEY")
    @classmethod
    def secret_key_must_be_set_in_production(cls, v: SecretStr) -> SecretStr:
        """Warn if SECRET_KEY is still the default placeholder."""
        # Note: We cannot access ENVIRONMENT here (single-field validator).
        # Full validation is done in check_production_readiness().
        return v

    def check_production_readiness(self) -> list[str]:
        """Return a list of configuration warnings for production."""
        warnings: list[str] = []
        if self.SECRET_KEY.get_secret_value() == "CHANGE-ME-TO-RANDOM-64-CHAR-STRING":
            warnings.append("SECRET_KEY is still the default — set a secure random value")
        if self.POSTGRES_PASSWORD.get_secret_value() == "psitta_dev_password":
            warnings.append("POSTGRES_PASSWORD is still the dev default")
        if self.ENVIRONMENT == "production" and self.LOG_LEVEL == "debug":
            warnings.append("LOG_LEVEL=debug in production — consider 'info' or 'warning'")
        if self.ENVIRONMENT == "production" and "localhost" in self.ALLOWED_ORIGINS:
            warnings.append("ALLOWED_ORIGINS contains localhost in production")
        return warnings


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached singleton — settings are loaded once and reused.

    Call get_settings.cache_clear() in tests to reset.
    """
    raw = os.getenv("APP_SECRETS", "").strip()
    if not raw:
        return Settings()

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError("APP_SECRETS contains invalid JSON") from exc

    if not isinstance(payload, dict):
        raise RuntimeError("APP_SECRETS must decode to a JSON object")

    return Settings(**payload)
