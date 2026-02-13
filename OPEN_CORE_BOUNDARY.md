# Open-Core Boundary

Psitta uses an open-core model: the core platform is open-source (Apache 2.0), while premium features are proprietary extensions.

## Core (Apache 2.0) — `core/` and `apps/`

Everything needed to upload, process, and listen to documents:

- Document upload, parsing, chunking
- Azure Neural TTS synthesis (standard voices)
- Rule-based tone classification
- Anthropic Claude image descriptions
- Playback session management
- Flutter cross-platform app
- PostgreSQL, Redis, S3 infrastructure
- CI/CD pipelines

## Extensions (Proprietary) — `extensions/`

Premium capabilities that extend the core:

| Extension | Description |
|-----------|-------------|
| `voice-cloning` | Custom voice profile creation |
| `premium-tts` | ElevenLabs, Google Cloud TTS, Amazon Polly |
| `advanced-tone` | LLM-powered tone classification (~92% accuracy) |
| `enterprise` | SAML SSO, org management, audit export |
| `analytics` | Listening behavior and engagement metrics |

## Decision Framework

A feature belongs in **core** if:
- It is essential for the basic upload → process → listen flow
- It uses freely available or self-hostable infrastructure
- It enables the open-source community to contribute

A feature belongs in **extensions** if:
- It adds premium quality beyond the core experience
- It requires expensive third-party APIs
- It serves enterprise-specific compliance needs
- It provides competitive differentiation for paid tiers
