# RB-01 — Why is the Legacy Player Still Reachable?
## Root Cause Investigation (investigation only — no code changed)

**Date:** 2026-07-22 · **Reported behavior:** Projects → any project → Documents → ▶ Play → legacy Player/Reading-Desk screen, for every document in every project. · **Repo state investigated:** `develop` @ `180584e` + PAC-3 working tree.

---

## 1. Executive Summary

The behavior is **a deterministic entitlement-resolution bug introduced by PAC-2B commit 5 (`f4f0765`), unique to the Project-Documents path** — not a stale route, not a forgotten migration of the button, and not the intended Explore routing misfiring.

The Play callback decides its destination with `ref.read(capabilitiesSnapshotProvider)`. That snapshot **fails closed to the Free baseline whenever the underlying `capabilitiesProvider` — a `FutureProvider.autoDispose` — has no active listener**. On the Projects screen, nothing watches the capability chain, so the provider is disposed; every tap re-creates it in `AsyncLoading`, the snapshot synchronously reports `Capabilities.free`, `has(writing_desk)` is false, and the code takes the Explore branch to `/player/...` — **even for a fully entitled subscriber, 100% of the time**. This exactly matches "every document inside every project."

Before PAC-2B, the same callback read the **billing** chain (`planStatusProvider.plan == 'writing_nook_pro'`), which is kept warm app-wide by a persistent `ref.listen` in `app.dart` — so reads returned real data and entitled users were routed to the Writing Desk correctly. The PAC-2B predicate swap changed the *data source* from an always-warm chain to a sometimes-cold chain; behavior parity held on every screen that watches capabilities in its build (library, settings, voices), and broke on the one screen that only `read`s them in a callback.

Separately — and important context — the `/player` route itself is **intentionally reachable** in this release: Explore users listen there by design, and the desk/sidebar/player-bar link to it as the focused listening surface. The one-shell "universal desk routing + legacy deletion" phase from the PAC-1 roadmap was **deferred, not completed**, when the PAC-3 label was reassigned to the Plans-screen alignment. So: legacy Player reachable for Explore = by design (this release); legacy Player reachable for *entitled users from Projects* = the defect.

## 2. Navigation Trace (Task 1)

```
ProjectsScreen → project detail → ProjectDocumentsTab (features/projects/widgets/project_documents_tab.dart)
  ├─ ▶ IconButton (line 79–82, Icons.play_circle_outline, tooltip tipPlay)
  │     onPressed: () => _openInPlayer(context, ref, doc)
  └─ row onTap (line 86) → _openInPlayer(context, ref, doc)     ← both paths converge

_openInPlayer (line 92):
  1. activeDocumentIdProvider ← doc.id ; currentDocTitleProvider ← doc.title
  2. hasWritingDesk = ref.read(capabilitiesSnapshotProvider).has(Capability.writingDesk)   ← line 99, THE DECISION
  3. true  → context.go('/writing-desk/${doc.id}?projectId=…')
     false → context.go('/player/${doc.id}?origin=project&projectId=…&projectName=…')     ← line 104, OBSERVED

Router (core/routing/app_router.dart):
  '/player/:documentId' (line 115) → PlayerScreen(documentId, originProjectId)   ← the legacy Reading surface
  '/writing-desk/:documentId' (line 216) → Writing Desk (with unsaved-edit exit guard)

Why line 99 returns false for a subscriber:
  capabilitiesSnapshotProvider ← capabilitiesProvider (FutureProvider.autoDispose, GET /users/me/capabilities)
  On /projects, ZERO widgets watch the chain (see §4 consumer census) → provider disposed
  ref.read on a disposed autoDispose provider → re-created in AsyncLoading
  snapshot.when(loading: () => Capabilities.free)  → fail-closed baseline → has(writing_desk) = false
  (After the tap, still no listeners → disposes again → next tap identical. Deterministic.)
```

The "legacy" look the operator recognized — "Player / {document id}" header, legacy chrome — is `PlayerScreen` (features/player/player_screen.dart) rendering inside the shell with the player-route chrome branches in `app_shell.dart` (e.g. lines 612–626, 723). It *is* the legacy reading surface; the app routed there.

## 3. Playback Architecture Comparison (Task 2)

| Entry point | Decision source | Warm at click time? | Destination (entitled) | Verdict |
|---|---|---|---|---|
| **Projects → Documents ▶ / row tap** | `ref.read(capsSnapshot)` in callback | **NO — nothing on /projects watches caps** | **/player (WRONG)** | **DEFECT — unique to this path** |
| Library (legacy screen; renders for Explore only) → open/onRead | `ref.read(capsSnapshot)` lines 236/1015 | Yes — LibraryScreen build `watch`es caps (line 708) | n/a (screen unreachable for entitled users; Explore → /player is intended) | Correct |
| Library (legacy) edit path (line 84 → `/player?edit=1`) | unconditional | — | Explore-only surface | Intended legacy behavior |
| Writing Library (entitled) → open | dispatcher `LibraryRoute` `watch`es `hasCapabilityProvider(writingDesk)` (line 47) — parent keeps chain warm for the whole /library visit | Yes | /writing-desk | Correct |
| Sidebar "Player" nav (sidebar_nav 172–175), player-bar Resume (app_shell 620), `/player` → PlayerLandingScreen | unconditional | — | /player | **Intended** — /player is the focused listening surface this release (PAC-1 §12.4 decision) |
| Writing Desk internal listen | in-desk playback | — | stays in desk | Correct |

**Two playback architectures do co-exist** (Writing Desk playback + the legacy Player surface) — by explicit, documented design for this release. The Projects flow is the **only** path where an *entitled* user is routed into the legacy one.

## 4. Legacy Player Inventory (Task 3)

**Consumer census of the capability chain (watch = keeps warm; read = needs someone else's watch):** watches — writing_library_screen:47 (dispatcher), :420 (rail); library_screen:708; settings_screen:114; voice_selector_screen:31. Reads — library_screen:128, :236, :1015 (warm via :708); writing_library_screen:108 (warm via :47); **project_documents_tab:99 (COLD — the defect)**. App-level: `app.dart:110` persistently listens to the **billing** chain only; nothing keeps capabilities warm globally.

**Everything capable of opening the old Player:**

| Reference | Classification |
|---|---|
| `project_documents_tab.dart:104` (`/player` branch of `_openInPlayer`) | **ACTIVE — defective for entitled users** (correct for Explore) |
| Router `'/player'` → PlayerLandingScreen; `'/player/:documentId'` → PlayerScreen | ACTIVE — intended listening surface this release |
| sidebar_nav.dart:38/172–175 (Player nav item) | ACTIVE — intended |
| app_shell.dart:620 (Resume button; inside `!isWritingShell` branch), :723 (path checks) | Partially DEAD (the `!isWritingShell` branch is unreachable since `isWritingShell` is hardcoded true) / ACTIVE path-checks |
| library_screen.dart:84 (`edit=1`), :241, :1022 (`/player` branches) | LEGACY BUT REACHABLE — Explore-only surface, intended this release |
| `features/player/` (player_screen, player_landing_screen, widgets, chunk_slicer, spellcheck) | ACTIVE — the listening surface itself |
| Legacy Reading chrome in app_shell (`!isWritingShell` branches), legacy sidebar brand header | DEAD CODE (unreachable; quarantined since Phase 1 for the deferred one-shell cleanup) |

## 5. Root Cause (Task 5)

**Evidence-supported answer: a data-source regression in PAC-2B commit 5 — the destination predicate was swapped from the always-warm billing chain to the sometimes-cold autoDispose capabilities chain, and this callsite is the only one that `ref.read`s that chain from a screen that never watches it.** Fail-closed-by-design then does exactly what it promises — it fails closed — routing entitled users down the Explore branch. Diff proof: `git show f4f0765~1` shows the predecessor `ref.read(planStatusProvider).plan == 'writing_nook_pro'`, warm via app.dart's persistent listener; parity analysis at the time verified populations and statuses but missed provider *lifetime* differing per screen. Not a stale route, not a stale callback, not a forgotten widget migration, not an intentional legacy path (for this population).

## 6. True Scope (Task 6)

**A single isolated defect — one callsite, one screen — sitting on top of one documented architectural fragility, plus one deferred roadmap phase.** Evidence: the consumer census shows exactly one cold `read` (project_documents_tab:99); every other read is warmed by a same-screen or parent watch — but that warmth is *coincidental coupling* (e.g. writing-library uploads are safe only because the dispatcher happens to watch). The fragility class — "callback reads of a fail-closed autoDispose snapshot" — will re-bite any future screen that doesn't watch. And `/player` remains a live architecture because the one-shell completion phase (universal desk routing, legacy chrome deletion) was deferred when PAC-3 was redefined; that is a roadmap fact, not a defect. RB-01 is therefore NOT evidence that the 5-day consolidation silently failed — the website, entitlement, and Plans work all hold; this is the known-deferred shell phase intersecting one cold-read bug.

## 7. Recommended Fix (Task 4 + 7 — NOT implemented)

**Intended architecture:** Play from Project Documents must open `/writing-desk/${doc.id}?projectId=…` for any user with the `writing_desk` capability (Trial ≡ Subscriber), and `/player/...` for Explore — identical to the Writing Library behavior. (Post-shell-collapse, a future phase routes everyone to the desk; unchanged advice from PAC-1.)

**Fix A (surgical, this defect):** make `ProjectDocumentsTab` `watch` the capability snapshot in `build` and use the watched value in `_openInPlayer` (or pass `hasWritingDesk` down). One file; restores warm, reactive data on the screen that navigates.

**Fix B (architectural hardening, recommended alongside or as first PAC-2C item):** keep the capabilities chain warm app-wide exactly like the billing chain — an app-level `ref.listen(capabilitiesProvider, …)` in `app.dart` (or drop autoDispose in favor of explicit invalidation, which already exists via `_invalidateAuthProviders`). This eliminates the entire cold-read class while preserving fail-closed semantics for genuine loading/error states.

Recommend A + B together: A fixes the user-visible defect independently; B removes the landmine.

## 8. Files likely to change

- `apps/desktop/lib/features/projects/widgets/project_documents_tab.dart` (Fix A)
- `apps/desktop/lib/app.dart` (Fix B — one listener block)
- Optionally `core/capabilities.dart` doc-comment (record the warm-keeper contract)
- Test: a regression unit/widget test pinning "entitled → desk route from the project tab" would need billing/caps mocks — feasibility to be assessed in the fix phase.

## 9. Risk Assessment

Fix A: LOW — one watch + predicate source change on one screen; no routes, no backend, no Stripe. Fix B: LOW/MEDIUM — app-level listener changes provider lifetime globally (memory: one cached payload; behavior: reads become warm everywhere); fail-closed loading semantics unchanged; must not disturb the auth-refresh invalidation chain (`_invalidateAuthProviders` already invalidates capabilities).

## 10. Regression Surface

Project tab open/play (both callbacks) for all three states; writing-library open + uploads (must stay warm); legacy library flows for Explore (must still reach /player); sidebar Player nav + player-bar Resume (must keep working); capability gates on settings/voices (unchanged); cold-start fail-closed behavior (I1 in the RC-1 matrix — verify locks still render while genuinely loading).

## 11. Recommended validation plan

1. Focused: existing 33 unit tests stay green; add (if feasible) the entitled-routing regression test.
2. `flutter analyze` 708 parity; full suite +207/2/44 baseline.
3. Manual: subscriber → Projects → ▶ → **Writing Desk opens** (the RB-01 repro, inverted); trial account same; Explore → /player still; Writing Library open still desk; sidebar Player + Resume still work; airplane-mode cold start → gates locked (fail-closed intact).
4. Re-run the affected RC-1 matrix rows (6, and the I-section cross-check).

---
**STOP — investigation only.** No code changed, no commit, no push. Awaiting approval to implement Fix A (+B).
