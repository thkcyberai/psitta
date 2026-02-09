# Open-Core Boundary

Psitta follows an **open-core** licensing model. This document defines the boundary between the freely available core and commercial extensions, and provides guidance for contributors and adopters.

## Licensing Overview

| Component | License | Location |
|-----------|---------|----------|
| Core platform | Apache 2.0 | `core/`, `apps/`, `docs/` |
| Commercial extensions | Proprietary | `extensions/` |
| Documentation | CC BY 4.0 | `docs/` |

## Core (Apache 2.0)

The core includes everything needed to run a fully functional document-to-audio narration pipeline. A self-hosted deployment using only core components is a first-class, production-ready experience — not a crippled demo.

### What's in Core

**Document Processing**
- PDF, EPUB, DOCX, HTML, Markdown ingestion
- Text extraction and intelligent chunking
- Table and list detection
- Image/chart extraction with alt-text generation (via Anthropic Vision)
- Rule-based tone classification (headings, emphasis, quotes, code)

**Text-to-Speech**
- Azure Cognitive Services TTS integration
- Static voice catalog with built-in voice options
- Speed control (0.5x–3.0x)
- Per-chunk audio generation and caching

**Playback**
- Streaming audio playback with seek and resume
- Playback session persistence (position, speed, voice preferences)
- Chunk-level navigation (jump to heading, paragraph, table)

**API & Infrastructure**
- Complete REST API (documents, playback, voices, users)
- JWT authentication via OIDC (Auth0, Clerk)
- PostgreSQL data layer with Alembic migrations
- Redis caching and job queue (Streams)
- S3-compatible object storage
- Rate limiting, request tracing, structured logging
- Docker Compose deployment

**Client**
- Flutter cross-platform app (iOS, Android, Web)
- Offline playback support
- Accessibility features

### Core Design Principles

1. **No artificial limits.** Core doesn't cap document size, user count, or audio quality to push upgrades.
2. **Provider interfaces are public.** Anyone can write a custom TTS or storage provider.
3. **All APIs are stable.** Extensions use the same public API as community integrations.

## Extensions (Commercial)

Extensions add capabilities that serve specific enterprise or premium use cases. They are optional and never required for core functionality.

### What's in Extensions

**Voice Cloning** (`extensions/voice-cloning/`)
- Custom voice profile creation from audio samples
- Neural voice model training and hosting
- Consent management workflows with legal compliance
- Voice similarity scoring and quality metrics

**Premium TTS Providers** (`extensions/premium-tts/`)
- ElevenLabs integration (high-fidelity neural voices)
- Google Cloud TTS (WaveNet/Neural2 voices)
- Amazon Polly (Neural engine)
- Provider failover and cost optimization routing

**Advanced Tone Analysis** (`extensions/advanced-tone/`)
- LLM-powered tone classification (sarcasm, urgency, emotion)
- Context-aware reading style adaptation
- Multi-speaker dialogue detection and voice assignment
- Custom tone rulesets per organization

**Enterprise Features** (`extensions/enterprise/`)
- SAML/SCIM SSO integration
- Organization management and team workspaces
- Usage analytics and billing dashboards
- Audit log export (SIEM integration)
- SLA-backed support tier

**Analytics** (`extensions/analytics/`)
- Listening behavior analytics
- Content engagement scoring
- A/B testing for voice and speed preferences
- Custom reporting and data export

### Extension Architecture

Extensions are loaded as Python packages that register themselves via entry points:

```python
# extensions/premium-tts/pyproject.toml
[project.entry-points."psitta.providers.tts"]
elevenlabs = "psitta_premium_tts.elevenlabs:ElevenLabsTTSProvider"
google = "psitta_premium_tts.google:GoogleTTSProvider"
```

The core discovers extensions at startup and makes them available through the same provider interface:

```python
# Core provider interface (Apache 2.0)
class TTSProvider(Protocol):
    async def synthesize(self, text: str, voice_id: str, speed: float) -> AudioSegment: ...
    async def list_voices(self) -> list[VoiceInfo]: ...

# Extension implementation (Commercial)
class ElevenLabsTTSProvider:
    async def synthesize(self, text: str, voice_id: str, speed: float) -> AudioSegment:
        # ElevenLabs-specific implementation
        ...
```

## Decision Framework for Contributors

When deciding where a contribution belongs, use this framework:

```
Is this needed for basic document → audio conversion?
├── Yes → Core
└── No
    ├── Does it require a paid third-party service?
    │   ├── Yes, and there's no free alternative → Extension
    │   └── Yes, but a free tier works → Core (with free-tier defaults)
    └── Is it an enterprise/team management feature?
        ├── Yes → Extension
        └── No → Probably Core (open an issue to discuss)
```

### Examples

| Feature | Placement | Reasoning |
|---------|-----------|-----------|
| New file format parser (e.g., .odt) | Core | Basic document processing |
| Azure TTS voice additions | Core | Uses existing core provider |
| ElevenLabs integration | Extension | Premium paid service |
| Rate limiting improvements | Core | Infrastructure security |
| SAML SSO | Extension | Enterprise feature |
| Accessibility improvements | Core | Fundamental UX |
| Usage billing dashboard | Extension | Commercial feature |
| Bug fix in any layer | Core or Extension | Wherever the bug lives |

## For Self-Hosters

You can run Psitta entirely on core components. The extension entry points will simply have no registered providers, and the system will use core defaults. No configuration changes are needed — extensions are additive, never required.

## For Extension Developers

If you're building a commercial extension:

1. Create a new directory under `extensions/your-extension/`
2. Implement the relevant `Protocol` interfaces from `core/backend/src/psitta/providers/`
3. Register via entry points in your `pyproject.toml`
4. Add tests that verify integration with core interfaces
5. Document the extension in `extensions/your-extension/README.md`

Extension code must not modify core files. If you need a new core interface or hook point, propose it as a core change first.
