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
from typing import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# Only accept UUIDs or alphanumeric strings up to 64 chars
_VALID_REQUEST_ID = re.compile(r"^[a-zA-Z0-9\-]{1,64}$")

HEADER_NAME = "X-Request-ID"


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

        # Attach to request state for downstream access
        request.state.request_id = request_id

        # Bind to structlog context for correlated logs
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        logger.info(
            "request.started",
            method=request.method,
            path=request.url.path,
            client=request.client.host if request.client else "unknown",
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
