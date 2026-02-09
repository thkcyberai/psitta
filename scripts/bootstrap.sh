#!/usr/bin/env bash
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Psitta — Developer Bootstrap                         ║"
echo "╚══════════════════════════════════════════════════════════╝"

cd "$(git rev-parse --show-toplevel)"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "  ✓ .env created from .env.example"
else
  echo "  ✓ .env already exists"
fi

echo "→ Starting Docker services..."
docker compose up -d postgres redis minio
docker compose up minio-init

echo "→ Setting up Python backend..."
cd core/backend
python3 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip -q
pip install -e ".[dev]" -q

echo "→ Running migrations..."
alembic -c src/psitta/db/alembic.ini upgrade head 2>/dev/null || \
  alembic -c alembic.ini upgrade head

echo "→ Installing pre-commit hooks..."
pre-commit install
cd ../..

echo "→ Setting up Flutter..."
cd apps/mobile
flutter pub get -q
cd ../..

echo ""
echo "  ✓ Bootstrap complete!"
echo "  Backend:  cd core/backend && uvicorn psitta.main:create_app --factory --reload"
echo "  Flutter:  cd apps/mobile && flutter run"
echo "  API docs: http://localhost:8000/docs"
