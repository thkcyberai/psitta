"""seed_welcome.py — Admin CLI to seed the Writing Nook welcome kit.

Seeds the 6 starter documents (docx / md / txt / html / pdf / epub) into an
existing account's Library, each parsed + chunked + covered. The auto-trigger
in ``GET /documents/`` handles brand-new writers on first login; this script
exists to seed an account that already existed before the feature shipped, or
to re-seed for testing.

Usage
-----
  ECS one-off task (production)::

      aws ecs run-task --cluster psitta-cluster \\
          --task-definition psitta-api --profile psitta-prod \\
          --region us-east-1 \\
          --network-configuration '...' \\
          --overrides '{"containerOverrides":[{"name":"psitta-api",
            "command":["python","scripts/seed_welcome.py",
                       "writer@example.com"]}]}'

Flags
-----
  EMAIL            Account to seed (lowercased on lookup).
  --force          Seed even if welcome_seeded is already true. NOTE: this
                   creates a second copy of the kit — it does not de-dupe.
  --dry-run        Resolve the user and report what would happen; no writes.

The script sets ``users.welcome_seeded = true`` after a successful seed so the
auto-trigger won't seed the same account again.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

import structlog
from sqlalchemy import text

logger = structlog.get_logger("seed_welcome")


async def _run(email: str, *, force: bool, dry_run: bool) -> int:
    from psitta.db.session import async_session_factory
    from psitta.services.seed_service import seed_welcome_kit

    normalized = email.strip().lower()

    async with async_session_factory() as db:
        row = (
            await db.execute(
                text(
                    "SELECT id, welcome_seeded, email FROM users "
                    "WHERE lower(email) = :em"
                ),
                {"em": normalized},
            )
        ).first()

        if row is None:
            logger.error("seed_welcome.user_not_found", email=normalized)
            return 1

        user_id = row.id
        already = bool(row.welcome_seeded)
        logger.info(
            "seed_welcome.user_resolved",
            email=normalized,
            user_id=str(user_id),
            welcome_seeded=already,
        )

        if already and not force:
            logger.info(
                "seed_welcome.skip_already_seeded",
                user_id=str(user_id),
                hint="pass --force to seed again (creates duplicates)",
            )
            return 0

        if dry_run:
            logger.info(
                "seed_welcome.dry_run",
                user_id=str(user_id),
                would_seed=True,
                force=force,
            )
            return 0

        docs, chunks = await seed_welcome_kit(db, user_id)
        await db.execute(
            text("UPDATE users SET welcome_seeded = true WHERE id = :id"),
            {"id": str(user_id)},
        )
        await db.commit()
        logger.info(
            "seed_welcome.done",
            user_id=str(user_id),
            docs=docs,
            chunks=chunks,
        )
        return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Seed the Writing Nook welcome kit into an account."
    )
    parser.add_argument("email", help="Account email (lowercased on lookup).")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Seed even if already seeded (creates duplicates).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve the user and report; no writes.",
    )
    args = parser.parse_args(argv)
    return asyncio.run(
        _run(args.email, force=args.force, dry_run=args.dry_run)
    )


if __name__ == "__main__":
    sys.exit(main())
