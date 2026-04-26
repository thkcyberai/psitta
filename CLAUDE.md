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
- 2026-04-19: Claude Code permission DSL requires `:*` only at the end of a Bash(...) rule. Any character after `:*` causes silent skip at startup. Use Form A (exact), Form B (prefix with trailing :*), or Form C (bash wildcards without :*) — never mix.
- 2026-04-19: Malformed Claude Code permission rules fail silently with only a yellow “Settings Warning” banner. Run `/doctor` to surface all invalid rules, and use a Node one-liner to audit programmatically against engine grammar.
- 2026-04-19: settings.json is the shared baseline (committed); settings.local.json is per-machine (must be gitignored). Claude Code may auto-inject blanket entries into settings.local.json when the operator approves “Yes, and don’t ask again” — periodically reset to empty template to restore discipline.
- 2026-04-19: After any .claude/settings.json change, Claude Code requires a full process restart (close terminal, `claude` again) — no dynamic reload.
- 2026-04-19: .gitignore order matters. A negation rule `!pattern` on a later line overrides an ignore rule on an earlier line. Always verify with `git check-ignore -v` rather than assuming a literal-match grep is sufficient.
- 2026-04-19: AWS Organizations consolidated billing is automatic across every account in an org. Billing is never a reason to collapse workloads into one account — clean separation does not cost extra.
- 2026-04-19: Wildcard ACM cert for `*.psitta.ai` does NOT cover bare `psitta.ai` apex. Always verify SAN list before assuming cert reuse.
- 2026-04-19: For multi-account AWS, cross-account Terraform providers using `assume_role` with scoped IAM roles are the correct pattern. Build it once; repointing role ARN is the only change needed if accounts are reorganized later.
- 2026-04-19: Next.js static export for S3 + CloudFront requires three config values: `output: 'export'`, `trailingSlash: true`, `images.unoptimized: true`. Image optimization requires a Node runtime that static hosting does not provide.
- 2026-04-19: pnpm workspace monorepo pattern: `pnpm-workspace.yaml` at root listing `apps/website`, single root `pnpm-lock.yaml`, shared node_modules via content-addressable store. Add Turborepo only when there are cross-package build dependencies — one app does not justify it.
- 2026-04-19: Big-tech AWS pattern: management account stays empty except billing + SCPs + identity. Operational workloads never live in the management account. Violation of this is common in solo-founder environments and is acceptable tech debt to refactor post-revenue.
- 2026-04-19: Solo-founder priority ordering: (1) ship and generate revenue, (2) maintain sanity, (3) optimize architecture. In that order. Refactoring AWS layouts at 11 pm under fatigue is how DNS outages happen.
- 2026-04-20: AWS CLI on Windows Git Bash requires file://C:\path\format (not /tmp/) for --policy-document and similar parameters. Set MSYS_NO_PATHCONV=1 or use Windows paths explicitly.
- 2026-04-20: jq is not installed on Git Bash Windows by default. AWS CLI JSON output (e.g., from assume-role) parsed via shell export without jq returns empty strings. Subsequent AWS commands then run as the default identity, appearing to succeed but silently wrong. Always cross-check with get-caller-identity after assume-role.
- 2026-04-20: Windows \r carriage-returns contaminate AWS session tokens in shell pipelines. Always pipe through tr -d '\r' when extracting values from AWS JSON on Windows Git Bash before exporting as env vars.
- 2026-04-20: Terraform data sources must have globally unique names per module. data "aws_caller_identity" "current" declared twice causes validate to fail with Duplicate data configuration. Grep existing .tf files before adding new data declarations.
- 2026-04-20: Terraform cross-account provider with assume_role must specify profile (or static credentials) as source identity. Without it, alias inherits shell default credentials — which are typically the WRONG account to assume from. Pattern: profile = "psitta-prod" + assume_role.role_arn = "arn:aws:iam::TARGET:role/..."
- 2026-04-20: Scoped IAM roles that omit route53:ListTagsForResource cause data "aws_route53_zone" lookups to fail with AccessDenied. Use a local constant for the zone ID instead of the data source when minimum-privilege trumps data-source convenience.
- 2026-04-20: GitHub Actions environment: production at job level changes OIDC sub claim from repo:owner/repo:ref:refs/heads/BRANCH to repo:owner/repo:environment:production. IAM trust policies with StringLike conditions on ref: form will reject workflows with environment declared. Either remove environment OR update trust policy to allow both formats.
- 2026-04-20: pnpm/action-setup@v4 with explicit version: N input conflicts with packageManager pnpm@N.M.P in root package.json. Remove the version input or align the two values — don't both specify.
- 2026-04-20: Unauthenticated GitHub CLI exposes workflow run status/step conclusions via anonymous REST API, but not log text. Diagnosis from step timing + known failure patterns (e.g., configure-aws-credentials@v4 retry-to-60s = OIDC denial) is still possible. Run gh auth login for richer debugging.
- 2026-04-20: CloudFront custom_error_response mapping 403→404 requires the target response page (/404.html) to exist in origin. If the mapped page itself 403s, CloudFront returns the original 403 instead of looping. Empty S3 buckets naturally 403, so always upload at least index.html + 404.html before expecting 404-handling to work.
- 2026-04-20: CloudFront distribution creation via Terraform: ~3-4 minutes when reusing an existing ACM cert; 8-12 minutes when provisioning a new cert. Cert reuse is a meaningful speedup for multi-distribution architectures.
- 2026-04-20: Cross-account Terraform with assume_role takes ~30 seconds per resource during apply (STS session per operation). Total apply time is dominated by CloudFront distribution creation, not cross-account overhead.
- 2026-04-20: Windows curl via schannel TLS backend fails with HTTP/0 000 on valid certificates when CRL revocation can't complete. Use curl --ssl-no-revoke as a diagnostic. For CI, use curl-openssl variants instead of bundled schannel curl.
- 2026-04-20: AI image generators (Gemini Nano Banana, DALL-E) produce one PNG per prompt; there is no "multiple separate files in one request" mode. Build brand bundles with a STYLE LOCK paragraph + N sequential prompts pasted one at a time. Trying to request all variants in one prompt yields a composite grid, not individual files.
- 2026-04-20: AI "transparent background" output frequently bakes the checkerboard preview pattern into the PNG as actual pixels. Always verify true alpha channel before treating AI output as transparent — open in Photoshop/GIMP/PIL and inspect, or programmatically check for flat-grey corner colors.
- 2026-04-20: Tailwind v4 shipped a fundamentally different configuration model from v3: CSS-first @theme blocks inside globals.css replaced the v3 JS/TS config file. tailwind.config.ts is ignored in v4 unless explicitly opted in via @config in CSS. When generating Tailwind code for Next.js 16+ projects, always check package.json for tailwindcss version first.
- 2026-04-20: Tailwind v4 @theme block requires CSS variables to use --color-{name}, --font-{name}, --spacing-{name}, --breakpoint-{name} prefix conventions for utility classes to generate correctly. Without the prefix, classes like bg-psitta-700, text-ink-primary are present in HTML but resolve to NO CSS rules. Tailwind emits no error — utilities are silent no-ops. CONFIRM generation worked by inspecting computed styles via DevTools, not by verifying the class name appears in HTML.
- 2026-04-20: When visual CSS changes don't appear to take effect, open DevTools Elements panel and inspect the target element's Styles panel immediately. Crossed-out rules = variable/class doesn't resolve. Don't iterate on code fixes without first confirming the existing CSS is actually being applied. Three rounds of "visual fixes" were wasted tonight on tokens that weren't wired up.
- 2026-04-20: Browser extensions (Speechify, Grammarly, Honey, LastPass) inject DOM nodes at document root on every page. These appear as <div id="extension-name-*"> in DevTools. Not application bugs; but test sites periodically in incognito mode or on a clean browser to see what real visitors see without extensions.
- 2026-04-20: Case-sensitivity mismatch between Windows NTFS (case-insensitive) and Linux (case-sensitive) causes silent CI failures. A folder created as apps/website/public/Brand/ on Windows reads the same as apps/website/public/brand/ locally, but git tracks them separately AND Linux CI will 404 on /brand/ references if git has /Brand/ indexed. Always match case exactly with existing committed paths; verify via git ls-files before staging new files in previously-committed directories.
- 2026-04-20: Pre-existing CI workflows that silently fail for weeks are a common solo-founder tech debt pattern — red badges become background noise when production is deployed via other mechanisms. Queue CI remediation as its own milestone; enabling branch protection requiring green CI to merge prevents future drift.
- 2026-04-21: Pre-push code review via Claude Code saved production: email-validator missing from pyproject.toml would have caused every POST /api/v1/contact to 500. Always run a read-only verification prompt before pushing backend changes to production.
- 2026-04-21: Pydantic v2 EmailStr requires the email-validator package. Add pydantic[email] (not just pydantic) to pyproject.toml when using EmailStr. The import resolves at module load but validation fails at runtime without the package.
- 2026-04-21: ECS container does NOT auto-run alembic on startup. Dockerfile CMD goes straight to uvicorn. Migrations must be run via one-off ECS task: aws ecs run-task with --overrides command override ['alembic', 'upgrade', 'head']. Task definition :3 references :latest tag so new images are pulled automatically.
- 2026-04-21: CORS config in config.py defaults can be overridden by Secrets Manager env vars (Pydantic Settings precedence). Always verify with aws secretsmanager get-secret-value before assuming code defaults take effect in production.
- 2026-04-21: Chrome DevTools mobile device toolbar auto-requests /manifest.json for PWA heuristics. This produces a mobile-only-looking 404 in the Network tab that can be mistaken for a page 404. Always check the actual page request status, not ancillary resource requests.
- 2026-04-21: Build pages one at a time with screenshot verification between each. This catches issues early and keeps commits atomic. The M8b.2 session landed 10 commits over 8 hours with zero production regressions.
- 2026-04-21: Windows curl CRYPT_E_NO_REVOCATION_CHECK error on HTTPS: use --ssl-no-revoke flag in Git Bash. Not a server issue — Windows schannel certificate revocation check fails on some network configs.
- 2026-04-21: Footer mailto link (hello@psitta.ai) was a stale alias not matching the canonical support@psitta.ai. When replacing mailto links with route links, check for address mismatches — stale aliases in footer/header are common.
- 2026-04-22: CloudFront S3 REST origin + OAC does NOT perform directory-index resolution. default_root_object handles only the apex /. Every Next.js static-export site using OAC needs a CloudFront Function to rewrite /path/ to /path/index.html, or the entire site is broken for direct-URL access to subpages. Only the homepage will work. This bug is catastrophic but invisible during in-app navigation because Next.js SPA hydration fetches RSC payloads, not HTML files.
- 2026-04-22: CloudFront cached error responses (403 mapped to 404 via custom_error_response) persist in cache just like success responses. After fixing an origin or function bug that was causing 404s, always invalidate /* to flush the cached error pages — otherwise browsers keep getting the stale 404 until TTL expires.
- 2026-04-22: SessionStart hook's docx-parser matches on exact heading text. A V2 DevLog with heading “5. Key Learnings (append to CLAUDE.md)” was rejected with “no Key Learnings section — skipping.” Future DevLogs must use plain “Key Learnings” as the heading text to match the hook's regex.
- 2026-04-22: Gemini and most AI image generators cannot produce true alpha-channel transparent PNGs. Their “transparent background” output usually has a checkerboard pattern or cream color baked into the pixels. Workaround: use the cream-background version and apply CSS mix-blend-multiply with bg-[matching-color] so the image merges into the page background via blend mode rather than alpha.
- 2026-04-22: Next.js 16 static export requires export const dynamic = “force-static” on route-handler-backed conventions like sitemap.ts and robots.ts. Without it, the build fails with dynamic-route errors. No-op at runtime; pure build-time directive.
- 2026-04-22: Next.js Metadata API has first-class verification fields for google, yandex, me, and yahoo — but NOT bing. For Bing Webmaster Tools verification, use verification.other[“msvalidate.01”] to emit the Microsoft-specific meta tag.
- 2026-04-22: INSERT ... ON CONFLICT (email) DO NOTHING is race-free and anti-enumeration-safe for email capture endpoints. Returning the same success message for new and duplicate submissions prevents attackers from probing for list membership. Cleaner than try/catch IntegrityError — no transaction rollback needed.
- 2026-04-22: IndexNow keys are public by design. They go in plain-text files at the site root and should NOT be stored in password managers. Saving them in project notes or a plain file is appropriate; treating them like secrets is misguided.
- 2026-04-22: In 2026, Bing's index matters more than its raw search-traffic share suggests because ChatGPT and Microsoft Copilot both query Bing, not Google, when their AI agents need web search. Being in Bing's index is table-stakes for being discoverable by AI assistants.
- 2026-04-22: ECS task definition :3 references :latest tag, so new Docker images are pulled automatically on each task run without needing a new task definition revision. Migrations via one-off ECS task (aws ecs run-task --overrides command=["alembic","upgrade","head"]) remain the correct pattern and just work, as long as the new image has been pushed to ECR first.
- 2026-04-23: flutter_native_splash does not support Windows. Use an in-app Flutter widget splash with GoRouter redirect pattern (auth-aware routing to /library or /login) instead.
- 2026-04-23: Cognito Hosted UI CSS only honors documented .xxx-customizable selectors. Generic CSS rules are silently ignored. aws cognito-idp set-ui-customization requires --image-file whenever --css is provided (atomic bundle). CSSVersion timestamp is the cache-buster.
- 2026-04-23: Theme-aware assets in Flutter: use Theme.of(context).brightness == Brightness.dark with a centralized widget like PsittaLogo. Opacity can be conditional on brightness (watermark only on dark themes, full opacity on light themes).
- 2026-04-23: Pillow can generate multi-resolution Windows ICO files directly: img.save(path, format="ICO", sizes=[(16,16),(20,20),(24,24),(32,32),(40,40),(48,48),(64,64),(128,128),(256,256)]). ImageMagick is not required.
- 2026-04-23: git add + git commit without an explicit file list sweeps ALL staged files — backend, frontend, unrelated test fixtures, everything. Use explicit git add <file> <file> per commit for atomic per-commit separation (backend vs frontend vs security).
- 2026-04-23: Riverpod FutureProvider.autoDispose never disposes while ANY listener is mounted. Persistent shell widgets (sidebar, library, settings all watching billingStatusProvider) prevent refresh. Cold restart clears Dart process memory → fresh fetch with a real token → the UI recovers. This masked a latent auth bug for an unknown amount of time.
- 2026-04-23: Dual subscription table architecture is tech debt: user_subscriptions (populated by set_plan_override dev/admin PATCH) is read by the quota enforcer; subscriptions (populated by Stripe webhook) is read by /billing/status. Real Stripe customers without a matching user_subscriptions row will 402 after doc #4 despite being Pro. M9 backlog item: consolidate onto a single table.
- 2026-04-23: Quota counter increments BEFORE the document INSERT commits. Any failure after the counter bump leaves an orphan. luisaao's 50-vs-49 discrepancy was one such orphan. Fix options: (a) same transaction as the INSERT, or (b) replace the counter with SELECT COUNT(*) FROM documents WHERE created_at IN current_month AND status != 'deleted'.
- 2026-04-24: Production Flutter client sending the literal fallback string "dev-bypass-token" on null-storage race. Backend correctly rejected in production (1ms sub-millisecond 401 at JWT parse) but Riverpod cached the 401 forever → silent Free UI for Pro users. Security-critical; the fix removes the string entirely from the production binary, adds refresh+retry on 401, and introduces PlanStatus.unavailable (fail-closed).
- 2026-04-24: CloudWatch latency signature differentiates auth failure from business-logic failure. 1ms 401 = rejected at JWT parse (before handler body ran). 100-400ms 200 = handler ran (JWKS fetch + DB + audit log). When diagnosing auth issues, filter CloudWatch by latency ranges in addition to status codes.
- 2026-04-24: DOCX formatting round-trip requires THREE coordinated changes or the fix is worse than no fix: (1) backend schema accepts formatted_content, (2) client save serializes Quill Delta → block/run JSON, (3) client load deserializes block/run JSON → Quill Delta with attributes. Fixing just one leaves the other paths silently wiping formatting on save or load.
- 2026-04-24: flutter_quill 10.8.x Delta format: Document.toDelta().toList() returns List<Op>. Each Op has .data (string or object) and .attributes (Map<String, dynamic>? or Style). Inline attributes are Attribute.bold, .italic, .underline, .size (for font_size) — keyed as 'size' not 'font_size' in the Delta. Custom key-value attributes via Attribute.fromKeyValue.
- 2026-04-24: pysbd sentence segmentation and the TTS pipeline consume plain text_content only — formatting never affects audio synthesis or alignment. Safe to layer Bold/Italic/Underline/FontSize formatting on top without touching the playback code path.
- 2026-04-24: Quota dialog + banner UX pattern: proactive banner on Library (persistent, X-dismissible, reappears on next app launch if still at limit), disabled action buttons with tooltip priority (unavailable > at-limit > not-Pro > enabled), safety-net dialog for 402 responses that slip through. Replaces cryptic "DioException: bad response" with actionable messaging that shows actual plan, actual usage, and actual reset date.
- 2026-04-24: Surgical production DB writes: use ECS one-off task (same codepath as the app), composite-key WHERE clause enforced by schema natural key, UPDATE.rowcount guard that aborts if != 1, and audit_log append via audit_service.log_event for SOC 2 tamper-evident schema. Before → UPDATE → After re-SELECT → collateral count SELECT for last 30 seconds = 1. Trivially reversible via opposite UPDATE.

## Last Devlog
- **File**: `C:\Users\Admin\OneDrive\_Psitta\Docs\DevLogs\Psitta_DevLog_20260425_M13_3_DownloadBug_CIUnblock_v1_0.docx`
- **Date**: April 25, 2026
- **Recent commits** (`git log --oneline -10`):

```
2b5d14d feat(backend): structured logging of formatted_content structure on chunk update
c77a170 test(backend): skip test_schemas.py — broken imports deferred to M11
e1b7f8a ci: make Lint a warning so downstream jobs run
4ed4686 test(backend): regression guard for /export heading level rendering
cbd5708 fix(desktop): DocumentReadingView renders numbered lists as numbers
0016119 fix(desktop): preserve list_type through DocBlock model and assembler
970a17d feat(desktop): M13.3 headings + bulleted/numbered lists round-trip
7512245 fix(backend): /export reads formatted_content and renders B/I/U/font_size + bullet/numbered lists
e4bc25f fix(desktop): DocumentReadingView now applies run.fontSize
9f8b0d1 fix(desktop): emit font_size as integer-string on load so Quill renders at saved size
```
- _Auto-updated by Stop hook at 2026-04-26 14:12 UTC_

## Further Reading
- `ARCHITECTURE.md` — full system design and component diagram
- `OPEN_CORE_BOUNDARY.md` — what goes in core vs extensions
- `docs/adr/` — architecture decision records
- `docs/TESTING.md` — test strategy
- `CONTRIBUTING.md` — contributor workflow
