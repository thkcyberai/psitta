# PAC-3 — Desktop Plans Platform Alignment: Implementation Report

**Date:** 2026-07-21 · **Status:** implemented in the working tree — **NOT COMMITTED**, per instruction. Awaiting approval + operator validation.

## 1. Files modified (10)

- `apps/desktop/lib/features/auth/plan_selection_screen.dart` (+~250 net: card restructure, state derivation, portal port, `_StateBanner`, locked feature rows)
- `apps/desktop/lib/l10n/app_en.arb`, `app_es.arb`, `app_fr.arb`, `app_pt.arb` — 18 new keys each (16 simple + 2 with placeholders) + 5 vocabulary value updates
- `apps/desktop/lib/l10n/app_localizations.dart` + `app_localizations_{en,es,fr,pt}.dart` — matching getters/methods hand-mirrored (verified: every abstract member implemented in all four locales)

**Semantic diff proof (en arb):** parsed-JSON comparison against HEAD — 20 additions (18 keys + 2 placeholder metadata blocks), 0 removals, exactly 5 changed values. The larger raw line-diff on `app_en.arb` is re-indentation of existing metadata blocks from the JSON round-trip; content-identical.

## 2. Implementation summary

**Card 1 — WRITING NOOK / Explore** (was "Free / Read"): outcomes first (Create writing projects · Organize your manuscript · Listen to your writing) → "Waiting for you" header with six lock-icon rows (Blueprints, Story-Coach, Structure Analyzer, AI Writing Intelligence, Premium voices, Word & sentence highlighting) → "Technical limits" (10 documents, Standard voices — `featBasicVoices` value updated). Price $0 / "Free forever". Explore-state button: "Your current experience" (highlighted current); entitled users see a muted "Included".

**Card 2 — Writing Nook** (title, price, trial subtitle, Most Popular, checkout all kept): feature list regrouped under the six approved platform names — Writing Workspace · Story Development · AI Writing Intelligence · Reading & Revision · Project Organization · Native Desktop (header keys renamed in place: "Book development"→"Story Development", "Listening & revision"→"Reading & Revision", + 2 new headers and one new Native-Desktop row) — mirroring the WA-4 pricing page.

**States** (derived from `/billing/status` `plan` + `status` + `current_period_end` — all pre-existing payload fields):
- *Explore* (`plan == free`): Explore card highlighted current; Writing card CTA **"Start your 14-day free trial"** (new key; same `_startCheckout` flow).
- *Trial* (`status == 'trialing'`): banner **"Trial active — {N} days remaining · Ends {date}"** (days = ceil of remaining hours/24, floored at 0; date via the existing `formatResetDate` helper; banner in `primaryContainer` tone). Button: **Manage subscription** (live, outlined + open-in-new).
- *Subscriber* (`status == 'active'`): banner **"✓ Active subscription"**; button **Manage subscription**. No dead "Current Plan" button in either entitled state.
- *Non-Stripe entitled* (allowlist/dev-override — `source != 'stripe'`): keeps the disabled "Current Plan" affordance, because the portal call would 502 (KL 2026-05-22b), matching Settings' gating.
- Loading/error: prior behavior preserved (no card current, retry banner).

**Manage subscription** is a verbatim port of Settings' `_ManageSubscriptionTile` flow — same `POST /billing/portal-session`, same error mapping (404/502/network), same `billingStatusProvider` invalidate on return, reusing the existing `manageTitle`/`manageNoUrl`/`managePortalUnavailable`/`managePortalError` l10n keys. **No new backend endpoint.**

**Creative Nook card: untouched.** Checkout, polling, waitlist, toggle, routing, capabilities, backend, Stripe: untouched (grep-verified: `_startCheckout`, `_beginStatusPolling`, `_joinWaitlist` bodies unchanged).

**Widget changes (minimal, content-serving):** `_PlanFeature.locked()` mode + lock icon row; `_PlanCard.statusBanner` slot; `_buildButton` branch for an actionable current card; new `_StateBanner` widget. All in the existing style vocabulary.

## 3–5. Validation (operator commands — run before approving)

```bash
cd /c/products/psitta/apps/desktop
flutter analyze 2>&1 | tail -1
flutter test test/unit/core/capabilities_test.dart test/unit/core/plan_gate_test.dart 2>&1 | tail -2
flutter test 2>&1 | tail -6
```
Expected: analyze **708** (if new info-lints appear from the new widget code, paste the delta lines — I'll fix to parity before commit); focused **+33 passed**; full suite **+207 ~2 -44** with the baseline failure set unchanged.

Manual state verification (the four states):
- **Explore** (free account): Plans shows Writing Nook/Explore highlighted, locks + limits ordered as specified; Writing card CTA "Start your 14-day free trial" → Stripe checkout opens (test mode).
- **Trial** (trialing account): banner with correct days remaining + end date; Manage subscription opens the Stripe portal.
- **Subscriber**: "Active subscription" banner; Manage subscription works.
- **Creative waitlist**: Notify me → joined state, unchanged.
- Cross-checks: Monthly/Annual toggle still swaps prices/subtitles; checkout error snackbars unchanged; all four app languages render the new strings (language switch in Settings).

Pre-validation static evidence: all four .arb files parse as valid JSON; all 18 abstract members have all 4 concrete implementations; placeholder methods interpolate correctly (`'$days days remaining'` etc.); Dart delimiters balanced; zero references remain to the retired keys (`planTaglineRead`, `planGetStarted`, `featWordByWord`, `featDeskBlueprints`, `featStoryCoachTools` on this screen).

## 6. Screenshots

Not producible from the sandbox (Flutter app cannot run here). The §2 state descriptions are code-deterministic; operator screenshots of the four states during manual verification can be attached to the record if desired.

## 7. Git commit message (DO NOT COMMIT — awaiting approval)

```
feat(desktop): align Plans screen with the Psitta platform architecture

Card 1 becomes Writing Nook / Explore (outcomes, then locked
capabilities, then technical limits). Writing Nook card regrouped
under the six approved capability groups, with a trial banner
(days remaining + end date), an Active subscription banner, and a
live Manage subscription action reusing the Settings Stripe portal
flow. Creative Nook, checkout, polling, and waitlist unchanged.
```

Files to stage when approved: the 10 files in §1 plus `docs/handoffs/PAC3_IMPLEMENTATION_REPORT.md` and `docs/handoffs/PAC3_DESKTOP_PLANS_REVIEW.md`.

---
**STOP.** No commit, no deploy. Also still open: the Website Freeze protocol remains paused at its build step (WA-3/WA-4 changes uncommitted on the website side). Awaiting your validation results and approval.

---

## Phase 4 addendum — validation record (updated 2026-07-21)

**Initial operator validation:**
- `flutter analyze`: **712** (baseline 708; delta **+4**)
- Focused tests: **33 passed** ✓
- Full suite: **207 passed / 2 skipped / 44 known baseline failures** — byte-match, PASS ✓

**Analyzer delta isolation (diff-proven):** the file carries 16 `use_build_context_synchronously` findings. Twelve exist at HEAD with identical code (shifted +6 lines by the PAC-3 doc-comment): `_startCheckout` 95/103/107/114 (HEAD 89/97/101/108), `_joinWaitlist` 158/169/173/179/181/184 (HEAD 152/163/167/173/175/178), polling 211/220 (HEAD 205/214). **Four are PAC-3-introduced**, all in the new `_openPortal`: 253 (`manageNoUrl`), 261 (`planCouldNotOpenBrowser`), 266 (`manageBrowserMsg`), 272 (`planConnectionError` in catch) — each an `AppLocalizations.of(context)` read after an `await`. 16 − 12 = 4 = repo delta ✓.

**Minimal fix applied (one edit, `_openPortal` only):** `final loc = AppLocalizations.of(context);` captured before the first `await`; the four post-await sites now read `loc`. No lint suppression, no ignore comments, no behavior change (post-await UI still flows through `_showSnack`, which guards on `mounted`; `_handlePortalError` is synchronous and was never flagged — its two context reads match Settings' identical unflagged pattern). The twelve pre-existing findings are deliberately untouched.

**Rerun expectation:** analyzer **708** with the twelve baseline findings remaining in plan_selection_screen.dart; focused tests **+33**. Full-suite rerun not required (guard-only change) — already at exact baseline.

**Final changed-file list (PAC-3, working tree):** the 10 files of §1 (plan_selection_screen.dart now includes the null-period-end refinement + this analyzer fix). Diff summary: 10 files, ~+1,270/−150 (l10n en-arb line count inflated by cosmetic re-indentation; semantic diff proven exact in §1).

**Verdict: WITHHELD** — manual account-state validation (Explore / Trial / Subscriber / non-Stripe / Creative / 4 languages + screenshots) is still outstanding. PAC3_VALIDATION_REPORT.md with the PASS/FAIL verdict follows its completion.

## Manual validation ledger (running)

| State | Result | Evidence |
|---|---|---|
| **Active subscriber** | **PASS** | Plans showed Writing Nook current + "Active subscription" banner; Manage Subscription opened the Stripe Customer Portal end-to-end: correct Psitta Writing Nook subscription, $17.99/mo, payment method, billing information, invoice history, cancel action all loaded. Screenshot: pending operator path. |
| Manage Subscription end-to-end | **PASS** | Same session as above. |
| Explore account | PENDING | Awaiting operator run. |
| Trialing account | PENDING | Awaiting operator run. |
| Non-Stripe entitled | PENDING | Awaiting operator run. |
| Creative Nook waitlist | PENDING | Awaiting operator run. |
| EN / PT / ES / FR | PENDING | Awaiting operator run. |
| Portal round-trip ("Return to Facti AI") | PENDING | Record destination, error-free return, and post-return billing state. |

Verdict remains WITHHELD until the release-critical PENDING states (Explore, Trial at minimum) are recorded.
