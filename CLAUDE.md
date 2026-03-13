# Psitta — Claude Code Context

## Project Overview
Psitta is a desktop document-to-audio app. Flutter desktop frontend + Python FastAPI backend + PostgreSQL.

## Repo Layout
```
C:/products/psitta/
├── core/backend/src/psitta/   ← FastAPI backend (Python)
│   ├── main.py                ← App factory
│   ├── config.py              ← Pydantic settings
│   ├── dependencies.py        ← FastAPI DI (get_db_session, etc.)
│   ├── api/v1/                ← Route handlers
│   ├── models/domain.py       ← Dataclass domain models
│   ├── schemas/api.py         ← Pydantic request/response schemas
│   ├── services/              ← Business logic
│   ├── providers/             ← TTS, storage, vision providers
│   └── db/
│       ├── session.py         ← AsyncSession factory
│       └── migrations/versions/   ← Alembic migrations
└── apps/desktop/              ← Flutter desktop app (Windows)
    └── lib/
        ├── data/api/api_client.dart
        ├── data/repositories/
        └── features/
```

## Stack
- Python 3.12, FastAPI, SQLAlchemy async, Alembic, PostgreSQL 16
- Flutter 3.24 desktop (Windows), Riverpod, Dio, just_audio
- Docker Compose for local dev (postgres, redis, minio, api containers)
- Auth: Auth0 JWT middleware (dev bypass token: `Bearer dev-bypass-token`)

## Critical Rules
1. **ALWAYS backup files before modifying**: `cp file.py file.py.bak`
2. **Never break existing functionality** — progressive enhancement only
3. **Use encoding='utf-8'** on all Python file writes
4. **Run in Docker**: backend runs in Docker container, so package installs go in Dockerfile or pyproject.toml
5. **Alembic migrations**: always create a new versioned file in `db/migrations/versions/`, never edit existing ones

## Database
- Local: `docker compose exec postgres psql -U psitta psitta`
- Run migrations: `docker compose exec api alembic upgrade head`
- Enum additions require: `ALTER TYPE enum_name ADD VALUE 'new_value'` BEFORE Alembic migration runs

## Dev Commands
```bash
# Restart backend after code changes
docker compose restart api

# Apply new migration
docker compose exec api alembic upgrade head

# Check logs
docker compose logs api --tail=50

# Run Flutter
cd apps/desktop && flutter run -d windows
```

## Auth Middleware
- Production: Auth0 JWT validation
- Dev bypass: `Authorization: Bearer dev-bypass-token` skips JWT, uses dev user UUID `00000000-0000-0000-0000-000000000001`

## Current User Table
Users table has columns: id (UUID), auth0_id, email, display_name, tier (enum: free/pro/admin), created_at, last_login_at

## M3a Goal — Subscription Tier Infrastructure
We are building subscription plan enforcement WITHOUT Stripe (Stripe comes in M3b).

### Tables to create (migration 009):
- `subscription_plans`: plan definitions (free, pro_monthly, pro_annual) with limits
- `user_subscriptions`: links user to active plan, dates, status

### Tier limits to enforce:
| Feature              | Free       | Pro         |
|----------------------|------------|-------------|
| Docs per month       | 3          | 50          |
| Max doc size (MB)    | 10         | 50          |
| TTS voices           | Edge only  | All voices  |
| Audio cache days     | 7          | 90          |
| Archived docs        | No         | Yes         |

### Files to create/modify for M3a:
- `db/migrations/versions/009_subscription_plans.py` — new migration
- `models/domain.py` — add SubscriptionPlan, UserSubscription dataclasses
- `schemas/api.py` — add plan/subscription schemas
- `services/subscription_service.py` — NEW: plan lookup, limit checks, overrides
- `api/v1/subscriptions.py` — NEW: GET /subscriptions/plans, GET /users/me/subscription, PATCH /users/me/plan (dev override)
- `api/v1/documents.py` — add tier enforcement on upload
- `api/v1/router.py` — mount new subscriptions router
