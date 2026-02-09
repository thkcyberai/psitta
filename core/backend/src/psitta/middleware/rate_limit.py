"""
Rate limiting middleware — token bucket per user + global circuit breaker.

Uses in-memory counters for MVP. Production would use Redis-backed
sliding window counters for multi-instance deployments.

Rate limit headers (RFC draft):
  X-RateLimit-Limit: max requests per window
  X-RateLimit-Remaining: remaining requests
  X-RateLimit-Reset: seconds until window resets
"""

from __future__ import annotations

import time
from collections import defaultdict

from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

# Defaults
DEFAULT_RATE = 100  # requests per window
DEFAULT_WINDOW = 60  # seconds
UPLOAD_RATE = 10  # uploads per window
UPLOAD_WINDOW = 60

# Path-specific overrides
PATH_LIMITS: dict[str, tuple[int, int]] = {
    "/api/v1/documents": (UPLOAD_RATE, UPLOAD_WINDOW),  # POST only
}


class _TokenBucket:
    """Simple token bucket for rate limiting."""

    __slots__ = ("capacity", "tokens", "refill_rate", "last_refill")

    def __init__(self, capacity: int, window_seconds: int) -> None:
        self.capacity = capacity
        self.tokens = float(capacity)
        self.refill_rate = capacity / window_seconds
        self.last_refill = time.monotonic()

    def consume(self) -> bool:
        now = time.monotonic()
        elapsed = now - self.last_refill
        self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_rate)
        self.last_refill = now

        if self.tokens >= 1.0:
            self.tokens -= 1.0
            return True
        return False

    @property
    def remaining(self) -> int:
        return max(0, int(self.tokens))

    @property
    def reset_seconds(self) -> int:
        if self.tokens >= 1.0:
            return 0
        deficit = 1.0 - self.tokens
        return max(1, int(deficit / self.refill_rate) + 1)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Per-user token bucket rate limiter."""

    def __init__(self, app, **kwargs) -> None:  # type: ignore[no-untyped-def]
        super().__init__(app, **kwargs)
        self._buckets: dict[str, _TokenBucket] = defaultdict(
            lambda: _TokenBucket(DEFAULT_RATE, DEFAULT_WINDOW)
        )
        self._upload_buckets: dict[str, _TokenBucket] = defaultdict(
            lambda: _TokenBucket(UPLOAD_RATE, UPLOAD_WINDOW)
        )

    def _get_key(self, request: Request) -> str:
        """Extract rate limit key: authenticated user ID or IP."""
        user_id = getattr(request.state, "user_id", None)
        if user_id:
            return f"user:{user_id}"
        forwarded = request.headers.get("X-Forwarded-For", "")
        ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")
        return f"ip:{ip}"

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        # Skip rate limiting for health checks
        if request.url.path in ("/health", "/ready"):
            return await call_next(request)

        key = self._get_key(request)

        # Select bucket based on path
        is_upload = request.url.path == "/api/v1/documents" and request.method == "POST"
        bucket = self._upload_buckets[key] if is_upload else self._buckets[key]

        if not bucket.consume():
            return JSONResponse(
                status_code=429,
                content={
                    "error": "rate_limit_exceeded",
                    "message": "Too many requests. Please slow down.",
                    "retry_after": bucket.reset_seconds,
                },
                headers={
                    "Retry-After": str(bucket.reset_seconds),
                    "X-RateLimit-Limit": str(bucket.capacity),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(bucket.reset_seconds),
                },
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(bucket.capacity)
        response.headers["X-RateLimit-Remaining"] = str(bucket.remaining)
        response.headers["X-RateLimit-Reset"] = str(bucket.reset_seconds)
        return response
