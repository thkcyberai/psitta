# Psitta — Test Strategy

## Overview

Psitta uses a three-tier testing approach: unit, integration, and end-to-end. Tests are designed to run fast by default, with heavier tests gated behind markers.

## Test Structure
```
core/backend/tests/
├── conftest.py              # Shared fixtures (mocks, client, settings)
├── factories.py             # Domain object factories
├── unit/                    # Fast, isolated, no external deps
│   ├── test_schemas.py      # Pydantic validation edge cases
│   ├── test_document_service.py
│   ├── test_playback_service.py
│   └── test_middleware/
│       ├── test_request_id.py
│       └── test_rate_limit.py
├── integration/             # Real FastAPI app, mocked dependencies
│   ├── test_document_api.py
│   ├── test_playback_api.py
│   ├── test_voice_api.py
│   └── test_user_api.py
└── e2e/                     # Full stack (requires running services)
    └── test_document_flow.py
```

## Running Tests
```bash
# All tests (fast — skips slow/e2e)
cd core/backend
pytest

# Unit tests only
pytest tests/unit/ -v

# Integration tests
pytest tests/integration/ -v

# E2E tests (requires docker compose up)
pytest tests/e2e/ -v -m slow

# With coverage
pytest --cov=psitta --cov-report=term-missing --cov-report=html

# Specific test file
pytest tests/unit/test_schemas.py -v
```

## Fixtures

### Mock Providers

All external providers have corresponding mock fixtures in `conftest.py`:

| Fixture | Mocks |
|---------|-------|
| `mock_storage` | S3 put/get/delete/presign |
| `mock_tts` | Azure TTS synthesis |
| `mock_vision` | Anthropic image description |
| `mock_voice_catalog` | Static voice listing |
| `mock_tone_classifier` | Tone classification |
| `mock_redis` | Redis commands (xadd, get, set) |

### Test Client

The `client` fixture creates an `httpx.AsyncClient` with ASGI transport — no real HTTP server needed. Each test gets a fresh FastAPI app instance.

### Factories

`factories.py` provides factory classes for all domain objects:
```python
from tests.factories import DocumentFactory, ChunkFactory

doc = DocumentFactory.create(title="Custom Title", page_count=5)
chunk = ChunkFactory.create(document_id=doc.id, sequence_index=0)
```

All factories return domain dataclass instances with sensible defaults.

## Test Categories

### Unit Tests

Fast, deterministic, no I/O. Test business logic in isolation.

**What to test:**
- Schema validation (accepted/rejected inputs, edge cases)
- Service methods with mock providers
- Middleware behavior via ASGI test client
- Domain model invariants

**Guidelines:**
- One assertion per test (prefer focused tests)
- Use descriptive test names: `test_upload_rejects_oversized_file`
- Mock at the provider boundary, not inside services

### Integration Tests

Test API endpoints with a real FastAPI app. External services mocked at the dependency injection level.

**What to test:**
- HTTP status codes for valid/invalid requests
- Response body structure
- Error message formats
- Query parameter handling
- Authentication requirements

### End-to-End Tests

Full pipeline tests requiring all services running. Marked with `@pytest.mark.slow`.

**What to test:**
- Upload → process → playback complete flow
- Health/readiness probes
- Cross-service interactions

## Coverage Targets

| Component | Target | Rationale |
|-----------|--------|-----------|
| Schemas | 95% | Validation is critical for security |
| Services | 85% | Core business logic |
| Middleware | 80% | Request handling paths |
| Providers | 70% | External API wrappers (mocked in unit) |
| API routes | 75% | HTTP layer (integration tests) |
| Workers | 60% | Pipeline stages (e2e tests) |

Overall target: **80% line coverage**

## CI Integration

Tests run automatically in GitHub Actions (`ci.yml`):

1. **Unit tests** — every push (fast feedback)
2. **Integration tests** — every push (with service containers)
3. **E2E tests** — on `main` branch only (requires full stack)

Coverage reports are uploaded as artifacts and tracked over time.

## Markers
```ini
# pyproject.toml
[tool.pytest.ini_options]
markers = [
    "slow: marks tests requiring full infrastructure",
    "integration: marks integration tests",
]
```

## Best Practices

1. **Test behavior, not implementation** — assert outcomes, not internal calls
2. **Use factories** — never construct test data inline
3. **One fixture per mock** — compose fixtures, don't create god-fixtures
4. **Async by default** — all test methods should be `async def`
5. **Descriptive names** — test name should explain what and why
6. **No test interdependence** — each test runs in isolation
7. **Clean up state** — fixtures use proper teardown
