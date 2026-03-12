"""
Psitta — Audit Logging Service.

Records security-relevant events (login, logout, permission changes)
to the audit_log table for compliance and incident investigation.
"""

from __future__ import annotations

from typing import Any
from uuid import uuid4

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)


async def log_event(
    db: AsyncSession,
    *,
    action: str,
    resource_type: str,
    user_id: str | None = None,
    resource_id: str | None = None,
    details: dict[str, Any] | None = None,
    ip_address: str | None = None,
) -> None:
    """Insert an audit log entry.

    Args:
        db: Active database session.
        action: Event name, e.g. "user.login", "user.logout", "document.delete".
        resource_type: Type of resource affected, e.g. "user", "document".
        user_id: Auth0 subject ID or internal user ID.
        resource_id: UUID of the affected resource (optional).
        details: Additional JSON metadata about the event.
        ip_address: Client IP address.
    """
    import json

    event_id = uuid4()
    details_json = json.dumps(details or {})

    await db.execute(
        text(
            "INSERT INTO audit_log "
            "(id, user_id, action, resource_type, resource_id, details_json, ip_address) "
            "VALUES (:id, :user_id, :action, :resource_type, :resource_id, :details, :ip)"
        ),
        {
            "id": event_id,
            "user_id": user_id,
            "action": action,
            "resource_type": resource_type,
            "resource_id": resource_id,
            "details": details_json,
            "ip": ip_address,
        },
    )

    logger.info(
        "audit.logged",
        event_id=str(event_id),
        action=action,
        resource_type=resource_type,
        user_id=user_id,
    )
