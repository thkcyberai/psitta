"""Read-only: show the narrative origin of the most recent user blueprints.

Verifies Phase 2 (migration 028 + persistence code): confirms that
``narrative_structure_key`` / ``narrative_variant`` are stored when a blueprint
is generated from the Narrative Structure tab. No INSERT/UPDATE/DELETE — safe to
run any number of times from an ECS one-off task.

Run (production):
    aws ecs run-task --cluster psitta-cluster --task-definition psitta-api \\
      --launch-type FARGATE --network-configuration '...' \\
      --overrides '{"containerOverrides":[{"name":"psitta-api", \\
        "command":["python","scripts/check_blueprint_narrative.py"]}]}'
"""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import text

from psitta.db.session import async_session_factory

logging.basicConfig(
    format="%(asctime)s  %(levelname)-7s  %(message)s",
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("check-narrative")


async def _run() -> None:
    async with async_session_factory() as db:
        rows = (
            await db.execute(
                text(
                    """
                    SELECT name,
                           narrative_structure_key,
                           narrative_variant,
                           created_at
                    FROM blueprints
                    WHERE is_system = false
                    ORDER BY created_at DESC
                    LIMIT 8
                    """
                )
            )
        ).all()
        if not rows:
            log.info("No user blueprints found.")
            return
        log.info("Most recent user blueprints (newest first):")
        for r in rows:
            log.info(
                "  %-28s  key=%-20s  variant=%-18s  %s",
                (r.name or "")[:28],
                r.narrative_structure_key or "-",
                r.narrative_variant or "-",
                r.created_at,
            )


if __name__ == "__main__":
    asyncio.run(_run())
