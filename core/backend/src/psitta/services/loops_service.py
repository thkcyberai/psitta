"""services/loops_service.py — Loops.so lifecycle event client (GTM Phase 2).

The reverse-trial funnel is event-driven: the backend posts an event to
Loops (``signup``, ``activated``, ``trial_3_days_left``, ``trial_ended``,
``subscribed``) and Loops fires the matching email sequence. This module
is the single, safe way to emit those events.

Safety, because these fire from hot paths (login/provisioning, billing):
  * Ships OFF. ``emit_event`` is a no-op unless ``LOOPS_EVENTS_ENABLED``
    is true AND ``LOOPS_API_KEY`` is set. So merging/deploying this
    changes nothing until the key + flag are configured.
  * Never raises. Any failure (network, timeout, bad key, Loops down) is
    swallowed and logged; the caller's request is never affected.
  * Skips synthetic emails (``…@auth0.local``) so we never send Loops a
    fake address when Cognito didn't provide a real one.

Loops "events/send" upserts the contact if it doesn't exist, so the
``signup`` event both creates the contact and starts the Welcome
sequence in one call.
"""

from __future__ import annotations

from uuid import UUID

import httpx
import structlog

from psitta.config import get_settings

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

_LOOPS_EVENTS_URL = "https://app.loops.so/api/v1/events/send"
_TIMEOUT_SECONDS = 5.0


async def emit_event(
    email: str | None,
    event_name: str,
    *,
    user_id: UUID | str | None = None,
    first_name: str | None = None,
    contact_properties: dict[str, object] | None = None,
) -> bool:
    """Post a lifecycle event to Loops. Best-effort; never raises.

    Returns True only if Loops accepted the event. Returns False (without
    error) when the integration is disabled, the key is missing, the email
    is absent/synthetic, or the request fails.
    """
    settings = get_settings()
    if not settings.LOOPS_EVENTS_ENABLED or not settings.LOOPS_API_KEY:
        return False
    if not email or email.endswith("@auth0.local"):
        return False

    props: dict[str, object] = dict(contact_properties or {})
    if first_name:
        props.setdefault("firstName", first_name)

    payload: dict[str, object] = {"email": email, "eventName": event_name}
    if user_id is not None:
        payload["userId"] = str(user_id)
    if props:
        payload["contactProperties"] = props

    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_SECONDS) as client:
            resp = await client.post(
                _LOOPS_EVENTS_URL,
                headers={
                    "Authorization": f"Bearer {settings.LOOPS_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
        if resp.status_code == 200:
            logger.info("loops.event_sent", event=event_name, user_id=str(user_id))
            return True
        logger.warning(
            "loops.event_rejected",
            event=event_name,
            status=resp.status_code,
            body=resp.text[:300],
        )
        return False
    except Exception as exc:  # must never break the caller's request
        logger.warning("loops.event_failed", event=event_name, error=str(exc))
        return False
