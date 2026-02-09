# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.x.x   | ✅ Current development line |

Once Psitta reaches 1.0, we will maintain security patches for the current major and one prior major version.

## Reporting a Vulnerability

**Do NOT open a public issue for security vulnerabilities.**

### Preferred: GitHub Security Advisories

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability**.
3. Fill in the advisory form with as much detail as possible.

### Alternative: Email

Send a detailed report to **security@psitta.dev** with:

- Description of the vulnerability
- Steps to reproduce
- Affected version(s)
- Impact assessment (your best estimate)
- Any suggested fix (optional but appreciated)

### What to Expect

| Timeline | Action |
|----------|--------|
| **24 hours** | Acknowledgment of your report |
| **72 hours** | Initial triage and severity assessment |
| **7 days** | Remediation plan communicated to reporter |
| **30 days** | Fix released (critical), or scheduled for next release (moderate/low) |

We follow [coordinated vulnerability disclosure](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerability_Disclosure_Cheat_Sheet.html). We request a 90-day disclosure window before public disclosure.

### Severity Classification

We use [CVSS v3.1](https://www.first.org/cvss/) for severity scoring:

- **Critical (9.0–10.0)**: Patch within 24–48 hours
- **High (7.0–8.9)**: Patch within 7 days
- **Medium (4.0–6.9)**: Patch in next scheduled release
- **Low (0.1–3.9)**: Tracked and prioritized accordingly

## Security Architecture

### Authentication & Authorization

- All API endpoints require JWT bearer tokens (except `/health` and `/docs`)
- Tokens are validated against the configured OIDC provider (Auth0 / Clerk)
- Role-based access control enforces resource ownership at the service layer
- No secrets are stored in application code; all credentials use environment variables

### Data Protection

- **At rest**: PostgreSQL with encrypted volumes; S3/MinIO server-side encryption
- **In transit**: TLS 1.2+ enforced on all external connections
- **Document TTL**: All uploaded documents auto-expire after a configurable period (default 60 days)
- **PII handling**: Minimal PII collection; audit log tracks all data access

### Infrastructure Security

- Docker containers run as non-root with `no-new-privileges`
- Read-only filesystems in production containers
- Network segmentation via Docker networks (backend services not exposed externally)
- Resource limits on all containers prevent resource exhaustion attacks
- Rate limiting on all API endpoints with stricter limits on upload and auth routes

### Dependency Management

- Nightly automated dependency scans via `pip-audit` and Trivy
- Container images scanned on every build and nightly
- SARIF results uploaded to GitHub Security tab for tracking

### Voice Data & Consent

- Voice profile creation requires explicit consent receipts
- Consent records are permanently retained even if voice profiles are deleted
- Voice recordings are stored in isolated S3 prefixes with per-user access controls

## Security-Sensitive Configuration

These environment variables are security-critical and must use strong, unique values in production:

| Variable | Risk if Compromised |
|----------|-------------------|
| `SECRET_KEY` | Session forgery, token manipulation |
| `POSTGRES_PASSWORD` | Full database access |
| `S3_SECRET_KEY` | Access to all stored documents and audio |
| `AZURE_TTS_KEY` | Unauthorized TTS usage (cost exposure) |
| `ANTHROPIC_API_KEY` | Unauthorized API usage (cost exposure) |
| `AUTH_CLIENT_SECRET` | Authentication bypass |

## Bug Bounty

We do not currently run a formal bug bounty program. We will recognize security researchers in our release notes and CONTRIBUTORS file (with permission).

## Security Contacts

- **Primary**: security@psitta.dev
- **Backup**: Open a GitHub Security Advisory
