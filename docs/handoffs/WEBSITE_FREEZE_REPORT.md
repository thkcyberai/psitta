# Website Freeze Report — Version 2.0.0
## Status: PREPARED — freeze declared upon completion of the execution checklist below

**Date:** 2026-07-23 · **Scope:** the five public pages of psitta.ai, frozen for the Psitta 2.0.0 release. After the declaration: no copy, narrative, or structural changes — release-blocker fixes only.

## 1. Pages verified

| Page | Alignment | Verification state |
|---|---|---|
| Homepage | WA-2 (narrative, six capability groups, ear/eye rewrite, R1/R2) | **Deployed + publicly verified** (commit `180584e`; hero, narrative flow, group order, zero reading-product messaging, balanced HTML, links/images resolved) |
| Product | WA-1 (Writing Nook first, five capability groups, Reading & Revision absorbed) | **Deployed + publicly verified** (commit `bb6589b`; desktop + mobile confirmed during WA-1) |
| Pricing | WA-4 (WRITING NOOK / Explore card, mirrored unlocked card, Creative untouched) | **Export-verified** (fresh build: heading sequence, lock rows, zero Reading) — public verification after the freeze push |
| Download | WA-3 (platform wording, "See everything included in Writing Nook" CTA) | **Export-verified** — public verification after the freeze push |
| Support | WA-3 (13-question FAQ: Writing Nook, trial, upgrades, Creative Nook) | **Export-verified** — public verification after the freeze push |

Cross-page invariants already verified in the export: one consistent Writing Nook story, Creative Nook Coming-Soon/waitlist-only everywhere, metadata + JSON-LD valid (5 offers), sitemap 9 URLs / robots correct, all internal links and brand images resolve, HTML balanced on every checked page.

## 2. Workflow results — PENDING the freeze push
Expected on push: CI ✓ · Release ✓ (backend redeploy, no backend changes in range — benign, precedented) · Deploy Website to psitta.ai ✓ (fresh CI build, `s3 sync --delete`, CloudFront invalidation `/*`). To be recorded on completion.

## 3. Public verification — PENDING propagation
Protocol: all five pages, desktop + tablet + mobile viewports; hero and narrative; pricing card hierarchy (Explore card live); download CTA; support FAQ; no Reading-product messaging; navigation/links/images/metadata/JSON-LD; responsive layouts.

## 4. Outstanding release blockers
**None known for the website.** (Desktop-side RC-1 items are tracked separately and do not gate the freeze.)

## 5. Freeze declaration

Upon green workflows + clean public verification, the following takes effect and will be confirmed in this document:

> **WEBSITE FROZEN — Version 2.0.0.** The public website is final for the Psitta 2.0.0 release. No additional copy changes, no narrative changes, no restructuring. Only release-blocker fixes, each requiring explicit founder approval.
