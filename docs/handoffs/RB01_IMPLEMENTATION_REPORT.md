# RB-01 — Implementation Report
## Capability Provider Lifetime Regression — Fix B

**Date:** 2026-07-22 · **Status:** Fix B implemented in the working tree — NOT COMMITTED. Fix A NOT implemented (per instruction: only if the repro survives Fix B). Reference: `docs/handoffs/RB01_LEGACY_PLAYER_ROOT_CAUSE.md`.

## 1. Implementation summary

One file changed: `apps/desktop/lib/app.dart`. Added one import (`core/capabilities.dart`) and one persistent, intentionally-empty `ref.listen<AsyncValue<Capabilities>>(capabilitiesProvider, …)` in the root `App.build`, placed directly beneath the existing billing listener and documented in full. Nothing else changed — no redesign, `autoDispose` retained, routing predicates untouched, ProjectDocumentsTab untouched.

## 2. Why Fix B is expected to be sufficient (pending the Step-2 repro)

The defect was never wrong logic — it was a cold read. The root widget is mounted for the app's entire lifetime, so its listener holds the capability chain alive continuously: the resolved capability set stays cached between screens, and every event-handler `ref.read(capabilitiesSnapshotProvider)` — including the Projects Play callback, unmodified — now returns real data. The decision rule stands: run the original repro (Projects → Documents → ▶) as Subscriber and Trial; if both land in the Writing Desk, Fix A is not implemented. **Known residual window (not a defect):** during a genuine in-flight fetch (first moments after login/auth refresh) the snapshot still fails closed — the exact same window the pre-PAC-2B billing predicate had (`PlanStatus.unavailable` → Player). Parity preserved by design.

## 3. Provider lifetime explanation

`capabilitiesProvider` is `FutureProvider.autoDispose`: it lives only while it has listeners. Screen-level `watch`es (library dispatcher, settings, voices) made it warm coincidentally, per screen. The billing chain never had this problem because `app.dart` has always held `ref.listen(planStatusProvider…)` (the downgrade guard), keeping `billingStatusProvider` alive app-wide. Fix B gives the capability chain the identical anchor. `autoDispose` is retained deliberately: with the app-level listener it never fires during ordinary usage, but the semantic (dispose when truly unobserved, e.g. in tests) is unchanged — removing it was not proven necessary.

## 4. Architectural impact

- Cold reads become impossible during ordinary desktop usage — the entire regression class is eliminated, not just this callsite.
- Fail-closed behavior preserved for genuine loading/error (snapshot still degrades to `Capabilities.free`).
- Auth chain preserved: `providers._invalidateAuthProviders` already calls `ref.invalidate(capabilitiesProvider)`; under a live subscription an invalidate triggers a refetch (loading → data), exactly like the billing chain on login/logout. No change to refresh behavior.
- Cost: one cached payload held in memory for the app's lifetime; one no-op callback per capability refresh. Negligible.
- Single point of protection: the listener itself. Its removal would silently re-arm the regression — the in-code comment names RB-01 explicitly to guard against that.

## 5. Files modified

`apps/desktop/lib/app.dart` (+24 lines: 1 import, 1 documented listener). Fix A files: none.

## 6–8. Analyzer / tests (operator commands — results to be recorded)

```bash
cd /c/products/psitta/apps/desktop
flutter analyze 2>&1 | tail -1                                   # required: 708
flutter test test/unit/core/capabilities_test.dart test/unit/core/plan_gate_test.dart 2>&1 | tail -2   # required: +33
flutter test 2>&1 | tail -6                                      # recommended once: Fix B changes provider lifetime globally
```
Full-suite justification: the change alters global provider lifetime, which is precisely the class of change the suite's provider-dependent widget tests could notice — one run to confirm the +207/2/44 baseline is warranted.

## 9. Manual validation (operator — Step 2 first, then the sweep)

**Step 2 — the decisive repro (BEFORE anything else):** Subscriber → Projects → any project → Documents → ▶ → must open **Writing Desk**. Repeat as Trial. Both pass → Fix A stays unimplemented; either fails → report it and Fix A follows as local compensation.

**Step 5 sweep:** Explore (Projects ▶ still → Player — correct for Explore), Library (Explore flows unchanged), Writing Library (open → Desk; uploads preflight still correct), Sidebar Player + player-bar Resume (still reach /player), Writing Desk playback, capability gates on Settings/Voices (unchanged), cold app startup (gates locked while genuinely loading — fail-closed intact), auth refresh + logout/login (entitlements re-resolve; no stale unlock), offline startup (Free baseline, nothing unlocks).

## 10. Cold-read audit (Step 4)

Every `ref.read(capabilitiesSnapshotProvider)` in `lib/`, post-Fix-B:

| File | Method | Warm | Cold | Risk | Recommendation |
|---|---|---|---|---|---|
| `projects/widgets/project_documents_tab.dart:99` | `_openInPlayer` | ✅ app-level listener | — | None (was THE cold site) | None — fixed at the architectural cause |
| `library/library_screen.dart:128` | `_canAcceptUploads` | ✅ app listener + screen watch (:708) | — | None | None |
| `library/library_screen.dart:236` | `_listenToDocument` | ✅ app listener + screen watch | — | None | None |
| `library/library_screen.dart:1015` | card `onRead` closure | ✅ app listener + screen watch | — | None | None |
| `library/writing_library_screen.dart:108` | `_canAcceptUploads` | ✅ app listener + dispatcher watch (:47) | — | None | None |

**Future cold-read regressions:** not possible while the app.dart listener exists — any new screen's callback reads are warmed globally. Remaining vector is deletion of the listener itself (guarded by the RB-01-named comment; recommend the PAC-2C reviewer checklist include "app.dart warm-keepers intact").

## 11. Remaining architectural risks

- The genuine-loading window (§2) — same as billing; acceptable, documented.
- The warm-keeper is a convention, not a compile-time guarantee (mitigations in §10).
- The deferred one-shell phase still leaves `/player` as a live architecture for Explore by design — unchanged by RB-01; tracked on the roadmap.

## 12. Commit message proposal (DO NOT COMMIT)

```
fix(entitlement): keep the capability chain warm app-wide (RB-01)

capabilitiesProvider is autoDispose; with no screen watching it, event-
handler reads saw a cold fail-closed Free baseline, routing entitled
users from Project Documents to the legacy Player. Add a persistent
app-level listener — the same pattern that keeps the billing chain
warm — so callback reads always see resolved entitlements. Fail-closed
loading semantics and the auth-refresh invalidation chain unchanged.
```

---
**STOP.** Fix A not implemented. No commit, no push. Awaiting the Step-2 repro result and validation numbers.
