# Testing Strategy

This document defines Psitta's testing approach, fixture patterns, and coverage expectations.

## Test Pyramid

```
        ╱ ╲
       ╱ E2E ╲          ← Few: Full Flutter app + API smoke tests
      ╱───────╲
     ╱ Integr.  ╲       ← Moderate: API routes + DB + Redis + S3
    ╱─────────────╲
   ╱    Unit Tests  ╲   ← Many: Services, schemas, providers, utilities
  ╱───────────────────╲
```

| Layer | Count Target | Speed | Dependencies |
|-------|-------------|-------|-------------|
| Unit | ~70% of tests | < 1s each | None (all mocked) |
| Integration | ~25% of tests | < 5s each | PostgreSQL, Redis, MinIO |
| E2E | ~5% of tests | < 30s each | Full stack |

## Backend Testing

### Directory Structure

```
core/backend/tests/
├── conftest.py              # Shared fixtures: db session, redis, test client
├── factories.py             # Factory functions for test data
├── unit/
│   ├── test_document_service.py
│   ├── test_playback_service.py
│   ├── test_schemas.py
│   ├── test_middleware/
│   │   ├── test_rate_limit.py
│   │   └── test_request_id.py
│   └── test_providers/
│       ├── test_s3_storage.py
│       └── test_azure_tts.py
├── integration/
│   ├── test_document_api.py
│   ├── test_playback_api.py
│   ├── test_voice_api.py
│   ├── test_user_api.py
│   └── test_worker.py
└── e2e/
    └── test_document_flow.py   # Upload → process → play full cycle
```

### Fixture Patterns

#### Database Fixtures (Integration)

Every integration test runs inside a transaction that is rolled back after the test completes. This gives test isolation without the cost of recreating the schema.

```python
# conftest.py
import pytest
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from psitta.db.session import async_session_factory

@pytest.fixture
async def db_session():
    """Provide a transactional database session that rolls back after each test."""
    engine = create_async_engine(settings.database_url)
    async with engine.connect() as conn:
        transaction = await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)
        try:
            yield session
        finally:
            await transaction.rollback()
            await session.close()
    await engine.dispose()
```

#### Factory Functions

Use factory functions instead of raw SQL or fixture files. Factories produce valid domain objects with sensible defaults that can be overridden per test.

```python
# factories.py
from uuid import uuid4
from psitta.models.domain import Document, DocumentStatus, SourceType

def make_document(
    user_id: str | None = None,
    title: str = "Test Document",
    status: DocumentStatus = DocumentStatus.UPLOADED,
    source_type: SourceType = SourceType.PDF,
    page_count: int = 10,
    **overrides,
) -> Document:
    return Document(
        id=overrides.get("id", uuid4()),
        user_id=user_id or f"user_{uuid4().hex[:8]}",
        title=title,
        source_type=source_type,
        status=status,
        page_count=page_count,
        file_size_bytes=page_count * 50_000,
        storage_key=f"uploads/{uuid4()}.pdf",
        metadata={},
        **overrides,
    )

def make_audio_segment(document_id=None, chunk_id=None, **overrides):
    return AudioSegment(
        id=overrides.get("id", uuid4()),
        document_id=document_id or uuid4(),
        chunk_id=chunk_id or uuid4(),
        voice_id="en-US-AriaNeural",
        speed=1.0,
        storage_key=f"audio/{uuid4()}.mp3",
        duration_ms=5000,
        file_size_bytes=40_000,
        **overrides,
    )
```

#### Provider Mocks

External providers are always mocked in unit tests. Each provider has a corresponding fake implementation.

```python
# Unit test example — mocking the TTS provider
class FakeTTSProvider:
    def __init__(self):
        self.calls: list[tuple[str, str, float]] = []

    async def synthesize(self, text: str, voice_id: str, speed: float):
        self.calls.append((text, voice_id, speed))
        return AudioSegment(
            data=b"fake-audio-data",
            duration_ms=len(text) * 50,
            format="mp3",
        )

    async def list_voices(self):
        return [VoiceInfo(id="test-voice", name="Test", language="en-US")]

@pytest.fixture
def fake_tts():
    return FakeTTSProvider()
```

#### Test Client (Integration)

```python
# conftest.py
from httpx import AsyncClient, ASGITransport
from psitta.main import create_app

@pytest.fixture
async def client(db_session):
    app = create_app()
    # Override the DB dependency to use our transactional session
    app.dependency_overrides[get_session] = lambda: db_session
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
```

### Test Conventions

1. **One assert per test** when possible. Multiple asserts are fine when testing a single logical operation (e.g., verifying both status code and response body).

2. **Test names describe behavior**, not implementation:
   ```python
   # Good
   async def test_upload_rejects_files_over_size_limit():
   async def test_playback_resumes_from_last_position():

   # Bad
   async def test_upload():
   async def test_playback_service_method():
   ```

3. **Arrange-Act-Assert** structure:
   ```python
   async def test_document_processing_creates_chunks(client, db_session):
       # Arrange
       doc = make_document(status=DocumentStatus.UPLOADED)
       await db_session.add(doc)

       # Act
       result = await document_service.process(doc.id)

       # Assert
       assert result.status == DocumentStatus.PROCESSED
       assert len(result.chunks) > 0
   ```

4. **Mark slow tests** so they can be skipped in rapid iteration:
   ```python
   @pytest.mark.slow
   async def test_full_document_processing_pipeline():
       ...
   ```

### Running Tests

```bash
# All tests
pytest

# Unit tests only (fast feedback loop)
pytest tests/unit -x --tb=short

# Integration tests (requires Docker services)
pytest tests/integration -v

# With coverage
pytest --cov=psitta --cov-report=html

# Skip slow tests
pytest -m "not slow"

# Run specific test file
pytest tests/unit/test_document_service.py -v
```

### Coverage Targets

| Module | Target | Rationale |
|--------|--------|-----------|
| `services/` | ≥ 85% | Core business logic — highest priority |
| `schemas/` | ≥ 90% | Validation logic must be thorough |
| `api/` | ≥ 75% | Route handlers tested via integration |
| `providers/` | ≥ 70% | External calls mocked; focus on interface compliance |
| `middleware/` | ≥ 80% | Security-critical code |
| `workers/` | ≥ 75% | Error handling and retry logic |
| **Overall** | **≥ 80%** | Enforced in CI |

## Flutter Testing

### Directory Structure

```
apps/mobile/test/
├── unit/
│   ├── models/
│   ├── services/
│   └── utils/
├── widget/
│   ├── components/
│   ├── screens/
│   └── test_helpers.dart
└── integration/
    └── app_test.dart
```

### Key Patterns

**Widget tests** use `pumpWidget` with provider overrides:

```dart
testWidgets('player shows document title', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentProvider.overrideWith((_) => fakeDocument),
      ],
      child: const MaterialApp(home: PlayerScreen()),
    ),
  );

  expect(find.text('Test Document'), findsOneWidget);
});
```

**Golden tests** for visual regression:

```dart
testWidgets('voice selector matches design', (tester) async {
  await tester.pumpWidget(/* ... */);
  await expectLater(
    find.byType(VoiceSelector),
    matchesGoldenFile('goldens/voice_selector.png'),
  );
});
```

### Running Flutter Tests

```bash
cd apps/mobile

# All tests
flutter test

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Update golden files
flutter test --update-goldens
```

## CI Integration

All tests run automatically on every PR via the CI pipeline (`.github/workflows/ci.yml`). The CI gate requires all test jobs to pass before merge.

Test artifacts (coverage XML, JUnit reports) are uploaded as workflow artifacts for debugging failed runs.

## Writing Tests for New Features

1. Start with a failing test that describes the desired behavior.
2. Write the minimum code to make it pass.
3. Add edge cases: invalid input, missing data, permission denied, timeouts.
4. Add integration test if the feature touches the database or external services.
5. Verify coverage didn't drop below targets.
