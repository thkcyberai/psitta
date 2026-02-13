# Psitta — Architecture Document

**Version:** 1.0.0
**Last Updated:** 2026-02-08

---

## 1. System Overview

Psitta is a document-to-audio platform composed of four primary subsystems:

```
┌─────────────┐     ┌──────────────────────────────────────────────────┐
│   Flutter    │────▶│                  API Gateway                     │
│   Client     │◀────│              (FastAPI + Auth)                    │
└─────────────┘     └────────┬──────────┬──────────┬──────────────────┘
                             │          │          │
                    ┌────────▼──┐ ┌─────▼────┐ ┌──▼──────────┐
                    │ Document  │ │  Voice   │ │  Playback   │
                    │ Pipeline  │ │  System  │ │  Service    │
                    └────┬──────┘ └─────┬────┘ └──┬──────────┘
                         │              │          │
              ┌──────────▼──────────────▼──────────▼──────────┐
              │              Shared Infrastructure             │
              │   PostgreSQL │ Redis │ S3 │ Task Queue         │
              └────────────────────────────────────────────────┘
```

### Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| **API Gateway** | Authentication, authorization, request routing, rate limiting, input validation |
| **Document Pipeline** | Ingestion → parsing → OCR → chunking → vision description → tone analysis |
| **Voice System** | Voice catalog management, voice selection, TTS synthesis, custom voice profiles |
| **Playback Service** | Audio streaming, caption synchronization, playback state management |
| **Shared Infrastructure** | Persistence, caching, object storage, background job orchestration |

---

## 2. Backend Architecture

### 2.1 Layered Architecture

```
┌─────────────────────────────────────────┐
│              API Layer (FastAPI)         │  ← HTTP handlers, validation, serialization
├─────────────────────────────────────────┤
│            Service Layer                │  ← Business logic, orchestration
├─────────────────────────────────────────┤
│          Provider Layer (Interfaces)    │  ← Abstraction over external services
├─────────────────────────────────────────┤
│         Repository Layer (DB)           │  ← Data access, queries
├─────────────────────────────────────────┤
│           Model Layer                   │  ← SQLAlchemy models, Pydantic schemas
└─────────────────────────────────────────┘
```

Every layer communicates only with adjacent layers. No API handler touches the database directly.

### 2.2 Provider Interface Pattern

All external dependencies are abstracted behind provider interfaces:

```python
# core/interfaces/tts_provider.py
class TTSProvider(Protocol):
    async def synthesize(self, text: str, voice_id: str, options: TTSOptions) -> AsyncIterator[AudioChunk]: ...
    async def list_voices(self, filters: VoiceFilter) -> list[VoiceMeta]: ...
    async def get_voice(self, voice_id: str) -> VoiceMeta: ...
    async def estimate_cost(self, char_count: int, voice_id: str) -> CostEstimate: ...
```

Provider interfaces defined in MVP:

| Interface | Core Implementation | Extension Implementation |
|-----------|-------------------|--------------------------|
| `TTSProvider` | Azure Cognitive Services | ElevenLabs Premium |
| `VoiceCatalogProvider` | Static catalog (JSON) | Dynamic catalog with recommendations |
| `DocumentSourceProvider` | File upload, URL fetch | Google Drive, Dropbox, Notion |
| `VisionDescriptionProvider` | Anthropic Claude | OpenAI GPT-4o, custom fine-tuned |
| `OCRProvider` | Tesseract | Google Cloud Vision |
| `AuthProvider` | Auth0/Clerk | Enterprise SSO (SAML/OIDC) |
| `StorageProvider` | S3-compatible | Azure Blob, GCS |
| `ToneClassifier` | Rule-based | LLM-based classifier |

### 2.3 Document Processing Pipeline

Each stage is an independent, idempotent worker job:

```
Upload → [validate] → [parse] → [OCR*] → [chunk] → [describe_visuals] → [classify_tone] → [synthesize] → Ready
            │            │          │          │              │                  │               │
            ▼            ▼          ▼          ▼              ▼                  ▼               ▼
        S3 (raw)    extracted    OCR text   chunks[]     descriptions[]     tone_tags[]     audio chunks[]
                     text +       (if        + word       per visual         per chunk       in S3 +
                    metadata     scanned)   timestamps    element                           timestamps
```

*OCR runs only for scanned/image-based PDFs (detected automatically).

### 2.4 Job Queue Design

Redis Streams-based task queue with the following guarantees:

- **At-least-once delivery** with idempotency keys
- **Consumer groups** for parallel processing
- **Dead letter queue** after 3 retries with exponential backoff
- **Progress reporting** via Redis pub/sub (client polls or uses SSE)
- **Job priority** — small documents processed before large ones

Job states: `PENDING → PROCESSING → COMPLETED | FAILED | DEAD_LETTER`

### 2.5 Data Flow: Upload to Playback

```
1. Client uploads document → POST /api/v1/documents
2. API validates, stores raw file in S3, creates document record (status: UPLOADED)
3. API enqueues job: {type: PROCESS_DOCUMENT, document_id, idempotency_key}
4. Worker picks up job:
   a. Parse document → extract text + detect non-text elements
   b. If scanned → run OCR pipeline
   c. Chunk text into semantic blocks with word-level timestamps
   d. For each visual element → generate description via VisionDescriptionProvider
   e. For each chunk → classify emotional tone
   f. Store all derived artifacts
   g. Update document status: PARSED
5. Client requests playback → POST /api/v1/documents/{id}/play
6. Playback service:
   a. For each chunk, check audio cache (Redis key: audio:{doc_id}:{chunk_id}:{voice_id})
   b. Cache miss → synthesize via TTSProvider → store in S3 → update cache
   c. Stream audio chunks progressively to client
   d. Emit caption sync events via SSE
7. Client renders audio + synchronized captions
```

---

## 3. Frontend Architecture

### 3.1 Flutter App Structure

```
apps/client/lib/src/
├── core/                    # Cross-cutting concerns
│   ├── config/              # Environment, feature flags
│   ├── models/              # Domain models (immutable, Freezed)
│   ├── providers/           # Riverpod providers (state management)
│   ├── services/            # API client, auth, storage, audio
│   └── widgets/             # Shared widgets (buttons, cards, loaders)
├── features/                # Feature modules (lazy-loaded)
│   ├── home/                # Document library, upload
│   ├── document/            # Document detail, processing status
│   ├── player/              # Playback, captions, controls
│   ├── voices/              # Voice catalog, selection, custom profiles
│   └── settings/            # User preferences, account, accessibility
└── shared/
    ├── theme/               # Design tokens, typography, colors
    ├── utils/               # Formatters, validators, extensions
    └── widgets/             # Reusable UI components
```

### 3.2 State Management: Riverpod

- **AsyncNotifierProvider** for server-synced state (documents, voices)
- **StateNotifierProvider** for local UI state (player controls, filters)
- **FutureProvider** for one-shot data fetches
- **StreamProvider** for real-time updates (processing progress, playback position)

### 3.3 Accessibility Implementation

| Feature | Implementation |
|---------|---------------|
| Screen readers | `Semantics` widget on all interactive elements; tested with VoiceOver + TalkBack |
| Keyboard navigation | `FocusTraversalGroup` with logical tab order on desktop |
| Font scaling | All text uses `MediaQuery.textScaleFactor`; no hardcoded font sizes |
| High contrast | `MediaQuery.highContrast` → switch to high-contrast theme |
| Reduced motion | `MediaQuery.disableAnimations` → disable all transitions |
| Caption styling | Configurable font size (12–32pt), contrast ratio ≥ 4.5:1, position (top/bottom) |
| Touch targets | Minimum 48x48dp for all interactive elements |

### 3.4 Audio Playback Architecture

```
┌──────────────────┐
│  PlaybackService │  ← Riverpod-managed singleton
├──────────────────┤
│  just_audio       │  ← Cross-platform audio engine
├──────────────────┤
│  AudioSource      │  ← ConcatenatingAudioSource for gapless chunk playback
├──────────────────┤
│  CaptionSync      │  ← Matches playback position to word-level timestamps
└──────────────────┘
```

---

## 4. API Specification (Summary)

Full specification in [docs/API.md](./docs/API.md).

### 4.1 Core Endpoints

```
Authentication:
  POST   /api/v1/auth/register
  POST   /api/v1/auth/login
  POST   /api/v1/auth/refresh
  POST   /api/v1/auth/logout

Documents:
  POST   /api/v1/documents              # Upload document
  GET    /api/v1/documents               # List user documents
  GET    /api/v1/documents/{id}          # Get document detail
  DELETE /api/v1/documents/{id}          # Hard delete
  GET    /api/v1/documents/{id}/status   # Processing status (SSE)
  GET    /api/v1/documents/{id}/chunks   # Get text chunks with timestamps

Playback:
  POST   /api/v1/documents/{id}/play     # Start playback session
  GET    /api/v1/playback/{session_id}/stream   # Audio stream (chunked transfer)
  GET    /api/v1/playback/{session_id}/captions # Caption sync stream (SSE)
  PATCH  /api/v1/playback/{session_id}   # Update position, speed, voice

Voices:
  GET    /api/v1/voices                  # List voices (filterable)
  GET    /api/v1/voices/{id}             # Voice detail
  GET    /api/v1/voices/{id}/preview     # Preview audio sample
  POST   /api/v1/voices/custom           # Create custom voice profile
  POST   /api/v1/voices/custom/{id}/recordings  # Upload recording
  POST   /api/v1/voices/custom/{id}/consent     # Submit consent receipt

User:
  GET    /api/v1/users/me                # Current user profile
  PATCH  /api/v1/users/me                # Update preferences
  DELETE /api/v1/users/me                # Delete account + all data

Admin (extension):
  GET    /api/v1/admin/usage             # Usage statistics
  GET    /api/v1/admin/health            # System health check
```

### 4.2 API Conventions

- **Versioned:** All endpoints prefixed with `/api/v1/`
- **JSON:API-ish:** Consistent envelope: `{ "data": ..., "meta": { "page": ..., "total": ... } }`
- **Pagination:** Cursor-based (`?cursor=xxx&limit=20`)
- **Filtering:** Query params (`?language=en&gender=female&style=narrative`)
- **Errors:** RFC 7807 Problem Details: `{ "type": "...", "title": "...", "status": 422, "detail": "..." }`
- **Idempotency:** `Idempotency-Key` header on all mutating requests
- **Rate Limiting:** `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers

---

## 5. Database Schema

### 5.1 Core Tables

```sql
-- Users (core fields; auth provider handles credentials)
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id     TEXT UNIQUE NOT NULL,        -- Auth provider user ID
    email           TEXT UNIQUE NOT NULL,
    display_name    TEXT NOT NULL,
    preferences     JSONB NOT NULL DEFAULT '{}', -- Playback prefs, accessibility settings
    tier            TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'enterprise')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Documents
CREATE TABLE documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    source_type     TEXT NOT NULL CHECK (source_type IN ('pdf', 'docx', 'txt', 'markdown', 'url')),
    source_url      TEXT,                       -- For URL ingestion
    file_key        TEXT NOT NULL,              -- S3 key for original file
    file_size_bytes BIGINT NOT NULL,
    page_count      INTEGER,
    status          TEXT NOT NULL DEFAULT 'uploaded'
                    CHECK (status IN ('uploaded', 'parsing', 'parsed', 'processing', 'ready', 'failed')),
    error_message   TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}', -- Extracted metadata (author, title, etc.)
    expires_at      TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '60 days',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_expires_at ON documents(expires_at);

-- Document chunks (semantic text blocks with timestamps)
CREATE TABLE document_chunks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    sequence_num    INTEGER NOT NULL,
    content_type    TEXT NOT NULL CHECK (content_type IN ('text', 'heading', 'list', 'table', 'image_desc', 'chart_desc')),
    text_content    TEXT NOT NULL,
    tone_tag        TEXT NOT NULL DEFAULT 'neutral',
    word_timestamps JSONB,                     -- [{word, start_ms, end_ms}, ...]
    page_number     INTEGER,
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(document_id, sequence_num)
);
CREATE INDEX idx_chunks_document_id ON document_chunks(document_id);

-- Visual elements detected in documents
CREATE TABLE visual_elements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_id        UUID REFERENCES document_chunks(id) ON DELETE SET NULL,
    element_type    TEXT NOT NULL CHECK (element_type IN ('image', 'chart', 'table', 'diagram')),
    page_number     INTEGER NOT NULL,
    bounding_box    JSONB,                     -- {x, y, width, height} normalized 0-1
    image_key       TEXT,                      -- S3 key for extracted image
    description     TEXT,                      -- Generated alt-text
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audio cache (synthesized audio chunks)
CREATE TABLE audio_segments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    chunk_id        UUID NOT NULL REFERENCES document_chunks(id) ON DELETE CASCADE,
    voice_id        TEXT NOT NULL,
    speed           NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    audio_key       TEXT NOT NULL,             -- S3 key for audio file
    duration_ms     INTEGER NOT NULL,
    format          TEXT NOT NULL DEFAULT 'mp3',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(chunk_id, voice_id, speed)
);
CREATE INDEX idx_audio_document_id ON audio_segments(document_id);

-- Voice profiles (custom voices)
CREATE TABLE voice_profiles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft', 'recording', 'processing', 'ready', 'failed')),
    language        TEXT NOT NULL DEFAULT 'en',
    metadata        JSONB NOT NULL DEFAULT '{}',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Voice recordings
CREATE TABLE voice_recordings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      UUID NOT NULL REFERENCES voice_profiles(id) ON DELETE CASCADE,
    recording_key   TEXT NOT NULL,             -- S3 key
    transcript      TEXT,
    duration_ms     INTEGER NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Consent receipts
CREATE TABLE consent_receipts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id      UUID NOT NULL REFERENCES voice_profiles(id) ON DELETE CASCADE,
    consenter_email TEXT NOT NULL,
    consent_type    TEXT NOT NULL CHECK (consent_type IN ('self', 'other')),
    consent_text    TEXT NOT NULL,             -- Exact text shown to consenter
    ip_address      INET,
    user_agent      TEXT,
    consented_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ
);

-- Playback sessions
CREATE TABLE playback_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    document_id     UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    voice_id        TEXT NOT NULL,
    speed           NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    position_ms     BIGINT NOT NULL DEFAULT 0,
    current_chunk   INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit log
CREATE TABLE audit_log (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    action          TEXT NOT NULL,
    resource_type   TEXT NOT NULL,
    resource_id     UUID,
    details         JSONB NOT NULL DEFAULT '{}',
    ip_address      INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_created_at ON audit_log(created_at);

-- Jobs (background processing)
CREATE TABLE jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type            TEXT NOT NULL,
    payload         JSONB NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'dead_letter')),
    priority        INTEGER NOT NULL DEFAULT 0,
    attempts        INTEGER NOT NULL DEFAULT 0,
    max_attempts    INTEGER NOT NULL DEFAULT 3,
    idempotency_key TEXT UNIQUE,
    error_message   TEXT,
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_type ON jobs(type);
```

### 5.2 Storage Layout (S3)

```
psitta-{env}/
├── uploads/
│   └── {user_id}/{document_id}/original.{ext}
├── extracted/
│   └── {document_id}/
│       ├── text.json            # Extracted text with metadata
│       ├── chunks.json          # Chunked text with timestamps
│       └── visuals/
│           └── {element_id}.png # Extracted visual elements
├── audio/
│   └── {document_id}/{chunk_id}/{voice_id}_{speed}.mp3
├── voices/
│   └── {profile_id}/
│       ├── recordings/{recording_id}.wav
│       └── model/               # v2: cloned voice model artifacts
└── temp/
    └── {job_id}/                # Temporary processing artifacts (auto-cleaned)
```

---

## 6. Security Architecture

Detailed in [SECURITY.md](./SECURITY.md). Summary:

- **Authentication:** OAuth 2.0 + OIDC via Auth0/Clerk; JWT access tokens (15 min) + refresh tokens (7 days)
- **Authorization:** RBAC (user, admin) + resource-level ownership checks on every request
- **Encryption:** TLS 1.3 in transit; S3 SSE-S3 at rest; sensitive Postgres columns encrypted via application-level encryption
- **Secrets:** Environment variables only; no hardcoded values; rotated via secrets manager
- **Input validation:** Pydantic models with strict types; file type validation via magic bytes (not extension)
- **Rate limiting:** Token bucket per user (100 req/min API, 10 req/min upload) + global circuit breaker
- **Audit:** Every mutation logged to `audit_log` table with user, action, resource, IP
- **CORS:** Allowlist-only origins
- **CSP:** Strict Content-Security-Policy headers
- **Dependency scanning:** Dependabot + Snyk in CI

---

## 7. Module Dependency Graph

```
                    ┌──────────┐
                    │   API    │
                    └────┬─────┘
                         │ depends on
              ┌──────────┼──────────┐
              ▼          ▼          ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Document │ │  Voice   │ │ Playback │
        │ Service  │ │ Service  │ │ Service  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │             │             │
             ▼             ▼             ▼
        ┌─────────────────────────────────────┐
        │         Provider Interfaces         │  ← core/interfaces
        │  (TTS, OCR, Vision, Storage, Auth)  │
        └────────────────┬────────────────────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Postgres │ │  Redis   │ │    S3    │
        └──────────┘ └──────────┘ └──────────┘
```

**Rule:** Arrows point downward only. No circular dependencies. Extensions depend on interfaces, never on concrete implementations.
