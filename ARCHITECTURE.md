# Psitta — System Architecture

## Overview

Psitta is a document narration platform that converts any document into ultra-natural audio. The system follows a clean architecture with clear separation between the API layer, business logic, and external providers.

## System Diagram
```
┌─────────────┐     ┌─────────────────────────────────────────────┐
│ Flutter App  │────▶│              FastAPI Server                 │
│ (iOS/Android)│◀────│  /api/v1/documents, playback, voices, users│
└─────────────┘     └────┬──────────┬──────────┬──────────────────┘
                         │          │          │
                    ┌────▼───┐ ┌───▼────┐ ┌──▼─────────┐
                    │Postgres│ │ Redis  │ │ S3 / MinIO │
                    │  (DB)  │ │(Queue) │ │ (Storage)  │
                    └────────┘ └───┬────┘ └──┬─────────┘
                                   │         │
                    ┌──────────────▼─────────▼──────────┐
                    │     Document Processing Worker     │
                    │  Parse → Chunk → Describe → TTS   │
                    └───────┬────────────────┬──────────┘
                            │                │
                    ┌───────▼──────┐ ┌──────▼────────┐
                    │ Azure TTS    │ │ Anthropic     │
                    │ (synthesis)  │ │ (vision/imgs) │
                    └──────────────┘ └───────────────┘
```

## Component Architecture

### API Server (FastAPI)

The API layer follows a three-tier pattern:
```
Routes (api/v1/*.py)
  │  Pydantic validation, HTTP concerns
  ▼
Services (services/*.py)
  │  Business logic, orchestration
  ▼
Providers (providers/*.py)
  │  External API calls via Protocol interfaces
  ▼
External Systems (Azure, Anthropic, S3, PostgreSQL)
```

**Key design decisions:**
- Dependency injection via FastAPI `Depends()` for testability
- Protocol-based provider contracts for open-core extensibility
- Frozen dataclass domain models separate from ORM models
- Pydantic strict schemas for all API validation

### Document Processing Pipeline

Documents flow through a six-stage pipeline executed by Redis Streams consumers:

| Stage | Action | Status |
|-------|--------|--------|
| 1. Parse | Extract text and images from PDF/DOCX | `parsing` |
| 2. Chunk | Split into narration-sized segments | `chunking` |
| 3. Describe | Generate image descriptions (Anthropic) | `chunking` |
| 4. Classify | Determine tone per chunk (rule-based) | `synthesizing` |
| 5. Synthesize | Convert chunks to audio (Azure TTS) | `synthesizing` |
| 6. Finalize | Mark document as ready | `ready` |

Each stage updates the document status, enabling real-time progress in the client.

### Provider Interface Pattern

All external integrations implement Protocol classes defined in `providers/interfaces/contracts.py`:
```python
class TTSProvider(Protocol):
    async def synthesize(self, text, voice_id, speed, tone) -> bytes: ...
    async def health_check(self) -> bool: ...
```

This enables:
- **Core providers** (Apache 2.0): Azure TTS, S3 storage, Anthropic vision, static voice catalog, rule-based tone
- **Extension providers** (commercial): ElevenLabs TTS, voice cloning, LLM tone classifier

Providers are swapped via dependency injection — no core code changes needed.

### Database Schema

PostgreSQL 16 with async SQLAlchemy and Alembic migrations:

| Table | Purpose |
|-------|---------|
| `users` | Authentication, tier, preferences |
| `documents` | Document metadata and processing status |
| `document_chunks` | Parsed text segments with tone classification |
| `audio_segments` | Generated audio files (cached per chunk+voice+speed) |
| `playback_sessions` | Resume position and listening state |
| `voice_profiles` | User voice preferences |
| `audit_log` | Security audit trail |

Key indexes optimize the primary access patterns: user document listing, chunk sequential access, and audio cache lookup.

### Caching Strategy

Audio segments are cached by `(chunk_id, voice_id, speed)` composite key:
- Same document re-played with same voice → zero TTS cost
- Same chunk appearing in multiple documents → shared audio
- Speed change → new synthesis required (SSML prosody differs)

## Security Architecture

- **Authentication**: External provider (Auth0/Clerk) — JWT validation
- **Authorization**: User-scoped data access (user_id on all queries)
- **Secrets**: `SecretStr` for all credentials, never logged
- **Storage**: Pre-signed URLs with 15-minute TTL, server-side encryption
- **Input**: Pydantic strict schemas, file size limits, format validation
- **Network**: CORS restricted, rate limiting (token bucket per client)
- **Container**: Non-root user, minimal base image, no dev tools in production

## Scalability

| Component | Scaling Method |
|-----------|---------------|
| API servers | Horizontal (stateless, behind load balancer) |
| Workers | Horizontal (Redis consumer groups, independent scaling) |
| PostgreSQL | Vertical + read replicas, connection pooling |
| Redis | Cluster mode for cache, Streams for job distribution |
| S3 | Effectively unlimited, CDN for audio delivery |

## Technology Choices

See [ADR index](docs/adr/README.md) for detailed decision records.

| Choice | Rationale |
|--------|-----------|
| FastAPI | Async-first, OpenAPI auto-generation, Pydantic integration |
| PostgreSQL | JSONB for metadata, robust indexing, proven reliability |
| Redis Streams | Consumer groups for exactly-once job delivery, low latency |
| S3/MinIO | MinIO for local dev, S3 for production — identical API |
| Azure TTS | Best neural voice quality/cost ratio at scale |
| Flutter | Single codebase for iOS and Android with native performance |
| Alembic | Industry standard for SQLAlchemy migrations |
