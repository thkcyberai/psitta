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

from pydantic import SecretStr
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
    ENVIRONMENT: Literal["development", "staging", "production", "testing"] = "development"
    APP_VERSION: str = "0.1.0"
    LOG_LEVEL: Literal["debug", "info", "warning", "error", "critical"] = "info"
    SECRET_KEY: SecretStr = SecretStr("CHANGE-ME-TO-RANDOM-64-CHAR-STRING")

    # ── API Server ─────────────────────────────────────────────────────
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_WORKERS: int = 1
    ALLOWED_ORIGINS: str = (
        "http://localhost:3000,http://localhost:8080,"
        "https://psitta.ai,https://www.psitta.ai"
    )

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
    AZURE_TTS_KEY: SecretStr = SecretStr("")
    AZURE_TTS_REGION: str = "centralus"

    # ── Vision Provider ────────────────────────────────────────────────
    VISION_PROVIDER: Literal["anthropic", "stub"] = "stub"
    ANTHROPIC_API_KEY: SecretStr = SecretStr("")

    # ── LLM Provider (Summarize-it WD-B1) ─────────────────────────────
    OPENAI_API_KEY: SecretStr = SecretStr("")
    OPENAI_SUMMARIZE_MODEL: str = "gpt-4.1-mini"

    # ── Amazon Cognito ─────────────────────────────────────────────────
    COGNITO_USER_POOL_ID: str = ""
    COGNITO_CLIENT_ID: str = ""
    COGNITO_REGION: str = "us-east-1"

    # ── Computed: Cognito URLs ─────────────────────────────────────────
    @property
    def cognito_issuer(self) -> str:
        """Cognito JWT issuer URL."""
        return (
            f"https://cognito-idp.{self.COGNITO_REGION}.amazonaws.com"
            f"/{self.COGNITO_USER_POOL_ID}"
        )

    @property
    def cognito_jwks_url(self) -> str:
        """Cognito JWKS endpoint for RS256 JWT validation."""
        return f"{self.cognito_issuer}/.well-known/jwks.json"

    # ── Stripe (M3 Billing) ──────────────────────────────────────────
    STRIPE_SECRET_KEY_TEST: SecretStr = SecretStr("")
    STRIPE_PUBLISHABLE_KEY_TEST: str = ""
    STRIPE_WEBHOOK_SECRET: SecretStr = SecretStr("")

    # ── Reverse-trial funnel (Phase 1) ───────────────────────────────
    # On genuine new-user signup, grant full Writing Nook for a fixed
    # window, then lazy-downgrade to Free (no cron — the resolver drops
    # the trial when expires_at passes, mirroring tester_allowlist).
    #
    # A4 (2026-07-20): DISABLED BY DEFAULT. The Stripe-native 14-day
    # Checkout trial (billing.TRIAL_PERIOD_DAYS) is now the single
    # trial source of truth — leaving both on would hand every new
    # writer 14 signup days PLUS 14 checkout days. Existing trial_grants
    # rows stay honored by the resolver until they lazily expire.
    # Setting REVERSE_TRIAL_ENABLED=true in the environment re-enables
    # signup grants (deliberate override only). ⚠ Operator: verify the
    # ECS task definition does NOT export REVERSE_TRIAL_ENABLED=true,
    # which would silently override this default.
    REVERSE_TRIAL_ENABLED: bool = False
    REVERSE_TRIAL_DAYS: int = 14
    REVERSE_TRIAL_PLAN_ID: str = "writing_nook_pro"

    # ── Loops.so (GTM funnel lifecycle emails) ─────────────────────────
    # Backend posts lifecycle events (signup, activated, trial_3_days_left,
    # trial_ended, subscribed) to Loops, which fires the matching email
    # sequence. Ships OFF: emission is a no-op until LOOPS_EVENTS_ENABLED
    # is true AND LOOPS_API_KEY is set (both via env/secret). Every emit is
    # best-effort and can never break the request that triggers it.
    LOOPS_EVENTS_ENABLED: bool = False
    LOOPS_API_KEY: str = ""

    # ── Rate Limiting ──────────────────────────────────────────────────
    # Global fallback tier — applies to any route that doesn't match a
    # specific tier below (PATCH, DELETE, cover upload, non-/documents
    # paths, etc.). Also used for unauthenticated requests keyed by IP.
    RATE_LIMIT_ENABLED: bool = True
    RATE_LIMIT_REQUESTS: int = 100
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    # Per-tier limits for high-cost document endpoints. Keys are per
    # authenticated user (Cognito sub) when a valid Bearer token is
    # present, else per client IP. See middleware/rate_limit.py for
    # the exact route matchers.
    RATE_LIMIT_UPLOAD_REQUESTS: int = 5           # POST /documents/, POST /documents/blank/
    RATE_LIMIT_UPLOAD_WINDOW_SECONDS: int = 60
    RATE_LIMIT_TTS_REQUESTS: int = 10             # POST /documents/{id}[/chunks/{id}]/resynthesize
    RATE_LIMIT_TTS_WINDOW_SECONDS: int = 60
    RATE_LIMIT_READ_REQUESTS: int = 120           # GET /documents/...
    RATE_LIMIT_READ_WINDOW_SECONDS: int = 60
    RATE_LIMIT_LLM_REQUESTS: int = 5             # POST /documents/{id}/summarize
    RATE_LIMIT_LLM_WINDOW_SECONDS: int = 60

    # ── Document Processing ────────────────────────────────────────────
    MAX_DOCUMENT_SIZE_MB: int = 50
    MAX_DOCUMENT_PAGES: int = 500
    DOCUMENT_TTL_DAYS: int = 60

    # ── Computed: Database URLs ────────────────────────────────────────
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

    def check_production_readiness(self) -> list[str]:
        """Return a list of configuration warnings for production."""
        warnings: list[str] = []
        if self.SECRET_KEY.get_secret_value() == "CHANGE-ME-TO-RANDOM-64-CHAR-STRING":
            warnings.append("SECRET_KEY is still the default — set a secure random value")
        if self.POSTGRES_PASSWORD.get_secret_value() == "psitta_dev_password":
            warnings.append("POSTGRES_PASSWORD is still the dev default")
        if not self.COGNITO_USER_POOL_ID:
            warnings.append("COGNITO_USER_POOL_ID is not set")
        if not self.COGNITO_CLIENT_ID:
            warnings.append("COGNITO_CLIENT_ID is not set")
        if self.ENVIRONMENT == "production" and self.LOG_LEVEL == "debug":
            warnings.append("LOG_LEVEL=debug in production")
        if self.ENVIRONMENT == "production" and "localhost" in self.ALLOWED_ORIGINS:
            warnings.append("ALLOWED_ORIGINS contains localhost in production")
        return warnings


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Cached singleton — settings are loaded once and reused."""
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
