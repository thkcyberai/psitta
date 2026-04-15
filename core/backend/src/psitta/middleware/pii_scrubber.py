"""
PII Scrubber — structlog processor for GDPR Article 25 compliance.

Runs inside the structlog processor chain (after TimeStamper, before
JSONRenderer) and replaces the values of known PII field names with
"[REDACTED]" before the event is serialized to CloudWatch.

Design invariants:
- Silent. Any exception inside the scrubber is swallowed; the original
  event_dict is returned unchanged. A buggy scrubber must never drop
  a log line or crash a request.
- Non-destructive key-wise. Keys are preserved so operators can still
  see "this event had an email field" — only the value is masked.
- Context-aware for ip_address: IPs are legitimate signal in auth,
  rate-limit, and permission events (abuse investigation, 429 triage).
  They are redacted everywhere else.
"""

from __future__ import annotations

from typing import Any, MutableMapping

_REDACTED = "[REDACTED]"

# Always-scrub: these fields are never legitimate in any log line.
_ALWAYS_SCRUB: frozenset[str] = frozenset(
    {
        "email",
        "user_email",
        "name",
        "full_name",
        "username",
        "phone",
        "address",
    }
)

# Conditional: scrubbed unless the event name starts with one of these
# security-relevant prefixes, where client IP is intentional signal.
_IP_KEEP_PREFIXES: tuple[str, ...] = (
    "auth.",
    "rate_limit.",
    "permission.",
)


def _is_security_event(event_name: Any) -> bool:
    if not isinstance(event_name, str):
        return False
    return event_name.startswith(_IP_KEEP_PREFIXES)


def scrub_pii(
    logger: Any,
    method_name: str,
    event_dict: MutableMapping[str, Any],
) -> MutableMapping[str, Any]:
    """Structlog processor: mask PII field values in-place.

    Signature matches structlog's processor contract:
    (logger, method_name, event_dict) -> event_dict.
    """
    try:
        for key in _ALWAYS_SCRUB:
            if key in event_dict:
                event_dict[key] = _REDACTED

        if "ip_address" in event_dict and not _is_security_event(
            event_dict.get("event")
        ):
            event_dict["ip_address"] = _REDACTED

        return event_dict
    except Exception:
        # Never raise from inside the logging pipeline.
        return event_dict
