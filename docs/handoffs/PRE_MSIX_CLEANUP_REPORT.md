# Pre-MSIX Cleanup Report
## RB03 Instrumentation Removal & Fix B Disposition

**Date:** 2026-07-22 · **Status:** cleanup complete in the working tree — NOT COMMITTED. Validation commands below for the operator.

## 1. RB03 instrumentation removed — VERIFIED

Both instrumented files were restored **byte-identical** to their pre-instrumentation state, proven by md5 against the values recorded before instrumentation:

| File | Pre-instrumentation md5 | Post-cleanup md5 | Match |
|---|---|---|---|
| `apps/desktop/lib/core/capabilities.dart` | `edaa6e6e90d67a90d90408809c6a0a48` | `edaa6e6e90d67a90d90408809c6a0a48` | ✅ |
| `apps/desktop/lib/features/projects/widgets/project_documents_tab.dart` | `101a00bd0bed33eb185570c078fe41d9` | `101a00bd0bed33eb185570c078fe41d9` | ✅ |

Repo-wide grep for `RB03`: **zero matches** in `lib/`. Both files are now clean against git HEAD (the instrumentation was their only working-tree modification — `project_documents_tab.dart`'s PAC-2B state is already committed in `f4f0765`).

## 2. Files changed (this cleanup)

The two files above (restorations). Net working-tree state after cleanup: the 10 PAC-3 files + `app.dart` (Fix B) + the WA-3/WA-4 website files (3) + the four known pre-existing modifications — i.e., exactly the pre-RB-03 state.

## 3–4. Analyzer / focused tests (operator — run to confirm)

```bash
cd /c/products/psitta/apps/desktop
flutter analyze 2>&1 | tail -1
flutter test test/unit/core/capabilities_test.dart test/unit/core/plan_gate_test.dart 2>&1 | tail -2
```
Expected: **708** and **+33 passed**. The tree is byte-identical to the state that last measured exactly these numbers (PAC-3 post-fix + Fix B), so any deviation indicates environment drift, not code.

## 5. Fix B recommendation: **KEEP**

Reasoning, against the stated criteria:
- **It improves provider lifetime without changing behavior** — the criterion for keeping. Fail-closed loading/error semantics are identical; the auth-refresh invalidation chain is identical; `autoDispose` is retained; the only change is that the resolved capability set stays cached between screens instead of being discarded whenever no screen watches it.
- **The defect it fixes is proven from code, independent of RB-03's build-identity finding.** The consumer census established that nothing on the Projects screen watches the capability chain; on any post-PAC-2B build without Fix B, an entitled user's Play tap performs a cold read and routes to the legacy Player. RB-03 showed the *screenshots* came from an old binary — it did not (and cannot) unprove the static defect. Removing Fix B would re-arm a real landmine for zero benefit.
- **Architectural consistency:** it is the exact pattern the billing chain has always used (`app.dart`'s persistent `planStatusProvider` listener). One convention, two chains.
- Caveat, honestly stated: Fix B has never been *runtime*-confirmed, because no post-Fix-B binary has ever been executed. The confirmation belongs in the RC-1 matrix (Projects → ▶ as Subscriber/Trial → Writing Desk) on a verified working-tree build — with build-identity verification via the Plans screen as step 0, per the RB-03 lesson.

## 6. Git diff summary (working tree vs HEAD, after cleanup)

- **PAC-3 (10 files, validated, awaiting commit approval):** `plan_selection_screen.dart` (+~330/−~90 incl. Phase-4 fixes), 4 `.arb` (18 keys + 5 value updates each), 5 generated localization classes.
- **RB-01 Fix B (1 file):** `app.dart` +24 (1 import, 1 documented listener) — recommend committing with or immediately after PAC-3.
- **WA-3/WA-4 website (3 files, approved, part of the paused Website Freeze):** `download/page.tsx`, `support/page.tsx`, `PricingTiers.tsx`.
- **Pre-existing, deliberately untouched:** `CLAUDE.md`, `api_client.dart`, `auth_service.dart`, `NewsletterForm.tsx`.
- **RB-03 residue:** none (this report's subject).

---
**STOP.** No commit, no push, no MSIX. Outstanding queue for the record: PAC-3 manual validation + commit gate, Website Freeze completion (commits/push/public verification), RB-03's runtime capture (now optional — its remaining value is the runtime confirmation of Fix B and the capability payload, both foldable into the RC-1 matrix on a verified build), then RC-1 → MSIX 1.2.0. Awaiting approval.
