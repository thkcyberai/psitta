# ADR-0001: Monorepo Structure

**Status:** Accepted
**Date:** 2025-02-08

## Context
Psitta consists of FastAPI backend, Flutter app, docs, CI/CD, and commercial extensions.

## Decision
Adopted monorepo with clear directory boundaries:
- `core/` — Apache 2.0 open-source backend
- `apps/` — Client applications (Flutter)
- `extensions/` — Commercial add-ons (proprietary license)
- `docs/` — All documentation

## Consequences
### Positive
- Atomic commits across backend + frontend
- Single CI pipeline validates entire system
- Easier contributor onboarding

### Negative
- CI runs slower for single-component changes
- Larger git history

### Neutral
- Extensions can be extracted later if needed
