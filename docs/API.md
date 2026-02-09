# Psitta — API Specification

**Version:** 1.0.0
**Base URL:** `https://api.psitta.io/api/v1`

---

## Conventions

- **Content-Type:** `application/json` (except file uploads: `multipart/form-data`)
- **Authentication:** `Authorization: Bearer <jwt_access_token>`
- **Idempotency:** `Idempotency-Key: <uuid>` required on all POST/PUT/PATCH/DELETE
- **Pagination:** Cursor-based: `?cursor=<opaque>&limit=20` (max 100)
- **Errors:** RFC 7807 Problem Details

### Response Envelope

```json
{
  "data": { ... },
  "meta": {
    "cursor": "next_cursor_token",
    "has_more": true,
    "total": 42
  }
}
```

### Error Response

```json
{
  "type": "https://api.psitta.io/errors/validation",
  "title": "Validation Error",
  "status": 422,
  "detail": "File size exceeds 100 MB limit",
  "instance": "/api/v1/documents",
  "errors": [
    { "field": "file", "message": "File size 150 MB exceeds maximum of 100 MB" }
  ]
}
```

---

## Documents

### POST /documents — Upload Document

**Request:** `multipart/form-data`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | File | Yes* | Document file (PDF, DOCX, TXT, MD). Max 100 MB |
| `url` | string | Yes* | Web URL to ingest. *Either `file` or `url` required |
| `title` | string | No | Override extracted title |
| `voice_id` | string | No | Default voice for playback |
| `auto_play` | boolean | No | Begin processing immediately (default: true) |

**Response:** `201 Created`

```json
{
  "data": {
    "id": "uuid",
    "title": "Document Title",
    "source_type": "pdf",
    "status": "uploaded",
    "file_size_bytes": 2048576,
    "page_count": null,
    "created_at": "2026-02-08T10:00:00Z",
    "expires_at": "2026-04-09T10:00:00Z"
  }
}
```

### GET /documents — List Documents

**Query params:** `status`, `source_type`, `cursor`, `limit`, `sort` (`created_at`, `-created_at`)

### GET /documents/{id} — Document Detail

Returns full document metadata including chunks summary, processing status, available audio.

### DELETE /documents/{id} — Hard Delete

Deletes document, all chunks, audio, and S3 objects. Irreversible.

### GET /documents/{id}/status — Processing Status (SSE)

Server-Sent Events stream:

```
event: progress
data: {"stage": "parsing", "progress": 0.45, "message": "Extracting text..."}

event: progress
data: {"stage": "ocr", "progress": 0.80, "message": "Processing scanned pages..."}

event: complete
data: {"status": "ready", "page_count": 42, "chunk_count": 156, "duration_estimate_ms": 1250000}
```

### GET /documents/{id}/chunks — Get Chunks

Returns text chunks with metadata for caption display.

**Query params:** `from_seq` (sequence number), `limit`

```json
{
  "data": [
    {
      "id": "uuid",
      "sequence_num": 0,
      "content_type": "heading",
      "text_content": "Chapter 1: Introduction",
      "tone_tag": "neutral",
      "word_timestamps": [
        {"word": "Chapter", "start_ms": 0, "end_ms": 450},
        {"word": "1:", "start_ms": 450, "end_ms": 700}
      ],
      "page_number": 1
    }
  ]
}
```

---

## Playback

### POST /documents/{id}/play — Start Session

**Request:**

```json
{
  "voice_id": "en-US-neural-aria",
  "speed": 1.0,
  "start_chunk": 0
}
```

**Response:** `201 Created`

```json
{
  "data": {
    "session_id": "uuid",
    "stream_url": "/api/v1/playback/{session_id}/stream",
    "captions_url": "/api/v1/playback/{session_id}/captions",
    "total_chunks": 156,
    "estimated_duration_ms": 1250000
  }
}
```

### GET /playback/{session_id}/stream — Audio Stream

**Response:** `200 OK` with `Transfer-Encoding: chunked`, `Content-Type: audio/mpeg`

Progressive audio delivery. Client receives audio chunks as they are synthesized.

### GET /playback/{session_id}/captions — Caption Stream (SSE)

```
event: caption
data: {"chunk_seq": 0, "text": "Chapter 1: Introduction", "start_ms": 0, "end_ms": 2500, "words": [...]}

event: caption
data: {"chunk_seq": 1, "text": "The history of document narration...", "start_ms": 2500, "end_ms": 8200, "words": [...]}
```

### PATCH /playback/{session_id} — Update Playback

```json
{
  "position_ms": 45000,
  "speed": 1.5,
  "voice_id": "en-US-neural-guy"
}
```

---

## Voices

### GET /voices — List Voices

**Query params:** `language`, `gender` (`male`, `female`, `neutral`), `style` (`narrative`, `conversational`, `formal`, `warm`), `provider`

```json
{
  "data": [
    {
      "id": "en-US-neural-aria",
      "name": "Aria",
      "language": "en-US",
      "gender": "female",
      "style": "narrative",
      "provider": "azure",
      "preview_url": "/api/v1/voices/en-US-neural-aria/preview",
      "is_premium": false,
      "quality_score": 4.5
    }
  ]
}
```

### GET /voices/{id}/preview — Voice Preview

**Response:** `200 OK`, `Content-Type: audio/mpeg`, 10-second sample audio.

### POST /voices/custom — Create Custom Profile

```json
{
  "name": "My Voice",
  "language": "en-US"
}
```

### POST /voices/custom/{id}/recordings — Upload Recording

**Request:** `multipart/form-data` with `audio` file (WAV/MP3, min 30 seconds) and optional `transcript`.

### POST /voices/custom/{id}/consent — Submit Consent

```json
{
  "consent_type": "other",
  "consenter_email": "person@example.com",
  "consent_text": "I consent to my voice being used..."
}
```

---

## User

### GET /users/me — Current User

### PATCH /users/me — Update Preferences

```json
{
  "display_name": "New Name",
  "preferences": {
    "default_voice_id": "en-US-neural-aria",
    "default_speed": 1.25,
    "caption_font_size": 18,
    "caption_position": "bottom",
    "high_contrast_captions": true
  }
}
```

### DELETE /users/me — Delete Account

Deletes all user data, documents, audio, voice profiles, and consent receipts. Irreversible. Requires `X-Confirm-Delete: true` header.

---

## Rate Limits

| Endpoint Group | Limit | Window |
|---------------|-------|--------|
| Authentication | 10 req | 1 min |
| Document upload | 10 req | 1 min |
| General API | 100 req | 1 min |
| Audio streaming | 50 req | 1 min |
| Voice preview | 30 req | 1 min |

Rate limit headers included on every response:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset` (Unix timestamp)
