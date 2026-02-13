# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report security issues via [GitHub Security Advisories](https://github.com/psitta/psitta/security/advisories/new).

You will receive a response within 48 hours. We will work with you to understand the issue and coordinate a fix before public disclosure.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.x (current) | ✅ |

## Security Practices

- All secrets are stored as environment variables (never committed)
- Database credentials use `SecretStr` — never logged or serialized
- Pre-signed URLs with short TTL for all S3 object access
- Rate limiting on all API endpoints
- Input validation via Pydantic strict schemas
- SQL injection prevention via parameterized SQLAlchemy queries
- CORS restricted to configured origins
- Non-root Docker containers
- Dependency scanning via Dependabot and nightly security workflow
- Pre-commit hooks detect private keys before commit

## Scope

This security policy covers:
- `core/backend/` — API server and worker
- `apps/desktop/` — Flutter application
- `.github/workflows/` — CI/CD pipelines
- `docker-compose.yml` — Infrastructure configuration
