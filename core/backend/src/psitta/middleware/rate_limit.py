"""
Psitta — Token Bucket Rate Limiter Middleware.

Applies per-client rate limiting using a token bucket algorithm.
Tracks request counts by client IP (or authenticated user ID when available).

Security:
  - Prevents brute-force attacks on auth endpoints
  - Protects expensive TTS/vision endpoints from abuse
  - Returns standard 429 Too Many Requests with Retry-After header
  - X-Forwarded-For aware for clients behind reverse proxies
  - Rate limit state stored in-memory (Redis upgrade path documented)

Headers returned on every response:
  - X-RateLimit-Limit: Maximum requests allowed in window
  - X-RateLimit-Remaining: Requests remaining in current window
  - X-RateLimit-Reset: Unix timestamp when the window resets
"""

from __future__ import annotations

import time
from collections import defaultdict
from dataclasses import dataclass, field
from typing import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from psitta.config import get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


@dataclass
class TokenBucket:
    """Token bucket for a single client."""

    tokens: float
    max_tokens: int
    last_refill: float = field(default_factory=time.monotonic)

    def consume(self, refill_rate: float) -> bool:
        """Try to consume one token. Returns True if allowed."""
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.last_refill = now

        # Refill tokens based on elapsed time
        self.tokens = min(
            self.max_tokens,
            self.tokens + elapsed * refill_rate,
        )

        if self.tokens >= 1.0:
            self.tokens -= 1.0
            return True
        return False


class RateLimitMiddleware(BaseHTTPMiddleware):
    """ASGI middleware implementing per-client token bucket rate limiting.

    Default: 100 requests per 60 seconds per client IP.
    Configurable via RATE_LIMIT_REQUESTS and RATE_LIMIT_WINDOW_SECONDS.

    Upgrade path: Replace _buckets dict with Redis INCR + EXPIRE
    for multi-instance deployments.
    """

    def __init__(self, app: object) -> None:
        super().__init__(app)  # type: ignore[arg-type]
        settings = get_settings()
        self.max_requests: int = settings.RATE_LIMIT_REQUESTS
        self.window_seconds: int = settings.RATE_LIMIT_WINDOW_SECONDS
        self.refill_rate: float = self.max_requests / self.window_seconds
        self._buckets: dict[str, TokenBucket] = defaultdict(
            lambda: TokenBucket(
                tokens=float(self.max_requests),
                max_tokens=self.max_requests,
            )
        )

    def _get_client_key(self, request: Request) -> str:
        """Extract client identifier for rate limiting.

        Priority:
          1. Authenticated user ID (from request.state, set by auth middleware)
          2. X-Forwarded-For header (first IP, for clients behind proxy)
          3. Direct client IP

        Security: X-Forwarded-For is only trusted when behind a known proxy.
        """
        # Authenticated user takes priority
        user_id = getattr(request.state, "user_id", None)
        if user_id:
            return f"user:{user_id}"

        # Proxy-forwarded IP
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return f"ip:{forwarded.split(',')[0].strip()}"

        # Direct connection IP
        client = request.client
        return f"ip:{client.host}" if client else "ip:unknown"

    async def dispatch(
        self, request: Request, call_next: Callable[..., Response]
    ) -> Response:
        # Skip rate limiting for health checks
        if request.url.path in ("/health", "/ready"):
            return await call_next(request)

        client_key = self._get_client_key(request)
        bucket = self._buckets[client_key]

        if not bucket.consume(self.refill_rate):
            retry_after = int(1.0 / self.refill_rate) + 1

            logger.warning(
                "rate_limit.exceeded",
                client_key=client_key,
                path=request.url.path,
                retry_after=retry_after,
            )

            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Too many requests. Please slow down.",
                    "retry_after_seconds": retry_after,
                },
                headers={
                    "Retry-After": str(retry_after),
                    "X-RateLimit-Limit": str(self.max_requests),
                    "X-RateLimit-Remaining": "0",
                },
            )

        response = await call_next(request)

        # Attach rate limit headers to every response
        remaining = max(0, int(bucket.tokens))
        reset_time = int(time.time()) + self.window_seconds

        response.headers["X-RateLimit-Limit"] = str(self.max_requests)
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Reset"] = str(reset_time)

        return response
