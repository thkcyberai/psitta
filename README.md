# Psitta

**Ultra-natural document narration for creators.**

Psitta reads your documents aloud using human-quality voices — PDFs, DOCX, Markdown, web pages — with layout-aware parsing, image descriptions, synchronized captions, and emotional prosody.

Built for creators who consume long-form content and care about quality.

---

## Features

- **Document Ingestion** — PDF (native + scanned), DOCX, TXT, Markdown, Web URLs
- **Layout-Aware Parsing** — Tables, charts, images detected and described
- **Premium Voices** — Neural TTS with voice browsing by language, gender, style
- **Emotional Prosody** — Subtle tone classification for natural delivery
- **Streaming Playback** — Progressive audio with speed control and voice selection
- **Synchronized Captions** — Closed-caption style text synchronized to audio
- **Accessibility First** — Spoken image descriptions, screen reader support, WCAG 2.1 AA
- **Custom Voice Profiles** — Record, store, and (v2) clone voices with consent workflows

## Architecture

Psitta follows an **open-core model**:

| Layer | License | Contents |
|-------|---------|----------|
| `core/` | Apache 2.0 | Ingestion, parsing, OCR, chunking, captions, player, all interfaces |
| `extensions/` | Commercial | Premium voices, advanced emotion, enterprise auth, analytics |
| `apps/` | Apache 2.0 | Flutter client, admin dashboard |

Core is fully functional without extensions. Extensions plug in via defined interfaces only.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full system design.
See [OPEN_CORE_BOUNDARY.md](./docs/OPEN_CORE_BOUNDARY.md) for boundary rules.

## Tech Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Client | Flutter 3.x | Single codebase: iOS, Android, macOS, Windows, Linux, Web |
| Backend | Python 3.12 + FastAPI | Async-native, strong ML/NLP ecosystem, type hints |
| Database | PostgreSQL 16 | JSONB, full-text search, proven at scale |
| Cache / Queue | Redis 7 + Redis Streams | Sub-ms cache, reliable task queue without extra infra |
| Object Storage | S3-compatible (MinIO local) | Industry standard, provider-agnostic |
| Search | PostgreSQL FTS (MVP) → Meilisearch (v2) | Minimize infra in MVP |

## Quick Start

### Prerequisites

- Docker & Docker Compose v2
- Flutter SDK 3.x
- Python 3.12+
- Node.js 20+ (for tooling)

### Backend

```bash
cd core/backend
cp .env.example .env          # Configure secrets
docker compose up -d           # Postgres, Redis, MinIO
pip install -e ".[dev]"        # Install with dev dependencies
alembic upgrade head           # Run migrations
uvicorn psitta.main:app --reload
```

### Client

```bash
cd apps/client
flutter pub get
flutter run
```

### Workers

```bash
cd core/backend
python -m psitta.workers.orchestrator
```

## Development

```bash
pre-commit install             # Install git hooks
pytest                         # Run tests
ruff check .                   # Lint
ruff format .                  # Format
```

See [CONTRIBUTING.md](./CONTRIBUTING.md) for full development guide.

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | System design, module breakdown, data flow |
| [SECURITY.md](./SECURITY.md) | Threat model, encryption, auth, audit |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Dev setup, commit conventions, PR process |
| [docs/PRD.md](./docs/PRD.md) | Product requirements (MVP + roadmap) |
| [docs/API.md](./docs/API.md) | REST API specification |
| [docs/TESTING.md](./docs/TESTING.md) | Testing strategy and coverage targets |
| [docs/OBSERVABILITY.md](./docs/OBSERVABILITY.md) | Metrics, logging, tracing |
| [docs/ADRs/](./docs/ADRs/) | Architecture Decision Records |

## License

Core platform: [Apache License 2.0](./LICENSE)
Extensions: Commercial license — see `extensions/LICENSE`
