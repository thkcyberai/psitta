# Psitta

**Turn reading time into listening time.** Psitta transforms any document into ultra-natural narration — upload a PDF, pick a voice, and listen.

[![CI](https://github.com/psitta/psitta/actions/workflows/ci.yml/badge.svg)](https://github.com/psitta/psitta/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## Architecture

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **API** | FastAPI + Uvicorn | Async REST API with OpenAPI docs |
| **Database** | PostgreSQL 16 | Document metadata, user data, sessions |
| **Queue** | Redis 7 Streams | Async document processing pipeline |
| **Storage** | S3 / MinIO | Document and audio file storage |
| **TTS** | Azure Cognitive TTS | Neural voice synthesis |
| **Vision** | Anthropic Claude | Image descriptions for narration |
| **Mobile** | Flutter 3.24+ | Cross-platform iOS/Android app |

## Quick Start
```bash
# 1. Clone and setup environment
git clone https://github.com/psitta/psitta.git
cd psitta
cp .env.example .env   # Edit secrets

# 2. Start infrastructure
docker compose up -d postgres redis minio

# 3. Run the bootstrap script
./scripts/bootstrap.sh

# 4. Start the API server
cd core/backend
source .venv/bin/activate
uvicorn psitta.main:create_app --factory --reload

# 5. Start the Flutter app (separate terminal)
cd apps/desktop
flutter run
```

API docs available at: http://localhost:8000/docs

## Repository Structure
```
psitta/
├── core/backend/     # FastAPI backend (Apache 2.0)
├── apps/desktop/      # Flutter cross-platform app (Apache 2.0)
├── extensions/       # Commercial add-ons (Proprietary)
├── docs/             # Documentation (CC BY 4.0)
├── scripts/          # Developer tooling
└── .github/          # CI/CD workflows
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full system design and [OPEN_CORE_BOUNDARY.md](OPEN_CORE_BOUNDARY.md) for licensing details.

## Development

| Command | Purpose |
|---------|---------|
| `docker compose up -d` | Start infrastructure |
| `./scripts/bootstrap.sh` | Full developer setup |
| `./scripts/reset-db.sh` | Reset database |
| `cd core/backend && pytest` | Run backend tests |
| `cd apps/desktop && flutter test` | Run mobile tests |
| `pre-commit run --all-files` | Run all linters |

## Documentation

| Document | Description |
|----------|-------------|
| [PRD](docs/PRD.md) | Product requirements |
| [Architecture](ARCHITECTURE.md) | System design |
| [API Spec](docs/API.md) | OpenAPI specification |
| [Security](SECURITY.md) | Vulnerability disclosure |
| [Testing](docs/TESTING.md) | Test strategy |
| [Contributing](CONTRIBUTING.md) | Contributor guide |
| [ADRs](docs/adr/) | Architecture decisions |

## License

- **Core** (`core/`, `apps/`): [Apache License 2.0](LICENSE)
- **Extensions** (`extensions/`): [Proprietary](LICENSE-EXTENSIONS)
- **Documentation** (`docs/`): CC BY 4.0
