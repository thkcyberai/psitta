# Psitta Logging, Security & Compliance Guide — v1.0

**Status:** v1.0 — initial draft
**Owner:** Platform / DevSecOps
**Last reviewed:** 2026-04-14
**Audience:** Backend engineers, platform engineers, future auditors

This guide defines how Psitta logs events, retains them, audits user actions, and meets its security and compliance obligations. It is the source of truth for "what should we log, where does it go, how long do we keep it, and what proves it to an auditor."

---

## 1. Purpose & Scope

Psitta handles user documents (potentially sensitive), TTS synthesis (consumes metered third-party credits), and authentication state backed by Amazon Cognito. The backend runs on AWS ECS Fargate with a single PostgreSQL database, and the desktop client ships as a Windows MSIX.

This document covers:

- Runtime logging (structlog → CloudWatch) — structure, retention, access
- Audit logging (`audit_log` database table) — which events, what shape, who can read/write
- Security event logging — auth failures, rate-limit trips, suspected abuse
- Compliance posture — SOC 2 §CC7.2 alignment and gaps
- Code-author conventions — what to log, what never to log, and how

It explicitly **does not** cover:

- Flutter desktop client telemetry (no opt-in client-side analytics pipeline exists yet)
- Database-level backup and recovery (see `docs/adr/` when those ADRs land)
- Stripe / billing logs (M3, blocked on EIN)

---

## 2. Current State Snapshot

As of 2026-04-14, the backend has the skeleton of a defensible logging posture but the wiring is incomplete. This section summarizes what exists today so the gap analysis below is concrete.

### 2.1 Runtime logging pipeline

- **Library**: `structlog` (63 occurrences across 23 files). Every service, provider, middleware, worker, and route module imports it.
- **Renderer**: JSON, one object per line. Configured in `core/backend/src/psitta/main.py:_configure_logging`. Pipeline: `merge_contextvars` → `filter_by_level` → `add_logger_name` → `add_log_level` → `PositionalArgumentsFormatter` → `TimeStamper(fmt="iso")` → `StackInfoRenderer` → `UnicodeDecoder` → `JSONRenderer`.
- **Root log level**: `settings.LOG_LEVEL`, defaults to `INFO`.
- **Transport**: ECS awslogs driver → CloudWatch. Configured in `infra/terraform/ecs.tf:102-108`, log group `/ecs/psitta-api`.
- **Request correlation**: `middleware/request_id.py` binds `request_id` into structlog context vars per request (UUID4, or a validated client-provided value). Every downstream log line inherits the ID.
- **OTel**: traces are instrumented (`opentelemetry-instrumentation-fastapi`, `opentelemetry-instrumentation-sqlalchemy`), but **logs are not shipped through OTel** and are not correlated to spans via `trace_id`/`span_id`.

### 2.2 What is logged today

| Middleware / module | Events | Level |
|---|---|---|
| `middleware/request_id.py` | `request.started`, `request.completed` | DEBUG (not shipped at prod `LOG_LEVEL=INFO`) |
| `middleware/auth.py` | `auth.jwks.fetch`, `auth.validated`, `auth.dev_bypass`, `auth.token.expired`, `auth.token.claims_error`, `auth.token.invalid` | INFO / WARNING |
| `middleware/rate_limit.py` | `rate_limit.exceeded`, `rate_limit.error`, `rate_limit.token_decode_failed` | WARNING / DEBUG |
| `providers/tts_router.py` | `tts_router.ok`, `tts_router.fallback`, provider-specific failures | INFO / WARNING |
| `workers/document_processor.py` | Pipeline stage transitions | INFO |
| `services/audit_service.py` | `audit.logged` (mirror of a DB insert, no details payload) | INFO |

### 2.3 Audit table

- **Schema** (`db/migrations/versions/001_initial_schema.py:161-173`):
  ```
  audit_log(
      id           UUID primary key,
      user_id      UUID nullable,
      action       VARCHAR(100),
      resource_type VARCHAR(50),
      resource_id  UUID nullable,
      details_json JSONB default '{}',
      ip_address   VARCHAR(45),
      created_at   TIMESTAMPTZ default NOW()
  )
  -- indexes: (user_id), (action), (created_at)
  ```
- **Service**: `services/audit_service.py` exposes `log_event(db, action, resource_type, user_id, resource_id, details, ip_address)`. Raw SQL `INSERT` into `audit_log`, plus a mirror `audit.logged` structlog line (which loses `details_json`).
- **Call sites**: 2, both in `api/v1/auth.py` — user login and user logout. No other route in `api/v1/*.py` calls `log_event()`.

### 2.4 CloudWatch retention

- Single log group `/ecs/psitta-api`, `retention_in_days = 30` (`infra/terraform/ecs.tf:17-19`).
- No S3 archival, no Kinesis Firehose, no cold-storage lifecycle.
- No separate log stream for audit / security events — everything intermingles.

### 2.5 Alarms & metric filters

Out of scope for this audit — not verified. Treat as "unknown, probably none" until Phase 2 of the roadmap verifies.

---

## 3. Target State

### 3.1 Principles

1. **Every security-relevant action is audited in a tamper-evident store.** Auth, authorization, document lifecycle, subscription changes, admin actions. No action that a customer might later need to investigate should be invisible.
2. **Retention meets the longest compliance obligation Psitta is subject to**, currently SOC 2 §CC7.2 (≥ 12 months of audit data, typically).
3. **Logs are correlated end-to-end** by `request_id` (already) and eventually by OTel `trace_id` so a single customer-facing incident can be reconstructed from one query.
4. **No secrets, no raw PII in logs.** Access tokens, passwords, Azure/ElevenLabs API keys, full email bodies, full document contents never land in CloudWatch. Structured keys like `email` and `sub` are allowed but treated as sensitive data (access controlled).
5. **Logging cannot break the request path.** Every log call site is best-effort; no audit write is allowed to propagate an exception to the user.
6. **Operational logs and audit logs are separated.** One store can be aggressively filtered and rotated; the other is compliance-grade and near-immutable.

### 3.2 Required capabilities

| Capability | Target |
|---|---|
| Per-request access log in prod | INFO-level `request.completed` with method, path, status, latency_ms, user_id |
| Audit event coverage | Login, logout, token refresh, doc upload, doc delete, doc archive, doc resynth, project create/delete, subscription/plan change, admin plan override, user profile update, voice profile assignment, rate-limit trip above threshold |
| Audit retention | ≥ 365 days, tamper-evident |
| Operational log retention | 30 days hot (CloudWatch) + 335 days cold (S3 / Glacier), searchable via Athena |
| PII / secrets | Scrubbed at the structlog processor layer, not per call site |
| Alerting | CloudWatch metric filters + alarms on `auth.token.invalid` rate spike, `rate_limit.exceeded` rate spike, 5xx rate, `audit.write.failed` non-zero |
| Access control | IAM policy grants "read audit stream" to a distinct principal set from "read app stream" |

---

## 4. Gap Analysis

Severity is a combination of audit exposure (SOC 2), security exposure, and operational risk.

| # | Gap | Severity | Evidence | Remediation |
|---|---|---|---|---|
| G1 | CloudWatch retention is 30 days — too short for SOC 2 evidence window | **High** | `ecs.tf:19` | Add S3 export bucket with 12-month retention + Athena table. Keep CloudWatch hot at 30 days for fast search. |
| G2 | `audit_log` table has ~2 active call sites, ~30+ security-relevant actions go unaudited | **High** | Grep of `log_event(` returns only 2 real callers, both in `api/v1/auth.py` | Wire `log_event` into documents, projects, subscriptions, users routes. See §7 for the event catalog. |
| G3 | `audit_log` has no tamper-evidence — a compromised DB role with `DELETE`/`UPDATE` on the table can erase its tracks | **High** | `001_initial_schema.py` defines the table as a plain PK, no constraint / trigger / grant revocation | (a) Revoke `UPDATE` / `DELETE` from app role via migration, or (b) add a per-row hash chain, or (c) ship every write to S3 Object Lock in parallel. (a) is cheapest and closes the majority of the risk. |
| G4 | Per-request access log is at DEBUG, invisible in prod | **Medium** | `request_id.py:60-65, 72-77` emit at `logger.debug` | Promote `request.completed` to INFO; add latency_ms and user_id fields. Keep `request.started` at DEBUG to avoid duplicate lines. |
| G5 | No PII / secret scrubbing in the structlog pipeline | **Medium** | `main.py:_configure_logging` has no scrubber processor; `auth.validated` logs raw `email` | Add a structlog processor that redacts known sensitive keys (`password`, `token`, `authorization`, `api_key`, `secret`, `set-cookie`). Allow-list `sub`, `user_id`, `email` but hash-tag `email`. |
| G6 | Audit events live in the same Postgres as business data — single compromise erases both | **Medium** | `audit_service.log_event()` only writes to local DB | Emit a parallel structlog line with the full `details_json` so CloudWatch has a shadow copy. Then wire S3 export (G1) so the shadow survives longer than 30 days. |
| G7 | Rate-limit trips not written to `audit_log` | **Low-Medium** | `rate_limit.py` logs to structlog only | Add an `audit_service.log_event` call with `action="rate_limit.exceeded"` when a user (not IP) hits a limit. Skip IP-keyed trips to avoid log flooding on probe traffic. |
| G8 | Worker pipeline failures unaudited | **Low-Medium** | `workers/document_processor.py` uses structlog only | Add `log_event` call on terminal document failure states (`FAILED`, `TIMEOUT`) so "why did my doc processing fail" has a durable answer. |
| G9 | Single log stream for app + audit + security | **Medium** | `ecs.tf:17-19` defines one log group | Split into `/ecs/psitta-api/app`, `/ecs/psitta-api/audit`, `/ecs/psitta-api/security`. Route via structlog processor that selects the stdlib logger name based on event name prefix. |
| G10 | No OTel log exporter; traces and logs don't join | **Low** | `pyproject.toml` has trace instrumentation, no log exporter | Add `opentelemetry-exporter-otlp-proto-grpc` log exporter later when a backend like Grafana Tempo / Honeycomb exists. Not a v1.0 blocker. |
| G11 | No documented alarms / metric filters | **Unknown** | Terraform has no `aws_cloudwatch_metric_alarm` matches for logging | Verify in Phase 2. If absent, add at minimum: 5xx rate, `auth.token.invalid` rate, `rate_limit.exceeded` rate, `audit.write.failed` non-zero. |

---

## 5. Remediation Roadmap

Phased so each phase delivers a defensible increment. "Effort" is rough calendar days for one engineer; "Owner" is the team hat, not a person.

### Phase 1 — Foundations (target: close Highs)

| Task | Gap | Effort | Owner |
|---|---|---|---|
| Set CloudWatch `retention_in_days = 90` (interim) and plan S3 export | G1 | 0.5d | DevSecOps |
| Add S3 export bucket `psitta-prod-logs-archive` with 365-day lifecycle | G1 | 1d | DevSecOps |
| Write migration revoking `UPDATE` / `DELETE` on `audit_log` from the app role | G3 | 0.5d | Backend |
| Add `log_event` calls to document upload / delete / archive / resynth | G2 | 1d | Backend |
| Add `log_event` calls to project create / delete | G2 | 0.5d | Backend |
| Add `log_event` calls to user profile update / plan change | G2 | 0.5d | Backend |

**Exit criteria for Phase 1:** SOC 2 sample evidence request ("show me every document deletion for user X in the last 6 months") can be answered by a single `SELECT` on `audit_log`.

### Phase 2 — Operational Visibility

| Task | Gap | Effort | Owner |
|---|---|---|---|
| Promote `request.completed` to INFO with latency_ms + user_id | G4 | 0.5d | Backend |
| Add structlog PII/secret scrubber processor | G5 | 1d | Backend |
| Split CloudWatch log group into app / audit / security streams | G9 | 1d | DevSecOps + Backend |
| Audit `log_event` → parallel structlog emit with full `details_json` | G6 | 0.5d | Backend |
| Audit existing CloudWatch alarms; add missing metric filters | G11 | 1d | DevSecOps |

### Phase 3 — Compliance Depth

| Task | Gap | Effort | Owner |
|---|---|---|---|
| Wire rate-limit trips into `audit_log` (user-keyed only) | G7 | 0.5d | Backend |
| Wire worker terminal failures into `audit_log` | G8 | 0.5d | Backend |
| Add OTel log exporter + trace-log correlation | G10 | 2d | Backend |
| SOC 2 evidence dry-run with external auditor | — | 3d | Compliance |

---

## 6. Runtime Logging Standards

For engineers writing new code.

### 6.1 Do

- Use `structlog.get_logger(__name__)` at module top. Never `print()`, never `logging.getLogger()` directly.
- Name events as dotted lowercase, subject-first: `document.uploaded`, `user.login`, `tts.synth.ok`, `rate_limit.exceeded`. The name is queryable in CloudWatch Logs Insights; drift here breaks dashboards.
- Pass structured key-value pairs, not interpolated strings. `logger.info("document.uploaded", document_id=str(doc.id), size_bytes=size)` — **never** `logger.info(f"Uploaded {doc.id} ({size} bytes)")`.
- Include `user_id` on any log line that is attributable to a specific user, so incident queries can filter by user.
- Use `logger.warning` for recoverable but noteworthy conditions (rate-limit hit, provider fallback, JWT expiry), `logger.error` only when something is genuinely broken and needs human attention.
- Prefer `logger.exception("foo.failed", ...)` inside `except` blocks — it captures the traceback.

### 6.2 Don't

- **Never log secrets**: access tokens, refresh tokens, passwords, Azure / ElevenLabs / Anthropic API keys, `Authorization` header contents, `Set-Cookie` values, Stripe signing secrets.
- **Never log raw request / response bodies** if they might contain user document content. Log shape, not content: `bytes=1234`, `pages=42`, not the text.
- **Never log PII payloads beyond what's necessary**: email is allowed on login events, but a log line with `email=` in an unrelated context is a leak. If in doubt, use `user_id` (UUID) instead.
- **Never let a logging or audit call raise into the request path.** Wrap with try/except and log the failure through a different logger if it fails. A broken audit write must not break a successful business action. (The current `audit_service.log_event` does *not* satisfy this — see G2 remediation.)
- **Never commit log lines that trigger the `structlog` exception formatter on tracebacks containing secrets.** If you catch an exception from a provider call, scrub before logging.

### 6.3 Audit vs. structlog decision rule

- **Audit (`audit_service.log_event`)** — something a user did that a customer, auditor, or incident responder might later ask about. Durable, indexed, subject to retention SLAs.
- **Structlog (`logger.info/.warning/.error`)** — operational telemetry: system health, performance, debugging, provider behavior. Rotates on operational schedule.
- If an event belongs in both, call both. The audit write is the record; the structlog line is the shadow.

---

## 7. Audit Event Catalog

Events that should exist in `audit_log`. Phase 1 lands the **bold** rows.

| Action | Resource type | Triggered in | Phase |
|---|---|---|---|
| `user.login` | user | `api/v1/auth.py` (exists) | 0 (done) |
| `user.logout` | user | `api/v1/auth.py` (exists) | 0 (done) |
| **`user.token_refresh`** | user | `api/v1/auth.py` | 1 |
| **`document.uploaded`** | document | `api/v1/documents.py:upload_document` | 1 |
| **`document.deleted`** | document | `api/v1/documents.py:delete_document` | 1 |
| **`document.archived`** | document | `api/v1/documents.py:archive_document` | 1 |
| **`document.resynthesized`** | document | `api/v1/documents.py:resynthesize_document` | 1 |
| **`document.chunk_resynthesized`** | document | `api/v1/documents.py:resynthesize_chunk` | 1 |
| **`project.created`** | project | `api/v1/projects.py` | 1 |
| **`project.deleted`** | project | `api/v1/projects.py` | 1 |
| **`user.plan_changed`** | user | `api/v1/users.py` | 1 |
| `user.profile_updated` | user | `api/v1/users.py` | 2 |
| `voice.assigned` | user | `api/v1/voices.py` | 2 |
| `rate_limit.exceeded` | user | `middleware/rate_limit.py` | 3 |
| `document.processing_failed` | document | `workers/document_processor.py` | 3 |
| `admin.plan_override` | user | `api/v1/users.py` (`PATCH /users/me/plan` — M3 replacement path) | 3 |

### 7.1 `details_json` conventions

- Always serializable via `json.dumps(default=str)`.
- Never include secrets, tokens, or full document content.
- Include enough to reconstruct "what happened" without hitting other tables: for `document.uploaded`, include `filename`, `size_bytes`, `mime_type`; for `document.resynthesized`, include `voice_id`, `speed`, `chunk_count`.

---

## 8. Operational Procedures

### 8.1 Retention

- **CloudWatch (hot)**: 30 days today → 90 days after Phase 1 → 30 days + S3 export after Phase 1 completes.
- **S3 archive (cold)**: 365 days after Phase 1 lands, with Object Lock in compliance mode for the audit stream (tamper-evidence).
- **`audit_log` table**: retained for the life of the database. Row-level cleanup is explicitly disallowed — see G3 remediation.

### 8.2 Access control

- **Read access to CloudWatch log groups**: SSO group `platform-oncall` only. Grant requires business justification and is audited by AWS CloudTrail.
- **Read access to `audit_log` table**: separate read-only DB role, not the app role. Grant by ticket.
- **Write access to `audit_log`**: app role only, `INSERT` grant only. `UPDATE` and `DELETE` revoked.

### 8.3 Incident response

When an incident is declared:

1. Query `audit_log` by `user_id` and time window for the affected customer(s).
2. Query CloudWatch Logs Insights for the same `request_id`(s) to reconstruct the request sequence.
3. If the incident predates CloudWatch's hot window, query the S3 archive via Athena (post-Phase 1).
4. Preserve evidence by exporting relevant rows and log lines to a case bucket with Object Lock.
5. File the incident report referencing `audit_log.id` values so the evidence chain is reproducible.

### 8.4 Secrets hygiene

If a secret ever lands in CloudWatch (e.g., an accidentally-logged Authorization header):

1. Rotate the secret immediately (do not wait for log cleanup).
2. File a CloudTrail-traced request to AWS Support to expunge the affected log stream if the exposure is severe.
3. Add a regression test or redaction rule so it cannot recur.

This procedure also applies to secrets pasted into chat or any other transient sink. See Key Learnings in `CLAUDE.md` — "Secrets exposed in chat must be rotated immediately — never paste API keys into Claude.ai chat."

---

## 9. Appendix

### 9.1 Code references

- `core/backend/src/psitta/main.py` — structlog pipeline (`_configure_logging`)
- `core/backend/src/psitta/middleware/request_id.py` — request correlation
- `core/backend/src/psitta/middleware/auth.py` — auth events
- `core/backend/src/psitta/middleware/rate_limit.py` — rate-limit events
- `core/backend/src/psitta/services/audit_service.py` — audit write entry point
- `core/backend/src/psitta/db/migrations/versions/001_initial_schema.py` — `audit_log` schema
- `core/backend/src/psitta/api/v1/auth.py` — existing audit call sites
- `infra/terraform/ecs.tf` — CloudWatch log group + awslogs driver

### 9.2 Out of scope for v1.0

- Flutter desktop client telemetry
- Database backup / disaster recovery
- Stripe / billing event logging (blocked on M3 EIN)
- CloudTrail analysis for AWS API-level audit (separate domain)

### 9.3 Related documents

- `ARCHITECTURE.md` — system component diagram
- `OPEN_CORE_BOUNDARY.md` — what goes in core vs extensions
- `docs/TESTING.md` — test strategy
- `CONTRIBUTING.md` — contributor workflow
- `CLAUDE.md` — Infrastructure State, M7 Security Hardening Status, Key Learnings

---

## 10. Change Log

| Version | Date | Change | Author |
|---|---|---|---|
| 1.0 | 2026-04-14 | Initial draft, derived from the logging / audit state audit on the same date | Platform |
