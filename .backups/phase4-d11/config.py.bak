"""
Application configuration.

All configuration is loaded from environment variables.
No hardcoded secrets. No defaults for sensitive values.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, PostgresDsn, RedisDsn, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Immutable application settings loaded from environment."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="PSITTA_",
        case_sensitive=False,
        extra="ignore",
    )

    # ── Application ──────────────────────────────────────────────
    app_name: str = "psitta"
    app_version: str = "0.1.0"
    environment: Literal["development", "staging", "production"] = "development"
    debug: bool = False
    log_level: str = "INFO"
    allowed_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # ── Database ─────────────────────────────────────────────────
    database_url: PostgresDsn
    database_pool_size: int = Field(default=20, ge=5, le=100)
    database_max_overflow: int = Field(default=10, ge=0, le=50)
    database_echo: bool = False

    # ── Redis ────────────────────────────────────────────────────
    redis_url: RedisDsn = RedisDsn("redis://localhost:6379/0")  # type: ignore[arg-type]
    redis_cache_ttl_seconds: int = Field(default=3600, ge=60)

    # ── Object Storage (S3-compatible) ───────────────────────────
    s3_endpoint_url: str | None = None  # None = use AWS default
    s3_bucket_name: str = "psitta-dev"
    s3_region: str = "us-east-1"
    s3_access_key_id: str = ""
    s3_secret_access_key: str = ""

    # ── Authentication ───────────────────────────────────────────
    auth_issuer_url: str  # e.g., https://psitta.us.auth0.com/
    auth_audience: str  # e.g., https://api.psitta.io
    auth_algorithm: str = "RS256"
    jwt_secret_key: str  # For internal token signing (refresh, etc.)
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7

    # ── TTS Providers ────────────────────────────────────────────
    tts_default_provider: Literal["azure", "elevenlabs"] = "azure"
    azure_tts_key: str = ""
    azure_tts_region: str = "eastus"
    elevenlabs_api_key: str = ""

    # ── Vision / Description ─────────────────────────────────────
    vision_provider: Literal["anthropic", "openai"] = "anthropic"
    anthropic_api_key: str = ""
    openai_api_key: str = ""

    # ── Processing ───────────────────────────────────────────────
    max_upload_size_bytes: int = Field(default=100 * 1024 * 1024, ge=1024)  # 100 MB
    max_page_count: int = Field(default=500, ge=1)
    chunk_max_chars: int = Field(default=5000, ge=100)
    retention_days: int = Field(default=60, ge=1)

    # ── Rate Limiting ────────────────────────────────────────────
    rate_limit_requests_per_minute: int = 100
    rate_limit_uploads_per_minute: int = 10

    # ── Observability ────────────────────────────────────────────
    otel_exporter_endpoint: str = "http://localhost:4317"
    otel_service_name: str = "psitta-api"

    @computed_field  # type: ignore[prop-decorator]
    @property
    def is_production(self) -> bool:
        return self.environment == "production"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached settings singleton. Call once at startup."""
    return Settings()  # type: ignore[call-arg]
