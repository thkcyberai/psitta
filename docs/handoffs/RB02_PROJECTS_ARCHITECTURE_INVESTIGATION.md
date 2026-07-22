# RB-02 — Why is Projects Still Entering the Legacy Reading Experience?
## Investigation (no code changed)

**Date:** 2026-07-22 · **Evidence base:** the operator's two screenshots as itemized in the RB-02 brief (the image files did not reach this session — the itemized UI evidence is specific enough for string-level widget identification, and every conclusion below is tied to repository code, not inference). **Honesty note up front: the RB-01 investigation was incomplete.** Its cold-read finding is real and its fix is sound, but it explained only the navigation predicate — the new evidence shows the user is inside an entire legacy *experience*, which a routing predicate alone cannot produce. This report follows the new evidence.

---

## 1. Executive Summary

Screenshot 1 is **identified with certainty as the legacy `LibraryScreen`** — it is the only widget in the codebase that renders the itemized right-panel actions ("Listen" primary button = `libListen`, "View Details" = `libViewDetails`, "Edit Text" = `libEditText`, plus a Writing Desk quick-action carrying a `TODO(temp)` comment). Its "Reading-style" chrome is also explained: `LibraryScreen` wraps itself in its **own `AppShell` without `isWritingShell: true`** (line 1109) — the legacy Reading chrome, self-inflicted by that screen alone. Screenshot 2 is the legacy `PlayerScreen`, reached from that panel's Listen action.

This chain matters because **the legacy `LibraryScreen` is only reachable through one gate**: the `/library` dispatcher renders it *only when the session's capability resolution lacks `writing_desk`*. So the screenshots prove something much stronger than a bad Play destination: **at the moment of capture, this session resolved as Explore/Free across the capability system — while the same account's billing-driven surfaces (the PAC-3 Plans screen, the Stripe portal) validated as an active subscriber.** The Projects screen itself is NOT legacy (§3). The defect is that an entitled session is receiving Free capability data — or the binary under test predates the capability architecture entirely. Two hypotheses survive the evidence; each has a one-minute discriminating test (§8). Naming a single root cause today would repeat RB-01's mistake.

## 2. Screenshot Analysis (Task 1)

**Screenshot 1 — answer: C, the legacy Reading-era Library** (`features/library/library_screen.dart`), with repository proof: `libListen` used only at library_screen.dart:1358 (primary FilledButton "Listen"); `libViewDetails`/`libEditText` only at :1478/:1484; the Writing Desk quick-action at :1489 (`loc.navWritingDesk`, commented `TODO(temp): remove once Project CTAs wire the real entry point`); detail panel behind `_selectedDocId` state; legacy chrome from the screen's own `AppShell(...)` at :1109 — the only screen in the app that self-constructs an AppShell, and it omits `isWritingShell: true`. **Screenshot 2** — legacy `PlayerScreen` (`features/player/player_screen.dart`; "Player / {id}" header, chunk/page thumbnails = its navigator).

**Reachability chain of the widget in screenshot 1:** only `LibraryRoute` (writing_library_screen.dart:41-50) constructs `LibraryScreen`, and only when `ref.watch(hasCapabilityProvider(Capability.writingDesk))` is **false**. This is a *reactive watch* — if capabilities later resolved entitled, the screen would rebuild into `WritingLibraryScreen`. A persistently-visible legacy library therefore means **steady-state Free capability data in that session**, not a loading race.

## 3. Projects Architecture (Task 3)

The Projects surface is **current platform architecture throughout**: `project_documents_tab.dart` imports `core/capabilities.dart`, the current `Document` model, current `project_providers`/`providers`/`document_actions`/`project_repository`, go_router, and the current cover widget — zero legacy widgets, controllers, models, routes, or shell. Its Play callback is the PAC-2B capability predicate with the correct current destinations. **Nothing in Projects is legacy; Projects is the victim, not the culprit.** The legacy experience begins only after navigation, at surfaces gated by capability resolution.

## 4. Current Navigation Graph (as evidenced)

```
Projects (current) → Project (current) → Documents tab (current)
  → ▶ _openInPlayer → caps.has(writing_desk) == FALSE  ← the session resolves Free
    → /player/{id}?origin=project  … AND/OR the operator reaches /library
  /library → LibraryRoute dispatcher → has(writing_desk)==FALSE → LEGACY LibraryScreen
    (self-built Reading AppShell chrome)  ← SCREENSHOT 1
    → detail panel "Listen" → _listenToDocument → has(writing_desk)==FALSE
      → /player/{id}  → legacy PlayerScreen  ← SCREENSHOT 2
```

## 5. Expected Navigation Graph

```
Projects → Documents → ▶ → caps.has(writing_desk) == TRUE (entitled)
  → /writing-desk/{id}?projectId=…  → Writing Desk (one shell, current chrome)
/library → dispatcher → TRUE → WritingLibraryScreen
```
**The divergence is not in any arrow — every arrow is correct. The divergence is in the boolean feeding them: an entitled account is evaluating `has(writing_desk) == false` in steady state.**

## 6–7. Comparison — Library / Writing Library / Writing Desk / Projects (Task 4)

| Surface | Doc architecture | Chrome | Gate | Legacy? |
|---|---|---|---|---|
| Projects + Documents tab | current models/providers | shell (Writing) | capability predicate (correct) | No |
| Writing Library | current | shell (Writing) | dispatcher `writing_desk` | No |
| Legacy Library | legacy layout + detail panel | **self-built AppShell, Reading chrome** | renders only when caps lack `writing_desk` | Yes — by design, Explore-only |
| Writing Desk | current (Quill/desk panes) | shell | route + in-desk gates | No |
| Player | legacy listening surface | player chrome | reachable for Explore + as listening mode | Yes — by design this release |

**Two document architectures co-exist by design (until the deferred one-shell phase); the defect is which one an entitled session is being served.**

## 8. Actual Root Cause (Tasks 6–7)

**Task 6 — are RB-01 and Fix B related? Fix B solved the problem it targeted — YES, the provider-lifetime cold-read is real and eliminated (mechanism verified statically). But it cannot explain these screenshots**, because the dispatcher `watch`es reactively (no cold read involved), and a persistent legacy library means the capability *data* is Free in steady state. RB-01's conclusion was **incomplete**: it fixed a genuine landmine on the navigation predicate while the deeper condition — the session resolving Free — remained unexamined, because the legacy-library evidence didn't exist yet.

**The new root cause is one of exactly two possibilities; the repository evidence eliminates everything else:**

- **H1 — The running binary predates the capability architecture.** If the screenshots were taken in the *installed* MSIX (1.1.2.0 or older) rather than a working-tree build, none of PAC-2B/Fix B is in the binary, and an old-enough build routes Projects→Play to the Player unconditionally and shows the legacy library/chrome exactly as photographed. Supporting: the PAC-3 subscriber validation (with its "Active subscription" banner, which exists *only* in the working tree) evidently ran a different, newer build — a mixed-build test session is a plausible operator workflow.
- **H2 — The capability fetch returns/fails to Free for this entitled session at runtime.** Server-side divergence is effectively ruled out — `/users/me/capabilities` and `/billing/status` call the identical resolver (`get_effective_plan(db, user_id, email)`; users.py:65, billing.py:472) and the client path matches the mounted route (`/users` + `/me/capabilities`). What static analysis cannot rule out: the request erroring in this environment (auth/timing/5xx), leaving the snapshot at the fail-closed Free baseline. Notable: **the PAC-2B smoke matrix — the runtime verification of capability gating — was never executed** (superseded by the freeze/PAC-3 pivots), so `/users/me/capabilities` has never been runtime-confirmed against a live entitled session.

**Discriminating tests (minutes, decisive):**
1. **Binary check (H1):** in the exact app session that produced the screenshots, open Plans. New Explore card + "Active subscription" banner → working-tree build (H1 dead). Old three-card "Free/Read" screen → old binary (H1 confirmed, investigation closed).
2. **Payload check (H2):** with the operator's token, `GET /users/me/capabilities` (curl or app log). `plan: writing_nook_pro` + full capability list → endpoint healthy (H2 dead). Free payload or error → H2 confirmed, and the response/status pinpoints the layer.

## 9. Recommended Fix (NOT implemented)

Run the two discriminators first — the fix differs completely. H1 → no code fix: re-run all manual validation on a clearly identified working-tree build (add "verify build identity via Plans screen" as step 0 of every manual protocol). H2 → fix at the layer the payload identifies (auth header timing, endpoint error, or data), then re-run. In both futures, RB-01's Fix B stays (independently correct), and the PAC-2B runtime smoke matrix must finally be executed before RC-1.

## 10. Affected Files

None yet — pending discrimination. H1: none (process). H2: to be determined by the payload (candidates: client dio/auth wiring in `capabilities.dart` fetch, or backend `users.py`/resolver — but only evidence may pick). Documentation: this report; RB-01 report already updated to "correct but incomplete."

## 11. Risk Assessment

Highest risk is **acting before discriminating** — an H2-style code change under H1 reality (or vice versa) burns the baseline for nothing. Second risk: manual validation without build-identity verification has now produced two release-blocker investigations; every future manual result is suspect until step-0 build identification is adopted. Third: the capability system's runtime health is unverified territory until the payload check runs.

## 12. Validation Plan

1. Discriminator 1 (build identity) and 2 (capabilities payload) — record both outcomes verbatim.
2. Branch on outcome per §9; any code change then follows the standard gates (analyze 708, focused 33, full suite baseline).
3. Execute the deferred PAC-2B runtime smoke rows (library dispatcher, gates) on a verified working-tree build, all three account states.
4. Re-run the RB-01/RB-02 repro end-to-end: Projects → ▶ as Subscriber and Trial → Writing Desk; legacy library unreachable for entitled sessions.

---
**STOP.** Investigation only — no code written or modified. Awaiting the two discriminator results and approval.
