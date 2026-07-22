# WA-4 — Pricing Page Platform Alignment

**Date:** 2026-07-21 · **Scope:** pricing card content only · **Status:** implemented in the working tree — NOT committed, NOT deployed. Awaiting approval; the final WA task before the website freeze.

## 1. Pricing page narrative review

The page scaffold was already aligned (three cards, Monthly/Annual toggle, trial-forward Writing card, waitlist-only Creative card, and the page metadata fixed in Phase 2). The one surviving artifact of the retired architecture was **card 1: "FREE / Read"** — a card that named reading as its identity, led with a feature list of what listening offers, and then enumerated exclusions. It implicitly said *reading is the free product; Writing Nook is a different, paid product* — contradicting every other page. Card 2 sold correctly but as a flat feature enumeration whose group headers ("Writing workspace", "Book development", "Listening & revision") predated the Product-page vocabulary.

## 2. Before / After hierarchy

**Before:** `FREE — Read (features, then exclusions) · WRITING NOOK — Write. Structure. Finish. (17 flat rows, old group names) · CREATIVE NOOK — Coming Soon`

**After:**
- **WRITING NOOK — Explore** ($0, Free forever): three accomplishments first (Create writing projects · Organize your manuscript · Listen to your writing) → **"Waiting for you"** divider → six locked capabilities with a lock affordance (Blueprints · Story-Coach · Structure Analyzer · AI writing · Premium voices · Word & sentence highlighting) → **"Technical limits"** last (10 documents per month · Standard voices). CTA unchanged: "Download for free".
- **WRITING NOOK — Write. Structure. Finish.** (price/trial/CTA untouched): the same story unlocked, grouped under the six approved Product-page names — Writing Workspace · Story Development · AI Writing Intelligence · Reading & Revision · Project Organization · Native Desktop. Every capability locked on Explore appears unlocked in its group.
- **CREATIVE NOOK** — byte-identical. Coming Soon, waitlist, no pricing, no checkout.

The progression now reads Explore → Trial → Subscriber emotionally: *you're already inside Writing Nook; upgrading unlocks more of it.* No state or architecture terminology is taught — "Explore" is simply the card's name.

## 3. Files modified

- `apps/website/components/pricing/PricingTiers.tsx` (tier data + two technically necessary code touches, below)

## 4. Reasoning behind every wording change

- **"FREE / Read" → "WRITING NOOK / Explore":** the mandated change; the eyebrow (product) is now identical on cards 1 and 2 — one product, two states — with no Reading/Lite/Starter/Basic vocabulary introduced.
- **Accomplishments before locks, limits last:** the card now opens with what a writer can do today (projects, manuscript, listening) instead of restrictions; the locked list under a "Waiting for you" divider turns exclusions into anticipation; "Technical limits" demotes 10-docs/standard-voices to footnote facts. This is the visible-but-locked platform principle expressed in marketing.
- **Lock affordance (new `locked` feature state + 16px lock icon):** the spec's 🔒 requires a rendering the component didn't have. Implemented in the identical row markup and icon style family as the existing check/dash/clock states — a content-semantics addition, not a styling change.
- **Card 2 group headers renamed to the Product-page vocabulary** (e.g. "Book development" → "Story Development", "Listening & revision" → "Reading & Revision", plus the three groups that had no header before): pricing now mirrors WA-1's capability architecture word-for-word, so a visitor moving Product → Pricing sees the same map twice.
- **"Unlimited projects & documents" → "Unlimited projects" + "Document Library & manuscript organization":** accuracy-preserving adjustment — Writing Nook's document allowance is 50/month per the entitlement system; the old copy over-claimed. Projects are genuinely unlimited, and the Library line carries the organization story (matches the desktop plan card, which claims only unlimited projects).
- **Rows merged for mirror-symmetry** ("AI assistance — 1M AI tokens / month"; "Premium natural voices — 250k characters / month"): every Explore lock finds its unlocked counterpart by name; allowances ride along as detail instead of standing as separate technology rows.
- **React list key `tierName` → `title` (technically necessary):** two cards now legitimately share the "Writing Nook" tierName, so tierName is no longer a unique key; titles are. One token, commented in code.

## 5. Intentionally left unchanged

All prices, the 14-day trial, both CTAs and their destinations, the Monthly/Annual toggle and Save 15% badge, layout/spacing/grid/branding/styling/animations, the "Most popular" and "Coming soon" badges, the Creative Nook card in its entirety (features, waitlist form, no-checkout posture), the footer note ("Start your 14-day Writing Nook free trial from inside the app — cancel anytime"), navigation and footer, and the pricing page route file (`app/pricing/page.tsx` — its metadata was already platform-aligned in Phase 2).

---
**STOP.** Awaiting approval. On approval: build → export verification → isolated commit → push → CI/Release/Website Deploy → public verification → **WEBSITE FROZEN** declaration, then RC-1 Manual Smoke Matrix → MSIX 1.2.0 Release Candidate → Public Release.
