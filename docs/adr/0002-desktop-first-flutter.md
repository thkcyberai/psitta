# ADR-0002: Desktop-First Flutter Application

**Status:** Accepted
**Date:** 2025-02-09
**Deciders:** Core team

## Context

Psitta's initial scaffold placed the Flutter app under `apps/mobile/` with
mobile-first assumptions (bottom navigation, single-column layouts, touch
targets). Upon clarifying product direction, the primary user persona is
a creator working at a desktop computer (Windows/macOS) who uploads and
manages documents, then listens during work sessions.

Mobile usage is planned for v2 using the same Flutter codebase.

## Decision

We adopted a **desktop-first** UX strategy:

- Renamed `apps/mobile/` → `apps/desktop/`
- Implemented desktop UX patterns:
  - **Multi-pane layout**: persistent sidebar (library nav) + content area + bottom player bar
  - **Drag-and-drop**: file upload from Finder/Explorer via `desktop_drop`
  - **Keyboard shortcuts**: Space (play/pause), Ctrl+arrows (skip), Ctrl+O (upload), Ctrl+F (search)
  - **Window management**: 1280×800 default, 900×600 minimum, via `window_manager`
  - **Visual density**: `VisualDensity.comfortable` (mouse/keyboard optimized)
- Target platforms: Windows + macOS for MVP
- Flutter Desktop with Material 3, Riverpod, GoRouter (ShellRoute for persistent shell)

## Consequences

### Positive
- Single Dart codebase extends to mobile later with responsive breakpoints
- Desktop UX matches creator workflow (long sessions, multitasking)
- Drag-and-drop eliminates friction for document upload
- Persistent player bar enables continuous listening while browsing library
- Keyboard shortcuts match power-user expectations

### Negative
- Flutter Desktop is less mature than mobile (fewer plugins, edge cases)
- Windows and macOS have different native conventions (menus, title bars)
- Some Flutter packages lack desktop support (must verify before adding)

### Neutral
- Linux support requires minimal changes when added later
- Mobile adaptation requires responsive layouts, not a rewrite
- GoRouter ShellRoute pattern works identically on all platforms
