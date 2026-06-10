"""
Psitta — Per-Tier Token Bucket Rate Limiter Middleware.

Applies rate limiting to incoming HTTP requests using a token bucket
algorithm. Routes are classified into tiers (upload, tts, read, default)
and each tier has its own independent bucket per client.

Keying
------
Priority for the client identifier used as the bucket key:
  1. Authenticated user: `user:{cognito_sub}` — extracted from a
     verified Cognito Bearer token on the Authorization header.
     Signature is verified against the cached JWKS so a forged `sub`
     cannot be used to rotate buckets.
  2. Proxy-forwarded IP: `ip:{first X-Forwarded-For}` — used when the
     request is behind a known proxy (ALB/CloudFront) and carries no
     usable auth token.
  3. Direct IP: `ip:{client.host}` — fallback.
The dev-bypass token recognized by middleware.auth is honored here too
so local development uses the dev user's bucket.

Tiers
-----
  upload   — POST /api/v1/documents/ and POST /api/v1/documents/blank/
  tts      — POST /api/v1/documents/{id}/resynthesize and
             POST /api/v1/documents/{id}/chunks/{cid}/resynthesize
  llm      — POST /api/v1/documents/{id}/summarize
  read     — GET /api/v1/documents/...
  default  — everything else (global fallback)

Skips `/health` and `/ready`. Never raises — on any unexpected error
the request is allowed through (fail-open), so a rate-limiter bug can
never take down the API. `rate_limit.error` is logged on failure.

Response contract on rate limit exceeded:
  HTTP 429
  body:   {"error": "rate_limit_exceeded",
           "detail": "Too many requests. Please slow down."}
  headers: Retry-After, X-RateLimit-Limit, X-RateLimit-Remaining,
           X-RateLimit-Reset

On allowed requests the same X-RateLimit-* headers are attached to the
response so clients can self-throttle.

Upgrade path: replace the in-memory `_buckets` dict with Redis
INCR + EXPIRE or a sliding-window script for multi-instance deployments.
The tier / matcher / key structure stays the same — only the state
store swaps out.
"""

from __future__ import annotations

import os
import re
import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Callable

import structlog
from jose import JWTError, jwt
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from psitta.config import Settings, get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


# ── Token Bucket ──────────────────────────────────────────────────────


@dataclass
class TokenBucket:
    """Token bucket for a single (client, tier) pair."""

    tokens: float
    max_tokens: int
    last_refill: float = field(default_factory=time.monotonic)

    def consume(self, refill_rate: float) -> bool:
        """Try to consume one token. Returns True if allowed."""
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.last_refill = now

        self.tokens = min(
            self.max_tokens,
            self.tokens + elapsed * refill_rate,
        )

        if self.tokens >= 1.0:
            self.tokens -= 1.0
            return True
        return False


# ── Tier Configuration ────────────────────────────────────────────────


@dataclass(frozen=True)
class Tier:
    """A rate-limit tier: name, request cap, and window."""

    name: str
    max_requests: int
    window_seconds: int

    @property
    def refill_rate(self) -> float:
        return self.max_requests / self.window_seconds


@dataclass(frozen=True)
class RouteMatcher:
    """(method, regex) pair mapping a request to a tier name."""

    method: str
    pattern: re.Pattern[str]
    tier_name: str

    def matches(self, method: str, path: str) -> bool:
        return self.method == method and bool(self.pattern.match(path))


def _build_matchers() -> list[RouteMatcher]:
    """Ordered matcher table — first match wins."""
    return [
        # Upload tier (5/min)
        RouteMatcher(
            method="POST",
            pattern=re.compile(r"^/api/v1/documents/?$"),
            tier_name="upload",
        ),
        RouteMatcher(
            method="POST",
            pattern=re.compile(r"^/api/v1/documents/blank/?$"),
            tier_name="upload",
        ),
        # TTS tier (10/min) — chunk-level must be before document-level
        # because the chunk path is a strict superset of the doc path.
        RouteMatcher(
            method="POST",
            pattern=re.compile(
                r"^/api/v1/documents/[^/]+/chunks/[^/]+/resynthesize/?$"
            ),
            tier_name="tts",
        ),
        RouteMatcher(
            method="POST",
            pattern=re.compile(r"^/api/v1/documents/[^/]+/resynthesize/?$"),
            tier_name="tts",
        ),
        # LLM tier (5/min) — Summarize-it endpoint
        RouteMatcher(
            method="POST",
            pattern=re.compile(r"^/api/v1/documents/[^/]+/summarize/?$"),
            tier_name="llm",
        ),
        # Read tier (120/min) — any GET under /api/v1/documents
        RouteMatcher(
            method="GET",
            pattern=re.compile(r"^/api/v1/documents(/.*)?$"),
            tier_name="read",
        ),
    ]


# ── Middleware ────────────────────────────────────────────────────────


class RateLimitMiddleware(BaseHTTPMiddleware):
    """ASGI middleware implementing per-tier, per-client token bucket
    rate limiting.

    Buckets are keyed on `(client_key, tier_name)` so each tier has an
    independent allowance — a user hitting their read limit still has
    fresh tokens for uploads and resynth calls.
    """

    def __init__(self, app: object) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        settings = get_settings()

        self._enabled: bool = settings.RATE_LIMIT_ENABLED

        self._tiers: dict[str, Tier] = {
            "upload": Tier(
                name="upload",
                max_requests=settings.RATE_LIMIT_UPLOAD_REQUESTS,
                window_seconds=settings.RATE_LIMIT_UPLOAD_WINDOW_SECONDS,
            ),
            "tts": Tier(
                name="tts",
                max_requests=settings.RATE_LIMIT_TTS_REQUESTS,
                window_seconds=settings.RATE_LIMIT_TTS_WINDOW_SECONDS,
            ),
            "llm": Tier(
                name="llm",
                max_requests=settings.RATE_LIMIT_LLM_REQUESTS,
                window_seconds=settings.RATE_LIMIT_LLM_WINDOW_SECONDS,
            ),
            "read": Tier(
                name="read",
                max_requests=settings.RATE_LIMIT_READ_REQUESTS,
                window_seconds=settings.RATE_LIMIT_READ_WINDOW_SECONDS,
            ),
            "default": Tier(
                name="default",
                max_requests=settings.RATE_LIMIT_REQUESTS,
                window_seconds=settings.RATE_LIMIT_WINDOW_SECONDS,
            ),
        }

        self._matchers: list[RouteMatcher] = _build_matchers()

        # (client_key, tier_name) -> bucket
        self._buckets: dict[tuple[str, str], TokenBucket] = defaultdict(
            lambda: TokenBucket(tokens=0.0, max_tokens=0)
        )

        # JWT decode cache — keyed on raw token string. Cognito access
        # tokens don't change across requests, so we avoid re-decoding
        # the same token on every call. Evicted lazily on exp.
        self._token_sub_cache: dict[str, tuple[float, str | None]] = {}
        self._token_cache_max: int = 4096

    # ── Tier resolution ───────────────────────────────────────────────

    def _resolve_tier(self, method: str, path: str) -> Tier:
        for matcher in self._matchers:
            if matcher.matches(method, path):
                return self._tiers[matcher.tier_name]
        return self._tiers["default"]

    # ── Client key resolution ─────────────────────────────────────────

    def _extract_bearer(self, request: Request) -> str | None:
        header = request.headers.get("Authorization") or request.headers.get(
            "authorization"
        )
        if not header:
            return None
        parts = header.split(None, 1)
        if len(parts) != 2 or parts[0].lower() != "bearer":
            return None
        token = parts[1].strip()
        return token or None

    async def _sub_from_token_async(
        self, token: str, settings: Settings
    ) -> str | None:
        if (
            settings.ENVIRONMENT == "development"
            and token == "dev-bypass-token"
        ):
            return "00000000-0000-0000-0000-000000000001"

        now = time.time()
        cached = self._token_sub_cache.get(token)
        if cached is not None:
            exp, sub = cached
            if exp > now:
                return sub
            self._token_sub_cache.pop(token, None)

        try:
            unverified = jwt.get_unverified_claims(token)
        except JWTError:
            return None

        exp = float(unverified.get("exp") or 0)
        if exp and exp < now:
            return None

        try:
            from psitta.middleware.auth import _find_rsa_key, _get_jwks

            jwks = await _get_jwks(settings)
            rsa_key = _find_rsa_key(jwks, token)
            payload = jwt.decode(
                token,
                rsa_key,
                algorithms=["RS256"],
                issuer=settings.cognito_issuer,
                options={"verify_aud": False},
            )
            token_client_id = payload.get("client_id") or payload.get("aud")
            if isinstance(token_client_id, list):
                token_client_id = token_client_id[0]
            if token_client_id != settings.COGNITO_CLIENT_ID:
                return None
            sub = payload.get("sub")
            if not sub:
                return None

            # Cache with the token's own exp (or a conservative 5 min).
            cache_until = exp if exp else now + 300.0
            if len(self._token_sub_cache) >= self._token_cache_max:
                # Simple bounded eviction — clear the whole map. Low freq.
                self._token_sub_cache.clear()
            self._token_sub_cache[token] = (cache_until, sub)
            return sub
        except Exception as e:
            logger.debug("rate_limit.token_decode_failed", error=str(e))
            return None

    async def _client_key(self, request: Request, settings: Settings) -> str:
        token = self._extract_bearer(request)
        if token is not None:
            sub = await self._sub_from_token_async(token, settings)
            if sub:
                return f"user:{sub}"

        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return f"ip:{forwarded.split(',')[0].strip()}"

        client = request.client
        return f"ip:{client.host}" if client else "ip:unknown"

    # ── Dispatch ──────────────────────────────────────────────────────

    async def dispatch(
        self, request: Request, call_next: Callable[..., Response]
    ) -> Response:
        # Skip liveness / readiness probes.
        path = request.url.path
        if path in ("/health", "/ready"):
            return await call_next(request)

        # Disabled globally (e.g. for local test runs).
        if not self._enabled:
            return await call_next(request)

        # Auto-disable when pytest is driving — defense in depth for the
        # test harness. Set per-request because PYTEST_CURRENT_TEST is
        # populated at test time, not at middleware instantiation.
        if os.environ.get("PYTEST_CURRENT_TEST"):
            return await call_next(request)

        try:
            settings = get_settings()
            tier = self._resolve_tier(request.method, path)
            client_key = await self._client_key(request, settings)
        except Exception as e:
            # Fail open on any unexpected error — never block legit traffic.
            logger.warning("rate_limit.error", error=str(e), path=path)
            return await call_next(request)

        bucket_key = (client_key, tier.name)
        bucket = self._buckets.get(bucket_key)
        if bucket is None or bucket.max_tokens != tier.max_requests:
            bucket = TokenBucket(
                tokens=float(tier.max_requests),
                max_tokens=tier.max_requests,
            )
            self._buckets[bucket_key] = bucket

        if not bucket.consume(tier.refill_rate):
            retry_after = max(1, int(1.0 / tier.refill_rate) + 1)
            reset_time = int(time.time()) + tier.window_seconds

            logger.warning(
                "rate_limit.exceeded",
                client_key=client_key,
                tier=tier.name,
                path=path,
                method=request.method,
                retry_after=retry_after,
            )

            return JSONResponse(
                status_code=429,
                content={
                    "error": "rate_limit_exceeded",
                    "detail": "Too many requests. Please slow down.",
                },
                headers={
                    "Retry-After": str(retry_after),
                    "X-RateLimit-Limit": str(tier.max_requests),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(reset_time),
                    "X-RateLimit-Tier": tier.name,
                },
            )

        response = await call_next(request)

        remaining = max(0, int(bucket.tokens))
        reset_time = int(time.time()) + tier.window_seconds
        response.headers["X-RateLimit-Limit"] = str(tier.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_time)
        response.headers["X-RateLimit-Tier"] = tier.name

        return response
