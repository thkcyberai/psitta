# Contributing to Psitta

Thank you for your interest in contributing to Psitta! This guide will help you get started.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Architecture Overview](#architecture-overview)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Open-Core Boundary](#open-core-boundary)

## Code of Conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold a welcoming and inclusive environment.

## Getting Started

### Prerequisites

- Python 3.12+
- Flutter 3.24+
- Docker & Docker Compose
- Git

### Development Setup

```bash
# 1. Clone the repository
git clone https://github.com/psitta/psitta.git
cd psitta

# 2. Copy environment configuration
cp .env.example .env
# Edit .env with your local settings (defaults work for most cases)

# 3. Start infrastructure
docker compose up -d postgres redis minio
docker compose up minio-init   # One-time bucket creation

# 4. Run database migrations
docker compose --profile migrate up migrate

# 5. Backend setup
cd core/backend
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -e ".[dev]"

# 6. Start the API server
uvicorn psitta.main:create_app --factory --reload

# 7. Flutter setup (separate terminal)
cd apps/mobile
flutter pub get
flutter run
```

### Verifying Your Setup

```bash
# Backend health check
curl http://localhost:8000/health

# Run backend tests
cd core/backend && pytest

# Run Flutter tests
cd apps/mobile && flutter test
```

## Architecture Overview

```
psitta/
├── core/backend/          # FastAPI + async PostgreSQL + Redis Streams
│   └── src/psitta/
│       ├── api/           # Route handlers (thin controllers)
│       ├── services/      # Business logic layer
│       ├── providers/     # External service abstractions (S3, TTS, etc.)
│       ├── models/        # Domain models
│       ├── schemas/       # Pydantic request/response schemas
│       ├── middleware/     # Request ID, rate limiting
│       ├── workers/       # Background job processors
│       └── db/            # Alembic migrations
├── apps/mobile/           # Flutter cross-platform client
├── extensions/            # Commercial add-ons (separate license)
└── docs/                  # Architecture decisions, API docs
```

Key architectural principles are documented in `ARCHITECTURE.md`. Please read it before making structural changes.

## Making Changes

### Branch Naming

```
feat/short-description     # New features
fix/issue-number-summary   # Bug fixes
docs/what-changed          # Documentation only
refactor/what-changed      # Code restructuring
test/what-tested           # Test additions/fixes
chore/what-changed         # Build, CI, dependencies
```

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(api): add batch document upload endpoint
fix(worker): handle corrupt PDF gracefully (#42)
docs: update API authentication guide
test(playback): add integration tests for resume
chore(deps): bump fastapi to 0.115.x
```

Scope should be one of: `api`, `worker`, `db`, `auth`, `storage`, `tts`, `vision`, `flutter`, `ci`, `docs`, `deps`.

### What to Work On

- Check [Issues](../../issues) for `good-first-issue` and `help-wanted` labels.
- For larger changes, open an issue first to discuss the approach.
- See `OPEN_CORE_BOUNDARY.md` to understand what belongs in core vs. extensions.

## Pull Request Process

1. **Fork** the repository and create your branch from `develop`.
2. **Write tests** for any new functionality.
3. **Run the full test suite** locally before pushing.
4. **Update documentation** if you changed APIs, configuration, or behavior.
5. **Open a PR** against `develop` with a clear description.

### PR Requirements

All PRs must pass the CI gate before merge:

- Ruff lint + format check (zero warnings)
- MyPy type check (no errors)
- Unit + integration tests pass
- Security scan (Bandit + pip-audit) clean
- Docker build succeeds
- Migration integrity check passes (single Alembic head, upgrade/downgrade cycle)

### Review Process

- All PRs require at least one approval from a maintainer.
- Maintainers may request changes; please respond within 7 days or the PR may be closed.
- Squash merge is the default strategy.

## Coding Standards

### Python (Backend)

- **Formatter**: Ruff (format)
- **Linter**: Ruff (check), configured in `pyproject.toml`
- **Type checker**: MyPy with strict mode on new code
- **Style**: Follow existing patterns in the codebase

Key conventions:
- All endpoints are `async`; never use blocking I/O on the main thread.
- Business logic lives in `services/`, not in route handlers.
- External calls go through `providers/` interfaces for testability.
- Use Pydantic models for all API input/output.
- Domain models in `models/` are plain dataclasses, not ORM objects.

### Dart (Flutter)

- **Formatter**: `dart format`
- **Analyzer**: `dart analyze --fatal-infos`
- **Architecture**: Feature-first folder structure, Riverpod for state management
- **Naming**: Follow [Effective Dart](https://dart.dev/effective-dart/style) conventions

### SQL / Migrations

- One migration per logical change (don't bundle unrelated schema changes).
- Always provide a `downgrade()` function.
- Test the full upgrade → downgrade → upgrade cycle.
- Use explicit enum creation with `checkfirst=True`.

## Testing

### Backend Test Structure

```
tests/
├── unit/              # Fast, no external dependencies
│   ├── test_services/
│   ├── test_schemas/
│   └── test_middleware/
├── integration/       # Requires PostgreSQL + Redis
│   ├── test_api/
│   └── test_workers/
└── conftest.py        # Shared fixtures
```

- Aim for ≥80% coverage on new code.
- Use `pytest-asyncio` for async tests.
- Use factory fixtures over raw SQL for test data.
- Integration tests should clean up after themselves (use transactions).

### Flutter Test Structure

```
test/
├── unit/              # Pure logic tests
├── widget/            # Widget-level tests
└── integration/       # Full app flow tests (less common)
```

See `TESTING.md` for detailed testing strategies and fixture patterns.

## Open-Core Boundary

Psitta uses an open-core model. Before contributing, read `OPEN_CORE_BOUNDARY.md` to understand what belongs in the Apache 2.0 core versus commercial extensions. In general:

- **Core** (Apache 2.0): Document processing, playback, built-in voices, API, standard integrations
- **Extensions** (Commercial): Voice cloning, premium TTS providers, advanced analytics, enterprise SSO

If you're unsure where your contribution belongs, ask in an issue before starting work.

## Questions?

- Open a [Discussion](../../discussions) for general questions
- Open an [Issue](../../issues) for bugs or feature requests
- See `ARCHITECTURE.md` for design decisions
- See `SECURITY.md` for vulnerability reporting
