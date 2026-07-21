# WA-1 — Product Page Platform Alignment Report

**Date:** 2026-07-21 · **Scope:** website-only, one page (`apps/website/app/product/page.tsx`) · **PAC:** paused, untouched.

## Change summary

The Product page now communicates the Psitta Platform architecture instead of the retired three-product ladder.

**Before:** `Read & Listen (peer section) → Writing Nook → Creative Nook` — reading presented as a product.
**After:** `Writing Nook → [Writing Workspace · Story Development · AI Writing Intelligence · Reading & Revision · Native Desktop] → Creative Nook (Coming Soon)` — two Nooks; everything else is a capability inside Writing Nook.

Detail: Writing Nook is the first and primary section ("Everything you need to plan, write, revise and finish your book — one application, one workspace, with a 14-day free trial", "Most popular" badge kept). Five capability groups per the approved structure: Writing Workspace (Writing Desk, new Document Library card, new Unlimited Projects card); Story Development (Blueprints and 25+ Narrative Structures split into individual capabilities; Scene Mapping and Progress Tracking likewise); AI Writing Intelligence (Story-Coach, Structure Analyzer, Writing Analytics, new AI-assistance card covering Summarize It); Reading & Revision (the entire former Read & Listen content absorbed — read aloud, PDF/DOCX/HTML/TXT/MD/EPUB support, premium voices, sentence + word highlighting, "listening improves writing" — illustration retained, copy reframed: "listening is how Psitta turns reading into revision"; "upgrade to Pro" → "included with Writing Nook"); Native Desktop (native Windows app plus new Local Performance, Keyboard Shortcuts, Offline-friendly Workflow cards). Creative Nook remains Section 2, Coming Soon, full existing capability set, waitlist only, no pricing/checkout, with "same application, same architecture, new capabilities" added.

**Intentionally unchanged:** all styling/layout/branding (same components, classes, grids, FeatureCard, badges, all three illustrations); hero + lead; metadata; JSON-LD offers; Creative capability set and waitlist form; download CTA with "Free tier available" (public copy keeps "Free" per founder decision); `reading-nook-illustration` asset filename (Phase B).

## Files modified

- `apps/website/app/product/page.tsx` (+275/−110)
- `docs/handoffs/WA1_PRODUCT_PAGE_ALIGNMENT_REPORT.md` (this report)

## Validation evidence

**Build (operator):** `npm run build` — 17/17 static pages, zero errors, `/product` exported.

**Generated-export verification (all PASS, checked against `out/product/index.html`):**
1. Heading sequence renders exactly: Writing Nook → Writing Workspace → Story Development → AI Writing Intelligence → Reading & Revision → Native Desktop → Creative Nook.
2. Rendered "Read & Listen": **0 occurrences**.
3. "Reading Nook" commercial language: **0 occurrences** (case-insensitive).
4. Creative Nook: "Coming soon" ×6, waitlist CTA present, no checkout/pricing markup.
5. Images: all four referenced `/brand/*` assets exist in the export; internal links (`/`, /about/, /contact/, /download/, /pricing/, /privacy/, /product/, /support/, /terms/) all resolve to exported pages.
6. JSON-LD: parses as valid `SoftwareApplication` with exactly the five approved offers (Psitta Free, Writing ×2, Creative ×2 coming soon).
7. HTML well-formedness: h2 2/2, h3 5/5, h4 29/29 open/close balanced; div balance 0.

## Deployment protocol

One isolated commit (`refactor(website): align product page with Psitta platform`, exactly the two files above) pushed to `develop`. Push triggers CI, Release (backend redeploy — no backend changes in range, benign), and the Website deploy (fresh CI build, `s3 sync --delete`, CloudFront invalidation `/*`, 3–5 min propagation). Public verification after propagation: https://psitta.ai/product/ on desktop and mobile viewports — Writing Nook hierarchy, Reading & Revision placement, Creative Coming Soon state, absence of the old Reading → Writing → Creative ladder. Final outcomes (commit hash, workflow results, public verification) recorded in the WA-1 final summary delivered at sign-off.

---
Boundaries held: WA-2 not begun; PAC paused; no MSIX build; no other website page touched.
