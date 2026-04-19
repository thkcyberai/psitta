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
- 2026-04-15: SOC 2 CC7.2 audit_log tamper-evidence requires THREE layers — (1) REVOKE UPDATE/DELETE from app role, (2) BEFORE UPDATE OR DELETE FOR EACH ROW trigger, (3) BEFORE TRUNCATE FOR EACH STATEMENT trigger. Row-level triggers do NOT fire on TRUNCATE, and TRUNCATE is not a grantable privilege, so the statement-level trigger is the only portable guard
- 2026-04-15: For full SOC 2 audit_log tamper-evidence the table owner must be a separate migration role (e.g. `psitta_migrator`), not the app role (`psitta`) — owners can `ALTER TABLE … DISABLE TRIGGER` and bypass the guard. Out of scope for migration 011; follow-up work for the SOC 2 evidence package
- 2026-04-15: `tests/conftest.py` `test_settings` fixture uses `DATABASE_HOST`/`DATABASE_NAME`/`DATABASE_USER`/`DATABASE_PASSWORD` but `config.py` Settings defines `POSTGRES_HOST`/`POSTGRES_DB`/`POSTGRES_USER`/`POSTGRES_PASSWORD` — the fixture will raise on strict instantiation. Pre-existing bug, separate task to reconcile; new tests should use `get_settings()` (env-loaded) to sidestep it
- 2026-04-15: TRUNCATE does not fire row-level triggers in PostgreSQL — a separate BEFORE TRUNCATE FOR EACH STATEMENT trigger is required for full tamper-evidence
- 2026-04-15: audit_log owner-role separation needed for SOC 2: psitta_migrator owns the table, psitta app role is non-owner — prevents ALTER TABLE DISABLE TRIGGER bypass
- 2026-04-15: conftest.py uses DATABASE_HOST/DATABASE_NAME but config.py defines POSTGRES_HOST/POSTGRES_DB — pre-existing mismatch, fix separately
- 2026-04-15: CLAUDE.md SessionStart hook processes pending markers automatically on startup — no human prompt needed from this session forward
- 2026-04-15 (PM): Cloudflare email auth records (DKIM CNAME, SPF/DMARC TXT) must be DNS only (gray cloud) — proxied CNAMEs silently break DKIM signature validation
- 2026-04-15 (PM): Hostinger email DNS sequence: domain-verification TXT → MX records → SPF TXT → 3 DKIM CNAMEs → DMARC TXT on _dmarc — all configurable in Cloudflare in a single session
- 2026-04-15 (PM): Stripe Managed Payments (Merchant of Record) costs 5% + $0.50 vs standard 2.9% + $0.30 — avoid for US-focused SaaS with margin pressure; add Stripe Tax (~0.5%) later as separate product when compliance becomes real
- 2026-04-15 (PM): SaaS tax code (txcd_10103000) is correct for desktop clients backed by cloud services — Downloadable Software (txcd_10101000) is wrong classification because the product stops working if backend shuts down
- 2026-04-15 (PM): Stripe lookup keys (e.g. reading_nook_pro_monthly) let the backend reference prices semantically instead of hardcoding opaque IDs — enables future price swaps without code changes
- 2026-04-15 (PM): Creativity Nook Pro as separate Stripe product (not add-on) enables clean subscription swaps with automatic proration — customer pays $19.99/mo total, not $14.99 + $19.99
- 2026-04-15 (PM): Stripe sandbox separates account creation from business verification — EIN + bank account are requested only on Switch to live account, allowing full integration testing before legal/financial setup
- 2026-04-15 (PM): Security discipline for secrets files: never echo/cat/print values to terminal; use Claude Code prompts that explicitly prohibit printing and require user to paste via editor (Notepad/VS Code) directly into the file
- 2026-04-16: SessionStart hook protocol-based approach fails because user instructions always override model's Session Protocol rules — deterministic Python synthesis eliminates the model from the critical path entirely
- 2026-04-16: When diagnosing hook failures, check the actual log path (.claude/hooks/session_start_hook.log) not the assumed path (.claude/session_start_hook.log) — path mismatches cause false 'hook never ran' conclusions
- 2026-04-16: Marker accumulation across sessions: the Stop hook appends to pending_session_summary.json on every session end — if the Start hook never consumes, the marker grows indefinitely with stale entries from old devlogs
- 2026-04-16: Process only the newest devlog from the marker array — older entries are stale snapshots superseded by newer devlogs that already contain all previous content
- 2026-04-16: CLAUDE.md Key Learnings uses bullet format (- DATE: LEARNING) not markdown table format — the hook must read and write the actual format to avoid corrupting existing entries
- 2026-04-16: ECS --force-new-deployment re-pulls the :latest image tag from ECR without creating a new task definition revision — task definition number stays the same but the container runs new code
- 2026-04-16: Production Alembic migrations can be run via one-off ECS task with command override when the RDS is in a private subnet unreachable from the developer laptop — no SSH tunnel or security group changes needed
- 2026-04-16: RDS automated backups run daily with continuous transaction logs every 5 minutes — point-in-time recovery within the retention window (default 7 days) requires no manual setup
- 2026-04-16: Stripe webhook endpoint must always return HTTP 200 after storing the event, even on handler errors — returning 500 causes Stripe to retry for up to 3 days, flooding the server
- 2026-04-16: Insert-first webhook pattern: store the raw event payload in subscription_events BEFORE running the handler — if the handler crashes, the event is preserved for manual reprocessing
- 2026-04-16: Stripe Checkout (prebuilt hosted page) is the correct integration for Flutter desktop — flutter_stripe SDK doesn't support desktop, so browser handoff via url_launcher is the clean path
- 2026-04-16: Stripe lookup keys (e.g. reading_nook_pro_monthly) resolve price IDs at runtime via stripe.Price.list() — code references semantic names, not opaque Stripe IDs, enabling price changes without code deployment
- 2026-04-16: Plan enforcement should be a FastAPI dependency (Depends), not global middleware — only some endpoints need gating, and billing endpoints must never be gated (chicken-and-egg)
- 2026-04-16: Stripe secrets script must use getpass (no echo) and subprocess with capture_output — never echo, cat, or print key values to terminal or command history
- 2026-04-16: ECS containers are stateless — all persistent data lives in RDS, S3, and Secrets Manager. Replacing a container loses nothing. This is why --force-new-deployment is safe.
- 2026-04-16: Docker Desktop is not used for local development but Docker images are still built by GitHub Actions for ECS Fargate deployment — these are separate concerns (local dev vs production deployment)
- 2026-04-16: Local .env POSTGRES_HOST=localhost is stale from Docker era — local backend cannot connect to RDS (private subnet). All migrations and testing must go through ECS or a future bastion host
- 2026-04-16: RDS Multi-AZ should be enabled before taking real subscription payments — single-AZ means a datacenter outage takes down the entire billing system. Queued as M9 pre-launch item.
- 2026-04-17: WebView2 stores cookies in a per-process default user data folder — clearing cookies on a throwaway WebviewController invalidates the Cognito session cookie globally, forcing credential re-entry on next login
- 2026-04-17: User-scoped SharedPreferences keys (user_{userId}_key pattern) prevent preference leakage between accounts on the same device — the pattern applies to any desktop app with multi-account support
- 2026-04-17: Legacy preference migration: copy unscoped key to scoped key for the first user who logs in, then delete the legacy key immediately — second user cannot inherit first user's data
- 2026-04-17: On logout, reset Riverpod providers to defaults but do NOT delete SharedPreferences keys — user's preferences must survive across logout/login cycles. Deletion is the wrong approach; scoping is the right one.
- 2026-04-17: Player bar state (document ID, position) should be saved to user-scoped SharedPreferences before logout and restored on re-login — don't auto-play, just show the document title and position
- 2026-04-17: stay_signed_in must remain device-scoped (not user-scoped) because it governs auto-login behavior at the machine level, regardless of which account is active
- 2026-04-17: Stripe webhook URL must include the full FastAPI router prefix (/api/v1/billing/webhook, not /billing/webhook) — the prefix is defined in main.py app.include_router(prefix='/api/v1') and is easy to miss
- 2026-04-17: stripe.StripeObject does not support .get() — always convert event data to plain dict via json.loads(str(obj)) at the webhook entry point before passing to handlers
- 2026-04-17: audit_log.resource_id is UUID type — never pass Stripe IDs (sub_xxx, cus_xxx) as resource_id. Pass the Psitta user_id (UUID) and put Stripe IDs in details_json
- 2026-04-17: Webhook handler must isolate subscription_events INSERT in an independent database session that commits before the handler runs — if the handler crashes, the forensic event trail survives for manual reprocessing
- 2026-04-17: ON CONFLICT (stripe_event_id) DO NOTHING RETURNING id is the correct atomic idempotency pattern — race-free under concurrent Stripe retries, and RETURNING lets you distinguish 'just inserted' from 'duplicate'
- 2026-04-17: When Settings page and Change Plan screen disagree on the current plan, they are hitting different backend endpoints — always consolidate to a single provider and single endpoint (billingStatusProvider → GET /billing/status)
- 2026-04-17: Legacy API endpoints should be deprecated (not maintained in parallel) once a new endpoint replaces their function — maintaining two sources of truth guarantees they will diverge
- 2026-04-17: Stripe Checkout redirects to success_url after payment — if psitta.ai/billing/success doesn't exist yet, the redirect shows a DNS error page. This is cosmetic (webhook still fires), but confusing for users — build the landing page before go-live
- 2026-04-17: The 000000 code in Stripe sandbox Link verification is printed on screen ('Enter 000000 to continue') — no real SMS is sent in test mode
- 2026-04-17: Creative Nook (not Creativity Nook) is the grammatically correct English name — 'creative' is an adjective, 'creativity' is a noun, and the adjective form parallels 'reading' in Reading Nook
- 2026-04-18: SessionStart hook must scan the DevLogs folder by mtime, not rely solely on the Stop hook's marker — the devlog is created after Claude Code exits, so the marker always points to the previous day's file
- 2026-04-18: Plan enforcement should be a Flutter-side concern using the same billingStatusProvider that drives the Change Plan screen — no need for separate backend middleware when the client can gate UI features directly
- 2026-04-18: Free-to-Pro feature gating pattern: isProUser = (plan != 'free' && status == 'active'). Use this single boolean across all UI gates for consistency
- 2026-04-18: Speed preference clamp on downgrade: an app-level Riverpod listener watches the plan and auto-clamps saved speed to kFreeMaxSpeed if the user is no longer Pro — prevents stale Pro-era settings from persisting
- 2026-04-18: SWH force-off on downgrade: same pattern as speed clamp — app-level listener sets SwhMode.never when plan reverts to free, preventing word highlighting from persisting after subscription ends
- 2026-04-18: Upload limit enforcement: count documents client-side from the library list filtered by created_at in the current month — avoid a separate backend round-trip when the data is already loaded
- 2026-04-18: Hiding menu items (download, archive) is better UX than showing them grayed out for free users — grayed items create frustration, hidden items keep the interface clean
- 2026-04-18: Stripe subscription cancellation can create duplicate customer.subscription.deleted webhook events if multiple subscriptions exist for the same customer — handler must process each independently by stripe_subscription_id
- 2026-04-18: Stripe declined card test (4000 0000 0000 9995) does NOT fire a webhook event — the payment fails at checkout before a subscription is created, so no invoice.payment_failed is sent
- 2026-04-18: psitta.ai domain is registered on AWS Route 53 in the Blowmymind management account (not psitta-prod) — registered March 14, 2026, expires March 14, 2028, auto-renew on
- 2026-04-18: .ai domains do not support WHOIS privacy protection — registrant contact information is always publicly visible
- 2026-04-18: For SaaS product websites, S3 + CloudFront is the correct AWS-native hosting when the domain is already on Route 53 — avoids DNS migration to Cloudflare and keeps all infrastructure in one console
- 2026-04-18: PostHog is preferred over Google Analytics 4 for SaaS products because it includes session replay, heatmaps, and advanced funnels in the free tier — GA4 requires separate paid tools for these capabilities
- 2026-04-18: Claude Code permissions can be broadly scoped via .claude/settings.local.json with 'Read **' and 'Write **' patterns to eliminate all permission prompts within the project directory

## Last Devlog
- **File**: `C:\Users\Admin\OneDrive\_Psitta\Docs\DevLogs\Psitta_DevLog_20260418_M3Complete_F3PlanEnforcement_CancellationFlow_M8Scoping_v1_0.docx`
- **Date**: April 18, 2026
- **Title**: Development Log — April 18, 2026
- **Recent commits** (`git log --oneline -10`):

```
cf9f71b feat(M3): F3 plan enforcement — upload limit dialog, voice lock for free users, speed cap 2x, SWH disabled, download/archive hidden for free plan
70e5b19 fix: SessionStart hook — scan DevLogs folder for newest devlog by mtime, override stale marker when a newer file exists
cd0f1ad fix(M3): update Creative Nook Pro feature copy — AI-powered content ideas
c9b997d fix(M3): consolidate billing providers — single billingStatusProvider for Settings, Library, and Change Plan screens, remove legacy subscriptionSummaryProvider
d1f95bb fix(M3): webhook handler — pass Psitta UUID to audit_log resource_id, isolate subscription_events in independent transaction for crash-safe event storage
20f7dfa feat(M3): Beta billing UI — plan screen with tier names and marketing copy, StripeObject-to-dict webhook fix, Creative Nook rename, user-scoped plan limits
022afe1 fix: user data isolation — scoped preferences by user_id, clear player state on logout, WebView2 cookie clearing, player bar snapshot/restore across sessions, default profile: Parchment/Rachel/1.0x
476b894 feat(M3): billing router — checkout session, subscription status, Stripe webhook with 4 lifecycle handlers, plan enforcement dependencies, plan limits config
8fb4a05 feat(M3): add Stripe SDK, billing config, ORM base, and migration 012 — stripe_customers, subscriptions, subscription_events tables
04fd95c feat: replace protocol-based SessionStart hook with deterministic Python synthesis
```
- _Auto-updated by Stop hook at 2026-04-19 22:22 UTC_

## Further Reading
- `ARCHITECTURE.md` — full system design and component diagram
- `OPEN_CORE_BOUNDARY.md` — what goes in core vs extensions
- `docs/adr/` — architecture decision records
- `docs/TESTING.md` — test strategy
- `CONTRIBUTING.md` — contributor workflow
