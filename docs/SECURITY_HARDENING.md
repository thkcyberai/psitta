# Psitta — Security Hardening Guide

## 1. Threat Model

### 1.1 Assets

| Asset | Classification | Impact if Compromised |
|-------|---------------|----------------------|
| User documents (PDFs, DOCX) | Confidential | Data breach, privacy violation |
| Generated audio files | Internal | Unauthorized access to paid content |
| Database credentials | Secret | Full system compromise |
| API keys (Azure, Anthropic) | Secret | Financial abuse, service disruption |
| User authentication tokens | Secret | Account takeover |
| Playback session state | Internal | Minor privacy leak |

### 1.2 Threat Actors

| Actor | Motivation | Capability |
|-------|-----------|------------|
| Unauthenticated attacker | Data theft, service abuse | Network access, automated tools |
| Authenticated malicious user | Free tier abuse, data exfiltration | Valid credentials, API access |
| Compromised dependency | Supply chain attack | Code execution in build/runtime |
| Insider (developer) | Accidental exposure | Repository and infrastructure access |
| Automated bot | Resource exhaustion, scraping | High volume, distributed |

### 1.3 Attack Surface
```
Internet
  │
  ├─► API Gateway / Load Balancer
  │     ├─► FastAPI Server (port 8000)
  │     │     ├─► /api/v1/* endpoints
  │     │     ├─► /health, /ready probes
  │     │     └─► /docs (Swagger — disabled in production)
  │     └─► Static assets (CDN)
  │
  ├─► Flutter App (client-side)
  │     ├─► API calls over HTTPS
  │     ├─► Local token storage
  │     └─► Audio playback cache
  │
  └─► GitHub (CI/CD)
        ├─► Actions workflows
        ├─► Container registry (GHCR)
        └─► Dependabot / security scanning
```

### 1.4 STRIDE Analysis

| Threat | Category | Mitigation |
|--------|----------|------------|
| Spoofed API requests | **S**poofing | JWT authentication, CORS restriction |
| Modified document content | **T**ampering | Checksums on upload, signed storage URLs |
| Credential exposure in logs | **I**nformation Disclosure | SecretStr, structured logging filters |
| Excessive TTS consumption | **D**enial of Service | Rate limiting, tier-based quotas |
| User data cross-access | **E**levation of Privilege | user_id scoping on all DB queries |
| Repudiation of actions | **R**epudiation | Audit log with IP, user_id, timestamp |

---

## 2. Authentication & Authorization

### 2.1 Authentication Flow
```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Flutter  │───▶│ Auth     │───▶│ Identity │───▶│ Psitta   │
│ App      │    │ Provider │    │ Provider │    │ API      │
│          │◀───│ (Auth0/  │◀───│ (Google/ │    │          │
│          │    │  Clerk)  │    │  Apple)  │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │                                               │
     │          JWT (access_token)                    │
     └──────────────────────────────────────────────▶│
                                                     │
                                               Validate JWT
                                               Extract user_id
                                               Check tier/permissions
```

**Design decisions:**
- Authentication is delegated to Auth0 or Clerk (not built in-house)
- JWT tokens are validated on every request using the provider's JWKS endpoint
- Refresh tokens are handled client-side (Flutter secure storage)
- The Psitta API never sees or stores user passwords

### 2.2 Authorization Model
```
User (tier: free | pro | enterprise)
  │
  ├── Own documents (CRUD — scoped by user_id)
  ├── Own playback sessions (CRUD — scoped by user_id)
  ├── Own voice preferences (CRUD — scoped by user_id)
  │
  └── Tier-gated features:
      ├── free:       5 documents, standard voices, 50 pages/doc
      ├── pro:        50 documents, premium voices, 500 pages/doc
      └── enterprise: unlimited, voice cloning, SSO, audit export
```

**Enforcement points:**
- API routes: FastAPI dependency checks `current_user.tier`
- Database: every query includes `WHERE user_id = :current_user_id`
- Storage: pre-signed URLs scoped to user's storage prefix
- Worker: processes only documents owned by the requesting user

### 2.3 Token Validation
```python
# Pseudocode — JWT validation in FastAPI dependency
async def get_current_user(
    authorization: str = Header(...),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    token = authorization.removeprefix("Bearer ")

    # 1. Decode and verify signature (RS256 via JWKS)
    payload = jwt.decode(
        token,
        key=jwks_client.get_signing_key(token),
        algorithms=["RS256"],
        audience=settings.AUTH_AUDIENCE,
        issuer=settings.AUTH_ISSUER,
    )

    # 2. Extract user identity
    external_id = payload["sub"]

    # 3. Lookup or create internal user record
    user = await user_service.get_or_create(external_id)

    return user
```

---

## 3. Secret Management

### 3.1 Secret Inventory

| Secret | Storage | Rotation Frequency | Access |
|--------|---------|-------------------|--------|
| `DATABASE_PASSWORD` | Environment variable | 90 days | API server, worker, migration |
| `REDIS_PASSWORD` | Environment variable | 90 days | API server, worker |
| `AWS_ACCESS_KEY_ID` | Environment variable | 90 days | API server, worker |
| `AWS_SECRET_ACCESS_KEY` | Environment variable | 90 days | API server, worker |
| `AZURE_TTS_KEY` | Environment variable | 90 days | Worker (TTS provider) |
| `ANTHROPIC_API_KEY` | Environment variable | 90 days | Worker (vision provider) |
| `SECRET_KEY` | Environment variable | On compromise | API server (session signing) |
| `GITHUB_TOKEN` | GitHub Actions | Auto-rotated | CI/CD only |

### 3.2 Secret Handling Rules

1. **Never commit secrets** — `.env` is gitignored, `.env.example` uses `CHANGE-ME` placeholders
2. **SecretStr everywhere** — Pydantic `SecretStr` prevents accidental logging or serialization
3. **No secrets in URLs** — database URLs constructed from components, not interpolated
4. **No secrets in Docker images** — passed via environment at runtime, never baked in
5. **CI secrets via GitHub Secrets** — encrypted at rest, masked in logs

### 3.3 Rotation Procedure
```bash
# 1. Generate new credential
NEW_PASSWORD=$(python -c "import secrets; print(secrets.token_urlsafe(32))")

# 2. Update in secret manager / environment
# (AWS SSM, Vault, or .env for development)

# 3. Rolling restart (zero-downtime)
docker compose -f docker-compose.yml -f compose.prod.yml up -d --no-deps api
docker compose -f docker-compose.yml -f compose.prod.yml up -d --no-deps worker

# 4. Verify health
curl -f http://localhost:8000/ready

# 5. Revoke old credential
# (Update PostgreSQL password, rotate API keys, etc.)
```

---

## 4. Input Validation & Sanitization

### 4.1 API Input

| Input | Validation | Defense |
|-------|-----------|---------|
| Document upload (file) | Max 50MB, allowed MIME types only | Prevents resource exhaustion, malicious files |
| Document title | Max 500 chars, stripped whitespace | Prevents XSS in downstream rendering |
| Voice ID | Must match catalog enum | Prevents injection via provider APIs |
| Speed | Float 0.5–3.0, validated by Pydantic | Prevents abuse of TTS resources |
| UUID parameters | Strict UUID v4 format | Prevents SQL injection via path params |
| Pagination | limit 1–100, offset >= 0 | Prevents unbounded queries |

### 4.2 File Upload Security
```python
# Enforced in documents.py upload endpoint
ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/epub+zip",
    "text/plain",
}
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB

# Validation chain:
# 1. Content-Type header check
# 2. File size check (streaming, not buffered)
# 3. Magic bytes verification (first 8 bytes)
# 4. Filename sanitization (strip path traversal)
```

### 4.3 SSML Injection Prevention

Text sent to Azure TTS is wrapped in SSML. User content is XML-escaped to prevent SSML injection:
```python
import xml.sax.saxutils as saxutils
safe_text = saxutils.escape(user_text)  # Escapes <, >, &, ", '
```

---

## 5. Infrastructure Security

### 5.1 Container Hardening

| Control | Implementation |
|---------|---------------|
| Non-root user | `USER appuser` (UID 1001) in Dockerfile |
| Minimal base | `python:3.12-slim` — no dev tools in runtime |
| Read-only filesystem | Source mounted as `:ro` in dev compose |
| No capabilities | `--cap-drop=ALL` in production compose |
| Resource limits | CPU/memory limits in `compose.prod.yml` |
| Health checks | HTTP health check in Dockerfile + compose |

### 5.2 Network Security

| Control | Implementation |
|---------|---------------|
| CORS | Restricted to configured origins only |
| HTTPS | Enforced at load balancer / reverse proxy |
| Internal services | No public ports for Postgres, Redis, MinIO |
| Rate limiting | Token bucket per client (IP or user_id) |
| Request size | 50MB max body, enforced at FastAPI level |

### 5.3 Database Security

| Control | Implementation |
|---------|---------------|
| Connection encryption | SSL mode required in production |
| Statement timeout | 30s default (prevents long-running queries) |
| Lock timeout | 10s (prevents deadlock starvation) |
| Connection pooling | Max pool size + overflow limits |
| Parameterized queries | SQLAlchemy ORM — no raw string interpolation |
| Credential isolation | SecretStr, not in connection URL logs |

---

## 6. OWASP Top 10 Mapping

| # | OWASP Category | Psitta Mitigation |
|---|---------------|-------------------|
| A01 | Broken Access Control | user_id scoping on all queries, tier-based authorization |
| A02 | Cryptographic Failures | SecretStr, HTTPS enforced, S3 server-side encryption |
| A03 | Injection | Pydantic strict schemas, SQLAlchemy ORM, SSML escaping |
| A04 | Insecure Design | Protocol-based providers, defense-in-depth, threat modeling |
| A05 | Security Misconfiguration | .env.example, Swagger disabled in prod, secure defaults |
| A06 | Vulnerable Components | Dependabot, pip-audit, Trivy nightly scans |
| A07 | Auth Failures | Delegated to Auth0/Clerk, JWT RS256, token expiry |
| A08 | Data Integrity Failures | File checksums, signed URLs, audit log |
| A09 | Logging Failures | Structured logging, secret filtering, audit trail |
| A10 | SSRF | No user-controlled URLs in backend calls, allowlist for providers |

---

## 7. Incident Response

### 7.1 Severity Levels

| Level | Description | Response Time | Example |
|-------|------------|--------------|---------|
| P0 — Critical | Active exploitation, data breach | < 1 hour | Credential leak, SQL injection |
| P1 — High | Exploitable vulnerability found | < 4 hours | Auth bypass, privilege escalation |
| P2 — Medium | Potential vulnerability | < 24 hours | Dependency CVE, misconfiguration |
| P3 — Low | Hardening improvement | Next sprint | Missing header, logging gap |

### 7.2 Response Procedure

1. **Detect** — automated scanning, user report, or monitoring alert
2. **Contain** — isolate affected service, rotate compromised credentials
3. **Assess** — determine scope, affected users, data exposure
4. **Fix** — patch vulnerability, deploy fix
5. **Notify** — affected users if data exposed (per policy)
6. **Review** — post-incident review, update threat model

### 7.3 Reporting

Security vulnerabilities should be reported via [GitHub Security Advisories](https://github.com/psitta/psitta/security/advisories/new) — never as public issues.

---

## 8. Compliance Considerations

| Requirement | Approach |
|-------------|----------|
| GDPR (data privacy) | User data scoped and deletable, document TTL auto-expiry |
| SOC 2 (security controls) | Audit log, access controls, encrypted storage |
| HIPAA (if health docs) | Not currently in scope — would require BAA with providers |
| PCI DSS (payments) | Payment processing delegated to Stripe (never touches card data) |

---

## 9. Security Checklist (Pre-Production)

- [ ] Auth provider configured (Auth0 or Clerk)
- [ ] All `CHANGE-ME` values in `.env` replaced with real secrets
- [ ] `SECRET_KEY` generated with `secrets.token_urlsafe(32)`
- [ ] HTTPS enforced at load balancer
- [ ] Swagger UI disabled in production (`ENVIRONMENT=production`)
- [ ] CORS origins restricted to production domains
- [ ] Database SSL mode enabled
- [ ] Redis password set
- [ ] S3 bucket policy: private, no public access
- [ ] Rate limiting configured per tier
- [ ] Dependabot enabled on GitHub repo
- [ ] Security scanning workflow (`security.yml`) active
- [ ] CODEOWNERS file restricts `extensions/` and security files
- [ ] Pre-commit hooks detect private keys
- [ ] Container images scanned with Trivy before deploy
- [ ] Audit log retention policy configured
