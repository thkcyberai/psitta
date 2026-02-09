# Psitta — Product Requirements Document

**Version:** 1.0.0
**Status:** Approved for MVP Development
**Last Updated:** 2026-02-08

---

## 1. Assumptions

### Product Assumptions

1. **Target user is a creator** — writers, researchers, students, publishers, podcast producers — who regularly consumes documents exceeding 5 pages.
2. **Voice quality is the primary differentiator.** Users will tolerate slightly longer processing times for significantly better audio quality. Latency budget: first audio chunk within 3 seconds for documents under 10 pages.
3. **English is the MVP language.** Multilingual support (Spanish, French, German, Mandarin, Japanese) is scoped for v2. Architecture must not couple to English.
4. **Mobile-first usage pattern.** ~65% of playback will occur on mobile devices. Desktop is used primarily for upload and library management.
5. **Documents are private by default.** No social features, no public sharing in MVP. Collaboration is v3.
6. **Average document size is 10–50 pages.** System must handle up to 500 pages gracefully with chunked processing. Documents over 500 pages show a warning and require explicit confirmation.
7. **Scanned PDFs represent ~15% of uploads.** OCR is not optional; it is required for MVP.
8. **Users will pay for quality.** Freemium model: 3 documents/month free (standard voices), paid tiers unlock premium voices, higher limits, custom voice profiles.
9. **Custom voice cloning is a v2 feature**, but the consent model, recording infrastructure, and data model ship in MVP.
10. **No offline playback in MVP.** Progressive streaming requires connectivity. Offline download is v2.

### Technical Assumptions

1. **Cloud-first deployment** on AWS (primary) with architecture portable to GCP/Azure via abstraction layers.
2. **TTS provider: ElevenLabs (primary) + Azure Cognitive Services (fallback).** Both offer neural voices meeting quality bar. Provider interface allows swapping without code changes.
3. **OCR provider: Tesseract (core, open-source) + Google Cloud Vision (extension, higher accuracy).** Same provider interface pattern.
4. **Vision description: OpenAI GPT-4o or Anthropic Claude for image/chart/table description.** Provider interface allows swapping.
5. **Authentication: Auth0 or Clerk in MVP.** Custom auth is not in scope. Provider interface defined for future migration.
6. **Object storage: AWS S3 in production, MinIO for local development.**
7. **No Kubernetes in MVP.** Docker Compose for development, ECS Fargate or Railway for production. K8s migration path documented.
8. **CI/CD: GitHub Actions.** Sufficient for team size < 20.
9. **Monitoring: OpenTelemetry → Grafana Cloud (or self-hosted).** No vendor lock-in.
10. **Maximum concurrent users in first 6 months: 10,000.** Architecture designed for 1M+ but infrastructure sized for 10K.

### Business Assumptions

1. **Team size at launch: 3–5 engineers.** Architecture must support this team size without excessive ceremony.
2. **Revenue model: SaaS subscription + usage-based TTS costs.** TTS is the dominant variable cost.
3. **TTS cost per 1M characters: ~$30 (ElevenLabs standard) to ~$100 (premium).** Passed through with margin.
4. **Target gross margin: 60%+** after TTS costs.
5. **Open-core model generates community contributions** to core while premium features drive revenue.

---

## 2. MVP Product Requirements

### 2.1 Document Ingestion

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| PDF upload (native text) | P0 | Text extracted with layout preservation; headers, footers, page numbers excluded from narration |
| PDF upload (scanned/image) | P0 | OCR pipeline produces text with >95% accuracy on clean scans |
| DOCX upload | P0 | Full text extracted including headings, lists, tables |
| TXT / Markdown upload | P0 | Rendered to semantic blocks; Markdown formatting interpreted |
| Web URL ingestion | P0 | Main content extracted (Readability algorithm); ads, nav, footers stripped |
| Upload size limit | P0 | 100 MB per document, 500 pages max (with warning above 500) |
| Chunking | P0 | Documents split into semantic chunks (paragraph/section boundaries); never mid-sentence |
| Non-text detection | P0 | Images, charts, tables, diagrams identified with bounding boxes |
| Non-text description | P0 | Alt-text generated for detected non-text content via vision model |
| Progress reporting | P0 | User sees real-time processing progress (uploaded → parsing → OCR → ready) |

### 2.2 Voice System

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Premium voice catalog | P0 | Minimum 20 voices across 4+ styles (narrative, conversational, formal, warm) |
| Voice browsing UI | P0 | Filter by language, gender, style; preview 10-second sample per voice |
| Voice selection per document | P0 | User selects voice before or during playback; changeable mid-session |
| SSML support | P0 | Pauses at punctuation, paragraph breaks, section transitions; emphasis on key phrases |
| Voice quality guardrails | P0 | No voice with MOS < 4.0 exposed to users; quality monitoring pipeline |
| Custom voice recording | P1 | User can record voice samples (minimum 30 seconds); stored securely |
| Consent flow | P1 | If recording another person's voice: explicit consent capture with receipt |
| Voice profile data model | P0 | Schema and API endpoints defined; recording storage in S3; metadata in Postgres |

### 2.3 Playback

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Streaming playback | P0 | Audio begins within 3 seconds of pressing play (for documents already processed) |
| Speed control | P0 | 0.5x to 3.0x in 0.25x increments; no pitch distortion |
| Pause / resume / seek | P0 | Seek to any position; resume from last position on app reopen |
| Background playback | P0 | Audio continues when app is backgrounded (mobile) |
| Caption sync | P0 | On-screen text highlights current sentence; scrolls automatically |
| Caption styling | P0 | Font size, contrast, position configurable; meets WCAG 2.1 AA |
| Queue / playlist | P1 | User can queue multiple documents for sequential playback |

### 2.4 Emotional Tone

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Rule-based classifier | P0 | Detects: neutral, formal, conversational, somber, excited; based on punctuation, keywords, document type |
| Tone → SSML mapping | P0 | Each tone maps to specific SSML parameters (rate, pitch, volume) |
| Tone override | P0 | User can force neutral tone for any document |
| Default to neutral | P0 | Legal, medical, technical content auto-detected and forced neutral |

### 2.5 Accessibility

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Image descriptions spoken | P0 | Generated alt-text narrated at the position of the image in the document |
| Screen reader compatibility | P0 | All UI elements have semantic labels; tested with VoiceOver + TalkBack |
| Keyboard navigation | P0 | Full app navigable via keyboard (desktop) |
| High contrast mode | P0 | System high-contrast settings respected |
| Caption font scaling | P0 | Captions respect system font size preferences |
| Reduced motion | P0 | Animations disabled when system prefers reduced motion |

### 2.6 Library & Retention

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Document library | P0 | List of all uploaded documents with status, date, duration |
| Search library | P1 | Full-text search across document titles and extracted text |
| 60-day TTL | P0 | Original files and derived artifacts auto-deleted after 60 days |
| Manual delete | P0 | User can hard-delete any document immediately |
| Re-upload | P0 | Deleted documents can be re-uploaded and reprocessed |

### 2.7 Security & Auth

| Requirement | Priority | Acceptance Criteria |
|-------------|----------|---------------------|
| Authentication | P0 | Email + password, Google OAuth, Apple Sign-In |
| Authorization | P0 | Users access only their own documents |
| Encryption in transit | P0 | TLS 1.3 enforced on all endpoints |
| Encryption at rest | P0 | S3 SSE-S3 for objects; Postgres TDE or column-level encryption for PII |
| Audit logging | P0 | All CRUD operations logged with user ID, timestamp, action, resource |
| Rate limiting | P0 | Per-user and per-IP rate limits on all endpoints |
| CSRF / XSS protection | P0 | Standard headers, input sanitization, CSP |

---

## 3. Roadmap

### v2 (3–6 months post-MVP)

| Feature | Description |
|---------|-------------|
| Custom voice cloning | Full voice synthesis from recorded samples; consent-verified |
| Multilingual support | Spanish, French, German, Mandarin, Japanese |
| LLM-based tone classifier | Context-aware emotion detection using fine-tuned model |
| Offline playback | Download processed audio for offline listening |
| Advanced search | Full-text search with filters (date, voice, document type) |
| Batch processing | Upload multiple documents; process in parallel |
| API access | Public API for third-party integrations |
| Team workspaces | Shared document libraries for small teams |

### v3 (6–12 months post-MVP)

| Feature | Description |
|---------|-------------|
| Real-time collaboration | Shared annotations, highlights, bookmarks |
| Publisher integrations | Ingestion from Kindle, Notion, Google Docs, Confluence |
| Podcast generation | Multi-voice document narration (different voice per speaker/section) |
| Analytics dashboard | Listening time, completion rates, popular content |
| Enterprise SSO | SAML, OIDC, SCIM provisioning |
| White-label SDK | Embed Psitta playback in third-party apps |
| Advanced prosody | User-adjustable emphasis, custom pronunciation dictionary |
| Accessibility audit certification | WCAG 2.1 AAA compliance |
