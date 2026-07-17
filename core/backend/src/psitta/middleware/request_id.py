"""
Psitta — Request ID Middleware.

Assigns a unique X-Request-ID to every request for distributed tracing.
If the client provides one, it is preserved. Otherwise, a new UUID4 is generated.

The request ID is:
  1. Added to the response headers (X-Request-ID)
  2. Bound to structlog context for correlated log entries
  3. Available via request.state.request_id in route handlers

Security: Client-provided IDs are validated (UUID format, max 64 chars)
          to prevent header injection attacks.
"""

from __future__ import annotations

import re
import uuid
from collections.abc import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# Only accept UUIDs or alphanumeric strings up to 64 chars
_VALID_REQUEST_ID = re.compile(r"^[a-zA-Z0-9\-]{1,64}$")

HEADER_NAME = "X-Request-ID"

# Client version telemetry. The desktop client stamps X-Client-Version on every
# request; capturing it here (bound to the log context) turns CloudWatch into a
# live view of which client versions are in the field — the visibility you need
# before ever raising the /config minimum-version floor. Validated to a strict
# charset/length so a hostile header can't inject into structured logs.
CLIENT_VERSION_HEADER = "X-Client-Version"
_VALID_CLIENT_VERSION = re.compile(r"^[0-9A-Za-z.+\-]{1,32}$")


def sanitize_client_version(raw: str | None) -> str:
    """Return a safe client version string, or "unknown" for absent/invalid.

    Rejects anything outside ``[0-9A-Za-z.+-]{1,32}`` so an attacker-controlled
    header can never inject newlines or control characters into the logs.
    """
    if raw and _VALID_CLIENT_VERSION.match(raw):
        return raw
    return "unknown"


class RequestIDMiddleware(BaseHTTPMiddleware):
    """ASGI middleware that ensures every request has a unique trace ID.

    Preserves client-provided X-Request-ID if it passes validation,
    otherwise generates a new UUID4.
    """

    async def dispatch(
        self, request: Request, call_next: Callable[..., Response]
    ) -> Response:
        # Extract or generate request ID
        incoming_id = request.headers.get(HEADER_NAME)

        if incoming_id and _VALID_REQUEST_ID.match(incoming_id):
            request_id = incoming_id
        else:
            request_id = str(uuid.uuid4())

        client_version = sanitize_client_version(
            request.headers.get(CLIENT_VERSION_HEADER)
        )

        # Attach to request state for downstream access
        request.state.request_id = request_id
        request.state.client_version = client_version

        # Bind to structlog context for correlated logs. client_version rides
        # the whole request, so every log line it produces is attributable to a
        # client version without threading it through each call site.
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            client_version=client_version,
        )

        logger.info(
            "request.started",
            method=request.method,
            path=request.url.path,
            client=request.client.host if request.client else "unknown",
            client_version=client_version,
        )

        response = await call_next(request)

        # Always include request ID in response headers
        response.headers[HEADER_NAME] = request_id

        logger.info(
            "request.completed",
            method=request.method,
            path=request.url.path,
            status_code=response.status_code,
        )

        return response
