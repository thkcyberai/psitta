# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Session Protocol

AT THE START of every session, before responding to anything else, Claude Code MUST:
1. Check if .claude/pending_session_summary.json exists
2. If it exists: read it, synthesize Key Learnings from the prior session transcript, append them to ## Key Learnings in CLAUDE.md following the - YYYY-MM-DD: format, then delete the marker file
3. Only after the marker is processed (or confirmed absent) proceed with the user's request

At the END of every session, Claude Code MUST update CLAUDE.md automatically by reading from ALL of these sources — no prompt needed:

1. **DEVLOG** — Read the newest `.docx` in `C:\Users\Admin\OneDrive\_Psitta\Docs\DevLogs\` (newest by mtime, never a hardcoded filename).
2. **GIT LOG** — Run `git log --oneline -10` to capture the latest commits.
3. **KEY LEARNINGS** — Append any new rules, mistakes, or patterns discovered during the session to the `## Key Learnings` section.
4. **INFRASTRUCTURE** — Update `## Infrastructure State` with any changed values confirmed during the session.

**HISTORY RULE**: Never overwrite previous entries in `## Key Learnings` — always append. This section is an immutable log that grows over time.

**FORMAT RULE**: Each Key Learning entry must be a single line prefixed with the ISO date and a one-line description, e.g. `- 2026-04-13: <lesson>`.

## Project Overview
Psitta is a document-to-audio platform: upload a PDF/DOCX, it is parsed, chunked, tone-classified, and synthesized to natural narration via Azure Neural TTS. Flutter desktop frontend + Python FastAPI backend + PostgreSQL + Redis Streams + S3/MinIO.

## Repo Layout
```
C:/products/psitta/
├── core/backend/src/psitta/   ← FastAPI backend (Apache 2.0)
│   ├── main.py                ← App factory (create_app)
│   ├── config.py              ← Pydantic Settings
│   ├── dependencies.py        ← FastAPI DI (get_db_session, current_user, ...)
│   ├── middleware/            ← Auth0 JWT + dev bypass
│   ├── api/v1/                ← Route handlers (documents, playback, voices, tts,
│   │                             users, projects, subscriptions, auth)
│   ├── services/              ← Business logic (document, playback, audio_cache,
│   │                             subscription, audit)
│   ├── providers/             ← External integrations behind Protocol interfaces
│   │   ├── interfaces/contracts.py   ← TTSProvider, StorageProvider, VisionProvider, ...
│   │   ├── tts_azure.py / tts_edge.py / tts_elevenlabs.py / tts_router.py
│   │   ├── storage_s3.py, vision_anthropic.py, tone_rule_based.py,
│   │   └── voice_catalog_static.py
│   ├── workers/               ← document_processor.py (Redis Streams consumer)
│   ├── models/domain.py       ← Frozen dataclass domain models
│   ├── schemas/api.py         ← Pydantic strict request/response schemas
│   └── db/
│       ├── session.py         ← AsyncSession factory
│       └── migrations/versions/   ← Alembic migrations
├── apps/desktop/              ← Flutter desktop app (Windows primary)
│   └── lib/{core,data,features,widgets}/
├── extensions/                ← Proprietary add-ons (premium-tts, voice-cloning,
│                                 advanced-tone, enterprise, analytics)
├── infra/terraform/           ← AWS infrastructure
├── devops/                    ← CI scripts, deploy helpers
├── docs/                      ← PRD, API spec, ADRs, TESTING
└── docker-compose.yml         ← Local dev stack
```

## Architecture (three tiers)
```
Routes (api/v1/*.py)         Pydantic validation, HTTP concerns
     ↓
Services (services/*.py)     Business logic, orchestration, DB transactions
     ↓
Providers (providers/*.py)   External API calls behind Protocol interfaces
     ↓
External: PostgreSQL, Azure TTS, Anthropic, S3/MinIO
```

Providers are swapped via DI, which is also how the open-core boundary works: core ships Apache-licensed providers (Azure TTS, rule-based tone, static voice catalog); `extensions/` ships proprietary alternatives (ElevenLabs, LLM tone, voice cloning). See `OPEN_CORE_BOUNDARY.md` — core features live in `core/` and `apps/`; premium features live in `extensions/`.

Document processing runs in a **separate worker container** (`psitta-worker`, `python -m psitta.workers.document_processor`), not inside the API. The pipeline is Parse → Chunk → Describe (images via Anthropic) → Classify tone → Synthesize (TTS) → Finalize, with status transitions on the `documents` row driving client progress.

Audio segments are cached in `audio_segments` keyed by `(chunk_id, voice_id, speed)` — re-playing the same doc with the same voice is free, but changing speed forces re-synthesis (SSML prosody differs).

## Stack
- Python 3.12, FastAPI, SQLAlchemy async, Alembic, PostgreSQL 16
- Redis 7 Streams for the processing queue
- Flutter 3.24 desktop (Windows), Riverpod, Dio, just_audio
- Docker Compose for local dev (postgres, redis, minio, api, worker, migrate)
- Auth: Auth0 JWT middleware; dev bypass token `Bearer dev-bypass-token` resolves to dev user UUID `00000000-0000-0000-0000-000000000001`

## Critical Rules
1. **Always back up files before modifying**: `cp file.py file.py.bak` (this is an established convention in this repo — many `.bak` files already exist next to sources).
2. **Never break existing functionality** — progressive enhancement only.
3. **Use `encoding='utf-8'`** on all Python file writes.
4. **Backend runs in Docker**: package installs go in `core/backend/Dockerfile` or `pyproject.toml`, never pip-install on the host.
5. **Alembic migrations are append-only**: always create a new versioned file in `core/backend/src/psitta/db/migrations/versions/`, never edit existing ones.
6. **Enum additions**: run `ALTER TYPE enum_name ADD VALUE 'new_value'` in a raw SQL step of the migration *before* the column change that uses it — PostgreSQL won't let you use the new value in the same transaction it was added.
7. **PRs target `develop`**, not `main`. Use Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `ci:`).

## Dev Commands
```bash
# Bring up the full stack (api + worker + postgres + redis + minio)
docker compose up -d

# Infra only (when running api/worker on host)
docker compose up -d postgres redis minio

# Restart backend after code changes (bind-mounted src auto-reloads, but restart
# is needed when Dockerfile / deps / startup code change)
docker compose restart api worker

# Apply migrations
docker compose exec api alembic upgrade head
# or via the dedicated profile:
docker compose --profile migrate up migrate

# Generate a new migration
docker compose exec api alembic revision -m "description"

# Logs
docker compose logs api --tail=50
docker compose logs worker --tail=50

# Postgres shell
docker compose exec postgres psql -U psitta psitta

# Backend tests / lint / types
cd core/backend && pytest
cd core/backend && pytest tests/path/to/test_file.py::test_name   # single test
pre-commit run --all-files                                          # ruff + mypy + dart
ruff check core/backend/src
mypy core/backend/src

# Flutter
cd apps/desktop && flutter run -d windows
cd apps/desktop && flutter test
cd apps/desktop && dart analyze
```

## Database
- Users table: `id` (UUID), `auth0_id`, `email`, `display_name`, `tier` (enum: free/pro/admin), `created_at`, `last_login_at`
- Core tables: `users`, `documents`, `document_chunks`, `audio_segments`, `playback_sessions`, `voice_profiles`, `audit_log`, `subscription_plans`, `user_subscriptions`
- All queries are user-scoped via `user_id` — never write a query that could return another user's rows.

## Subscription Tiers (enforced in `services/subscription_service.py`)
| Feature              | Free       | Pro         |
|----------------------|------------|-------------|
| Docs per month       | 3          | 50          |
| Max doc size (MB)    | 10         | 50          |
| TTS voices           | Edge only  | All voices  |
| Audio cache days     | 7          | 90          |
| Archived docs        | No         | Yes         |

Stripe integration is deferred — plan changes currently go through the dev override endpoint `PATCH /users/me/plan`.

## Infrastructure State
- **AWS Account**: psitta-prod (808765744063), us-east-1
- **Cognito User Pool**: `us-east-1_zdbJm5EyI` | client: `1mtmn45trougr6oqpr1afhekp4`
- **Production API**: https://api.psitta.ai
- **ECS Cluster/Service**: `psitta-cluster` / `psitta-api` (Fargate, us-east-1)
- **Azure Speech Region**: `centralus` (corrected from `eastus` on 2026-04-13)
- **Secrets Manager**: `psitta/prod/app-secrets` (16 keys — `AZURE_TTS_REGION` added 2026-04-13)
- **.env backup**: `C:\Users\Admin\OneDrive\.env.psitta.backup`
- **DB backup**: `C:\Users\Admin\OneDrive\psitta_db_backup_20260304.sql`
- **GitHub**: github.com/thkcyberai/psitta — default working branch `develop`
- **Production TTS fallback chain**: ElevenLabs → Azure (centralus) → Edge

## Security CI Coverage
GitHub Actions workflow: `.github/workflows/security.yml`

| Tool               | Type               | Trigger                  | Status        |
|--------------------|--------------------|--------------------------|---------------|
| bandit             | Python SAST        | Every push + nightly     | Added 2026-04-13 |
| flutter pub audit  | Flutter deps       | Every push + nightly     | Added 2026-04-13 |
| pip-audit          | Python deps        | Nightly 02:00 UTC        | Pre-existing  |
| safety             | Python deps        | Nightly 02:00 UTC        | Pre-existing  |
| CodeQL             | Semantic analysis  | Nightly 02:00 UTC        | Pre-existing  |
| security-gate      | Build blocker      | Every push               | Blocks on any job failure |

- bandit scans `core/backend/src/` with `-ll` (HIGH/CRITICAL fail the build); last run: 6,639 LOC, 0 HIGH/CRITICAL.
- 4 MEDIUM bandit findings reviewed and confirmed false positives (B608 ×2 parameterized queries, B104 ECS `0.0.0.0` bind, B108 ephemeral single-container cache) — no remediation needed.
- `flutter-audit` runs in `apps/desktop/`; `security-gate` `needs:` array includes `flutter-audit`.

## M7 Security Hardening Status
| # | Task                                 | Status        | Notes |
|---|--------------------------------------|---------------|-------|
| 1 | WAF — AWS Web Application Firewall   | Done          | PHP/Laravel probe blocking, rate-limit rules |
| 2 | SAST + Dependency Scanning           | Done (2026-04-13) | bandit, pip-audit, safety, flutter pub audit, CodeQL |
| 3 | Terraform IAM Cleanup                | Done (2026-04-13) | `cross_account_admin` reconciled; `auth0_domain` / `auth0_audience` removed from `terraform.tfvars` |
| 4 | Auth0 Account Cancellation           | Next session  | Cognito stable 3 weeks, zero auth errors — irreversible, needs dedicated focus |
| 5 | Rate Limiting (FastAPI middleware)   | Queued        | Per user/IP on all API endpoints |
| 6 | SOC 2 Prep                           | Queued        | After all hardening items complete |

## Milestone Roadmap
| #  | Milestone                  | Status       | Notes |
|----|----------------------------|--------------|-------|
| M1 | Foundation Infrastructure  | Done         | VPC, RDS, S3, ECS, ALB, CloudFront, Secrets Manager |
| M2 | Login Infrastructure       | Done         | Auth0 → Cognito migration complete, saves ~$240/month |
| M3 | Subscription & Stripe      | Blocked      | Waiting on EIN (LLC opened) |
| M4 | Login Screen & Account UX  | Done         | Flutter login screen with Cognito Hosted UI |
| M5 | Application Completion     | Done         | PDF Single Source of Truth architecture, highlighting, eager TTS, MSIX v1.0.3.0 |
| M6 | Windows Packaging          | Done         | MSIX v1.0.3.0 built and packaged |
| M7 | Security Hardening         | In Progress  | WAF / SAST / IAM done — Auth0 cancel + rate limiting remain |
| M8 | Marketing Launch           | Queued       | After M7 complete |

## SWH Status
Select Word Highlight (SWH) is currently **non-functional**.

- **Root cause**: SWH relies on the ElevenLabs `/with-timestamps` endpoint; the ElevenLabs quota is exhausted (100,352 credits consumed).
- Azure and Edge TTS providers return no word-level timing data, so SWH has nothing to drive highlighting while the fallback chain is running on Azure.
- Will auto-restore when the ElevenLabs monthly billing cycle resets.
- **Option A (M6/M7)** — Forced alignment via `aeneas` or `gentle`: post-synthesis, server-side, provider-agnostic, zero API credits.
- **Option B (M6)** — Azure Speech SDK `word_boundary` events: native Azure word timestamps, matches ElevenLabs schema, ~4–6 hours of work, no Flutter changes needed.

## Next Session Priorities
1. **Auth0 cancellation** — manage.auth0.com → Settings → Cancel Subscription. Irreversible; Cognito has been stable 3 weeks with zero auth errors. Requires dedicated focus.
2. **Rate limiting** — FastAPI middleware, per user/IP, on all API endpoints.
3. **SWH Option B** — Azure Speech SDK `word_boundary` timestamps (~4–6 hours), restores SWH while running on the Azure provider.

On the horizon: M3 Stripe integration (resume when EIN arrives), ElevenLabs quota auto-reset, SOC 2 prep after M7 completes.

## Key Learnings
Immutable append-only log. Never rewrite past entries — only append new ones at the bottom.

- 2026-04-13: Devlog path is `C:\Users\Admin\OneDrive\_Psitta\Docs\DevLogs\` — always use newest by mtime, never hardcode filename
- 2026-04-13: CLAUDE.md update prompts must read file first and list section headers before using update/add verbs
- 2026-04-13: Azure TTS region is `centralus` not `eastus` — confirmed via CloudWatch `tts_router.ok` logs
- 2026-04-13: Secrets exposed in chat must be rotated immediately — never paste API keys into Claude.ai chat
- 2026-04-14: Stop hooks cannot access model context — they run as plain shell commands, so model-driven synthesis must be deferred to the next SessionStart via a pending marker
- 2026-04-14: Stop hooks must never fail the session — swallow all errors, log to a hook log file, and always exit 0
- 2026-04-14: Pending marker pattern (JSON with transcript path + git log + devlog info) is how mechanical hook work hands off to deferred model synthesis at SessionStart
- 2026-04-14: Split Session Protocol into mechanical (hook-written deterministic sections) vs model (deferred Key Learnings) — never ask a shell hook to synthesize lessons
- 2026-04-14: Use env vars (e.g. PSITTA_DEVLOG_DIR) in Stop hooks for runtime paths instead of hardcoding, so hooks remain portable across machines
- 2026-04-14: Stop hook scripts must force UTF-8 (LC_ALL=C.UTF-8, PYTHONIOENCODING=utf-8) to prevent em-dash mojibake (â€—) in git log on Windows
- 2026-04-14: Infra state updater must use first-token matching (not substring equality) so hand-written audit context like "centralus (corrected from eastus on 2026-04-13)" is preserved on re-run
- 2026-04-14: Per-tier rate-limit route matchers must be ordered longest-first — chunk matcher `/documents/{id}/chunks/{cid}/resynthesize` must precede `/documents/{id}/resynthesize` or the shorter pattern shadows it
- 2026-04-14: Authenticated routes pay a double JWT decode (rate-limit middleware + get_current_user) — mitigate with per-token cache + JWKS cache (1hr TTL); full elimination requires refactoring middleware/auth.py
- 2026-04-14: Rate limiter must fail-open — catch all exceptions, log, allow the request through; a limiter bug must never DoS the API
- 2026-04-14: RateLimitMiddleware is outermost so 429 responses bypass CORS/RequestID middleware — fine for Flutter desktop, will need reorder when a web UI ships
- 2026-04-14: Kinesis Firehose → S3 CloudWatch log objects are doubly-gzipped (outer Firehose layer + inner per-record gzip members) — a single gunzip leaves 0x1f8b markers; decoder must iterate nested gzip members

## Last Devlog
- **File**: `C:\Users\Admin\OneDrive\_Psitta\Docs\DevLogs\M7Complete_LoggingInfra_ComplianceFramework_Devlog_20260414.docx`
- **Date**: April 14, 2026
- **Title**: Development Log  -  April 14, 2026
- **Focus**: M7 Security Hardening completion + Logging infrastructure + Compliance documentation
- **Recent commits** (`git log --oneline -10`):

```
47875bd feat(M7): add WAF logging to S3 + CloudWatch alarm for XSS blocks + SNS security alerts topic
b4e904c fix(WAF): allow DOCX/image uploads blocked by CrossSiteScripting_BODY false positive — label-match pattern
cf37693 feat(M7): wire audit_service.log_event() to all 18 security-relevant endpoints
e0bc568 feat(M7): extend CloudWatch log retention to 90d + S3 Glacier IR archival via Kinesis Firehose
a7ca21b docs: add logging, security and compliance guide v1.0
89f396b fix: project card doc count invisible in Midnight dark theme — outline → onSurfaceVariant
9aeede4 feat(M7): per-tier rate limiting on high-cost document endpoints
6d5fa92 chore: add host-side requirements.txt for .claude/hooks scripts (python-docx)
c2ca947 feat: add CLAUDE.md auto-update hooks (Stop + SessionStart) with pending summary pattern
234188f feat: PDF architecture rewrite, WAF rules, audio cache improvements, library and player updates
```
- _Auto-updated by Stop hook at 2026-04-15 13:09 UTC_

## Further Reading
- `ARCHITECTURE.md` — full system design and component diagram
- `OPEN_CORE_BOUNDARY.md` — what goes in core vs extensions
- `docs/adr/` — architecture decision records
- `docs/TESTING.md` — test strategy
- `CONTRIBUTING.md` — contributor workflow
