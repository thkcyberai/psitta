"""
Request ID middleware — injects a unique request ID into every request.

If the client sends X-Request-ID, it's reused (after validation).
Otherwise, a new UUID is generated. The ID is attached to the request
state and echoed in the response header for tracing.
"""

from __future__ import annotations

import re
import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

_UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
HEADER = "X-Request-ID"


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Attach a unique request ID to every request/response cycle."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        # Accept client-provided ID if it's a valid UUID
        incoming = request.headers.get(HEADER, "")
        if incoming and _UUID_RE.match(incoming):
            request_id = incoming
        else:
            request_id = str(uuid.uuid4())

        # Store on request state for downstream access
        request.state.request_id = request_id

        # Bind to structlog context for log correlation across the request
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            method=request.method,
            path=request.url.path,
        )

        response = await call_next(request)
        response.headers[HEADER] = request_id
        return response
