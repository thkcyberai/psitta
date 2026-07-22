# PAC-3 — Validation Report
## Desktop Plans Platform Alignment — Final Verdict (Option A evidence basis, approved)

**Date:** 2026-07-23 · **Release context:** Psitta 2.0.0 · **Evidence rule:** everything below is classified VALIDATED (with its evidence), NOT VISUALLY VALIDATED (honestly), or PENDING RC-1. Nothing is fabricated.

## Executive summary

PAC-3 replaced the retired "Free / Read" three-product Plans screen with the platform model: WRITING NOOK / Explore (outcomes → locked capabilities → technical limits), one Writing Nook card across Trial/Subscriber states with live banners and Manage-subscription, and an untouched Creative Nook. All automated gates are green at exact baselines. Manual evidence covers the subscriber journey end-to-end and a clean-state four-language run of the working-tree build; the Trial banner is the one surface not yet seen by human eyes — explicitly deferred to RC-1 on the 2.0.0 MSIX. **Verdict: READY FOR COMMIT.**

## Static review — VALIDATED
Scope exactly the 10 approved files; Creative card, checkout, polling, waitlist bodies diff-proven unchanged; no backend/Stripe/capabilities/navigation changes; all four .arb files valid JSON; all 18 new l10n members implemented in all four generated locale classes; semantic arb diff proven exact (20 additions / 0 removals / 5 planned value changes); no raw-English regressions (brand tierNames pre-existing).

## Analyzer — VALIDATED: **708** (exact baseline)
Initial run 712; the +4 delta was diff-isolated to four PAC-3 `use_build_context_synchronously` findings in the new `_openPortal`, fixed with a single pre-await localization capture; the twelve pre-existing baseline findings remain untouched. Rerun: 708.

## Focused tests — VALIDATED: **33 passed** (12 capability contract + 21 entitlement contract)

## Full suite — VALIDATED: **207 passed / 2 skipped / 44 known baseline failures**, failure set byte-matched.

## Manual validation — classified honestly

**VALIDATED — Subscriber (recorded evidence):** Plans showed Writing Nook current with the "Active subscription" banner; Manage Subscription opened the Stripe Customer Portal end-to-end — correct Psitta Writing Nook subscription, $17.99/mo, payment method, billing information, invoice history, cancel action all present. *Caveat recorded for the audit trail: this session predates the RB-03 build-identity finding; its observations are consistent only with a working-tree build, and the portal-side evidence (Stripe-hosted) is binary-independent.*

**VALIDATED — Clean-state working-tree run (yesterday's breakthrough session):** after full uninstall + local-state reset, the working-tree build (PAC-3 + Fix B included) ran correctly: Projects → Documents → Play opened the **Writing Desk**; the Writing Nook experience rendered correctly in **English, Portuguese, Spanish, and French** — exercising the PAC-3 l10n layer (new keys compiled and rendered in all four locales with no missing-key errors).

**NOT VISUALLY VALIDATED — Trial state:** the "Trial active — N days remaining · Ends {date}" banner and Manage-subscription-while-trialing have not been seen by human eyes. Code-level confidence: the derivation is pinned by the entitlement contract tests and the banner shares its rendering path with the validated subscriber banner. **Deferred to RC-1** (H2/H3 rows) on the 2.0.0 MSIX with a trialing test account.

**NOT VISUALLY VALIDATED — Non-Stripe entitled** (allowlist disabled-Current-Plan affordance) and **Explore-state checkout launch** (CTA → Stripe test checkout). The Explore card's rendering itself was covered by the clean-state run's Free-account phase; the checkout click-through and allowlist state land in RC-1.

**VALIDATED — Creative Nook:** diff-proven byte-untouched; waitlist behavior unchanged by construction.

## Pending RC-1 (explicit carry-list)
Trial banner visual + trial portal; Explore CTA → test-mode checkout click-through; non-Stripe entitled affordance; Monthly/Annual toggle spot-check on the installed MSIX; screenshots for the record. All rows exist in RC1_SMOKE_MATRIX.md; RC-1 step 0 = build-identity verification via the Plans screen (RB-03 lesson).

## Files changed / diff summary
The 10 files of the implementation report §1; net ~+1,280/−150 including Phase-4 fixes (en-arb line count inflated by cosmetic re-indentation, semantically exact).

## Final verdict

✅ **READY FOR COMMIT** — with the Trial-state visual validation honestly recorded as outstanding and formally carried into RC-1, per the approved Option A basis.
