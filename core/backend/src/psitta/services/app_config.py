"""services/app_config.py — remote control-plane resolver.

Reads server-owned CLIENT configuration (the ``app_config`` table, migration
032) and exposes it to the client via ``GET /config``. This is the first brick
of the remote control plane: minimum/recommended client version and feature
flags / kill switches that can change WITHOUT a client release or backend
redeploy — an admin flips a value (scripts/set_config.py) and the next request
sees it.

Reliability-first: resolution is DB overrides deep-merged over PERMISSIVE
defaults, and the read is fail-safe. If the table is missing (code deployed
before the migration is applied) or a row is malformed, callers get the
defaults — which never force an update and never fire a kill switch — so a
config fault can never lock users out of the app.
"""

from __future__ import annotations

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)

# The single logical config document lives under this key.
CONFIG_KEY = "client_config"

# Permissive, fail-safe defaults. "0.0.0" as the version floor means NO client
# is ever forced to update, and an empty flags map means NO feature is killed —
# so if config is absent or unreadable the app keeps working normally. Real
# values are set via scripts/set_config.py when a release ships or an incident
# needs a kill switch.
DEFAULT_CLIENT_CONFIG: dict = {
    "minimum_supported_version": "0.0.0",
    "recommended_version": "0.0.0",
    "flags": {},
}


async def get_client_config(db: AsyncSession) -> dict:
    """Resolve the client control-plane config: DB overrides over safe defaults.

    Fail-safe: any error (missing ``app_config`` table before migration 032, a
    malformed row) returns the permissive defaults. The SELECT runs in a
    SAVEPOINT so a missing-relation error cannot poison the request
    transaction.
    """
    merged: dict = {
        "minimum_supported_version": DEFAULT_CLIENT_CONFIG["minimum_supported_version"],
        "recommended_version": DEFAULT_CLIENT_CONFIG["recommended_version"],
        "flags": dict(DEFAULT_CLIENT_CONFIG["flags"]),
    }

    try:
        async with db.begin_nested():
            row = (
                await db.execute(
                    text("SELECT value FROM app_config WHERE key = :k"),
                    {"k": CONFIG_KEY},
                )
            ).first()
    except Exception:
        logger.warning("app_config.read_failed_using_defaults")
        return merged

    if not row or not isinstance(row.value, dict):
        return merged

    val = row.value
    if isinstance(val.get("minimum_supported_version"), str):
        merged["minimum_supported_version"] = val["minimum_supported_version"]
    if isinstance(val.get("recommended_version"), str):
        merged["recommended_version"] = val["recommended_version"]
    if isinstance(val.get("flags"), dict):
        merged["flags"] = val["flags"]
    return merged
