#!/usr/bin/env bash
set -euo pipefail
echo "→ Dropping database..."
docker compose exec postgres dropdb -U psitta psitta --if-exists
echo "→ Creating database..."
docker compose exec postgres createdb -U psitta psitta
echo "→ Running migrations..."
cd core/backend
alembic -c src/psitta/db/alembic.ini upgrade head 2>/dev/null || \
  alembic -c alembic.ini upgrade head
echo "  ✓ Database reset complete"
