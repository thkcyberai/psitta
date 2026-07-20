# PHASE 2 — Commercial Flow Verification Report

**Date:** 2026-07-20 · **Repo:** thkcyberai/psitta (working tree `C:\products\psitta`, branch `develop`)
**Scope:** Verify the consolidated commercial flow (Visitor → Pricing → Checkout → Billing → Subscription → Portal) and the four pre-Phase-2 consistency checks (Creative Nook CTA, metadata, search/indexing, visible illustrations).
**Method:** Read-only inspection of the working tree plus durable A4 evidence for the live Stripe side. No production Stripe mutation, no production DB access, no deploys. One repo fix made (below).

---

## 1. Verification checklist

### Commercial-flow items (from the Phase 2 spec)

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Writing Nook is the ONLY purchasable product | **PASS** | Backend `billing.py` `VALID_LOOKUP_KEYS = {writing_nook_pro_monthly, writing_nook_pro_annual}` — any other lookup_key gets HTTP 400. Desktop has exactly one checkout call site: `_startCheckout('writing_nook_pro')` (plan_selection_screen.dart:438). Website has no checkout links at all — pricing CTAs point to `/download`. Live Stripe catalog (A4 migration, 2026-07-20): all Reading/legacy products and prices archived; only Writing products active. |
| 2 | Creative Nook appears only as Coming Soon | **PASS** | Website `PricingTiers.tsx`: `CREATIVE = {comingSoon: true, waitlist: true}` — renders `CreativityWaitlistForm`, no `cta.href`. Desktop `_creativeCard()`: `comingSoon: true`, button is `planNotifyLaunch`/`planOnWaitlist`, `onPressed: _joinWaitlist` (POST `/waitlist/creativity-nook`) — no checkout path. Backend comment codifies it: "Creative Nook is roadmap-only and gets no checkout path until it ships." Waitlist endpoint exists and is mounted (`api/v1/waitlist.py`, router.py:152). |
| 3 | Reading Nook cannot be purchased | **PASS** | No `reading_*` lookup key in `VALID_LOOKUP_KEYS` → checkout returns 400. No client surface offers it (Reading card/tier deleted in Phase 1). Live Stripe: 4 legacy products + 6 prices archived with rollback records (`_a4_stripe/rollback_records/live_catalog_migration_2026-07-20.json`); archived prices cannot start new subscriptions. |
| 4 | Pricing pages are correct | **PASS (after fix F1)** | Website `/pricing`: Free / Writing ($17.99/mo, $183/yr = $15.25/mo, "14-day free trial", Most Popular) / Creative (Coming Soon, waitlist). Desktop plan screen mirrors it, with `planTrial14` on both billing periods. Meta description fixed (F1 below). |
| 5 | Checkout creates only Writing subscriptions | **PASS** | Server-side allowlist (item 1) is the enforcement point — client input cannot widen it. `subscription_data={"trial_period_days": 14}` applied to every new Checkout session; duplicate-subscription guards list Stripe subs with `status=all` and block a second active/trialing sub. |
| 6 | Billing reflects only Writing | **PASS** | `/billing/status` canonicalizes grandfathered plans via `plan_limits._LEGACY_PLAN_ID_ALIASES` (`pro_monthly`/`pro_annual`/`reading_nook_pro` → `writing_nook_pro`); billing.py:717 maps `reading_nook_pro → writing_nook_pro`. Client display maps (quota_gate, settings_screen) render every paid legacy id as "Writing Nook Pro". `status ∈ {active, trialing}` accepted end-to-end (resolver SQL, webhook mirror, client polling/gates). |
| 7 | Customer Portal remains correct | **PASS (with note R2)** | `POST /billing/portal-session` intact and gated to real Stripe subscribers only (`isStripeSubscribed`: plan≠free ∧ status=active ∧ source=stripe), so tester-allowlist/dev users never hit a 502 portal. Website robots.ts disallows `/billing/`. Note R2: Stripe-hosted portal/receipts still show "Facti AI" account branding, and grandfathered subscribers see their original (archived) product name inside Stripe's portal — both are Stripe Dashboard data, not repo code (see Remaining issues). |
| 8 | Navigation contains no obsolete links | **PASS** | Website `Header.tsx`/`Footer.tsx`: zero Reading references. `sitemap.ts`: 9 routes, none Reading-specific. Desktop `app_router.dart`: zero Reading matches; sidebar nav routes are library/player/projects/voices/settings; one shell for everyone (`isWritingShell = true`). |
| 9 | Help pages are consistent | **PASS** | Website support FAQ: "Writing Nook includes 250,000 premium voice characters…". Desktop guide chat (en/pt/es/fr): three tiers — Free, Writing Nook (with 14-day trial), Creative Nook (coming soon). Settings voice gate: "Available with Writing Nook Pro" ×4 languages. |
| 10 | Marketing copy reflects the new offer | **PASS** | Home hero is Writing-Nook-forward; JSON-LD offers are Psitta Free / Writing monthly (trial-prefixed) / Writing annual / Creative (coming soon). Product page presents reading features as "Read & Listen" capability, not a product. |

### The four consistency checks (pre-Phase-2 request)

| Check | Result | Detail |
|---|---|---|
| Creative Nook CTA behavior | **PASS** | Both surfaces waitlist-only (checklist item 2). No purchase button, no Stripe call, no entitlement anywhere in the Creative path. |
| Metadata | **PASS after fix F1** | `/pricing` meta description still advertised "Reading ($14.99/mo)" — fixed. Home, product, support, billing, download, signup, about, privacy, terms metadata: clean. |
| Search / indexing | **PASS (with note R1)** | `sitemap.ts` has no Reading URLs; `robots.ts` disallows `/billing/` and `/signup/`; JSON-LD Reading offers removed (Phase 1). Note R1: the static export `apps/website/out/` on disk is stale and still contains pre-Phase-1 Reading HTML — it regenerates on the next `npm run build`; do not deploy `out/` before rebuilding. |
| Visible illustrations | **PASS** | Inspected `reading-nook-illustration_blended.png` visually: generic open book + Psitta parrot, no "Reading Nook" text baked into the image. All illustration files referenced by the product page exist on disk, including `creative-nook-illustration_blended.png`. Only the *filename* says "reading-nook" (URL path, not rendered copy) — Phase B rename item. |

## 2. Fixes made (1)

**F1 — `apps/website/app/pricing/page.tsx` (meta description).**
Before: "Start free, then choose your Nook: Reading ($14.99/mo), Writing ($17.99/mo), or Creative ($29.99/mo — coming soon)…"
After: "Start free, then upgrade to Writing Nook — 14-day free trial, $17.99/mo or $183/yr (~15% off yearly). Creative Nook coming soon."
Committed to the working tree with an mtime guard and md5-verified byte-identical. This was the only customer-visible miss found in Phase 2; a follow-up source sweep of `apps/website/app` + `components` now returns zero Reading-commercial matches.

## 3. Remaining issues (none blocking; all tracked)

- **R1 — Stale static export:** `apps/website/out/` still contains pre-consolidation HTML (old pricing/product/support with Reading Nook). Regenerated automatically by `npm run build`; must be rebuilt before any website deploy.
- **R2 — Stripe-hosted surfaces (production, out of repo scope):** portal/receipt branding still "Facti AI" (tracked since A4), and grandfathered subscribers will see their original product name inside Stripe's Customer Portal because that text comes from the archived Stripe product record. Renaming archived products is a production Stripe mutation — not performed under the standing boundary; needs your explicit approval if you want it.
- **R3 — Phase B naming:** asset filenames `reading-nook-illustration*.png` (kept; images themselves are brand-neutral).
- **R4 — Dead l10n keys:** `featHdrEverythingReading`, `planChooseReading`, `planTaglineReadRefine` are unreferenced (safe); removable in a later cleanup with a `flutter gen-l10n` run.
- **Operator validation still to run on your machine** (sandbox has no Flutter/Node toolchain for this repo): `flutter analyze` (711-parity), `flutter test` (failure-set diff vs 44-entry baseline), `npm run build` (clean build + fresh `out/`).

---

**STOP.** Phase 2 complete. Not continuing further; awaiting your instructions. Standing boundaries remain in force (no production Stripe mutation, no production DB access, no MSIX publication, maintenance page active).
