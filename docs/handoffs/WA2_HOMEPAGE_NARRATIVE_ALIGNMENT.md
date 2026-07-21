# WA-2 — Homepage Narrative Alignment

**Date:** 2026-07-21 · **Scope:** homepage narrative only · **Status:** Sections 2–3 implemented in the working tree (NOT committed to git, NOT deployed); Section 1 is a recommendation awaiting your decision.

## 1. Homepage narrative review

The homepage is composed of five blocks: Hero (page.tsx) → "Writing Nook highlights" (page.tsx) → **FeatureStrip** ("What Psitta does") → **WhyListening** ("Your ear catches what your eye misses") → MakerNote.

The two blocks that still told the old story were exactly the ones you named. **FeatureStrip** was the pre-consolidation elevator pitch — "Three capabilities that turn reading into revision," selling hearing your writing, sentence highlighting, and premium voices, i.e. voices/highlighting/PDF as the product. **WhyListening** made the right argument with a reading-centric frame ("Reading silently…") and stopped at "the fix follows" — it never connected listening to *finishing a book*. The Hero and the "Writing Nook highlights" section were already largely aligned (Phase 1 work); MakerNote is founder voice and origin story — capability-neutral and credible as-is.

**One editorial clash surfaced by this change (recommendation R2 below):** the page.tsx highlights section is titled "Everything you need to finish the book," which now nearly duplicates the mandated new FeatureStrip heading "Everything you need to finish your book" on the same page. Flagged for your decision; not changed (page.tsx is outside the two mandated sections).

## 2. Proposed copy

### Section 1 — Hero (RECOMMENDATION ONLY, not implemented)

Current: eyebrow "The Writing Nook" · h1 "Hear your words. / Finish your book." · support "Meet Maya — she'll let you know more about how Psitta helps you structure, draft, and finish your book." · CTA "Start writing with Psitta".

**Assessment: keep the headline.** "Hear your words. / Finish your book." already ends on the transformation, leads with the differentiator, and is the brand hook — replacing it would trade recognition for marginal gain. The weak element is the support line, which introduces Maya before it makes the promise.

**R1 — proposed support line (one sentence changed, nothing else):**
> "Psitta is the writing platform for people finishing books — structure it, draft it, and hear every line read back until it's done. Meet Maya for the two-minute tour."

**R2 — duplicate-heading fix (page.tsx highlights section):** retitle its h2 from "Everything you need to finish the book" to **"Inside the Writing Nook"** (its eyebrow is already "Writing Nook"), letting that section be the product overview and the new FeatureStrip be the platform promise. One line; awaiting approval.

### Section 2 — FeatureStrip (IMPLEMENTED)

h2: **"Everything you need to finish your book"** · subtitle: **"One writing platform. Every stage of your manuscript."** — six capability-group cards (same card component, same grid; 3 columns × 2 rows):

- **Writing** — "A distraction-free Writing Desk built for daily writing. Sit down, pick up exactly where you left off, and put words on the page — every session moves the manuscript forward."
- **Story Development** — "Plan the book before it drifts. Blueprints and proven narrative structures turn your idea into a map — plan scenes, track progress, and always know what to write next."
- **AI Writing Intelligence** — "A Story-Coach that catches drift as you write, a Structure Analyzer that shows what's working, AI assistance when you're stuck, and analytics that prove your momentum — honest feedback, exactly when it helps."
- **Reading & Revision** — "Hear every line read back in a natural voice with synchronized highlighting. Listening turns rereading into revision — you fix what you hear, and the draft gets better with every pass."
- **Project Organization** — "Every draft, chapter, and source organized in projects and one searchable library. Your whole manuscript lives in one place — never scattered across folders again."
- **Native Desktop** — "A native Windows app that keeps up with you — fast, keyboard-driven, and offline-friendly, so nothing stands between you and the next page."

### Section 3 — WhyListening (IMPLEMENTED; heading kept verbatim)

> **Your ear catches what your eye misses**
> Professional writers don't catch a manuscript's flaws by rereading it — they catch them by hearing it. Read silently and your brain auto-corrects: it fills in missing words, smooths clumsy transitions, and skips right past the sentence you rewrote three times. Hear your chapter read back and every stumble announces itself — and the fix usually follows within seconds. Psitta builds that into your writing routine: listen, fix, move on. Revision stops being the wall between you and a finished book, and becomes the fastest part of your day.

## 3. Files modified

- `apps/website/components/home/FeatureStrip.tsx` (Section 2 — heading, subtitle, 3 cards → 6 capability groups)
- `apps/website/components/home/WhyListening.tsx` (Section 3 — body rewrite, heading unchanged)

No other file touched. Hero (page.tsx) untouched pending R1/R2 decisions.

## 4. Reasoning behind every wording change

- **"What Psitta does" → "Everything you need to finish your book":** mandated; shifts the frame from describing features to promising the outcome. Sub "One writing platform. Every stage of your manuscript." plants the single-platform architecture in nine words.
- **Three cards → six groups:** the old trio WAS the retired product (reading capabilities as the pitch). The six groups mirror the Product page's capability architecture, so homepage → product page now tells one continuous story.
- **Every card ends on an outcome, not a mechanism:** "every session moves the manuscript forward," "always know what to write next," "honest feedback, exactly when it helps," "the draft gets better with every pass," "never scattered again," "nothing stands between you and the next page." Technology words (PDFium, ElevenLabs, Azure, PDF/DOCX, pixel-accurate) were deliberately removed from the homepage — they survive on the Product page where evaluation happens.
- **"Plan the book before it drifts":** gives Story Development a stake (drift = the reason manuscripts die), which the AI card then pays off ("catches drift as you write").
- **WhyListening, "Professional writers don't catch…":** reframes the opener from an observation about reading to an identity claim about writers — the reader is invited into the professional's method. Kept the strongest original imagery ("brain auto-corrects," "the sentence you rewrote three times," "the fix follows within seconds") because it's earned and vivid; deleted nothing that worked.
- **New closing, "Revision stops being the wall… fastest part of your day":** the transformation sentence — it names the enemy (revision as the wall between writer and finished book) and sells the after-state. This is the "sell transformation, not audio" requirement in one line.

## 5. Intentionally left unchanged

Layout, spacing, grid, card markup, icon system and classes; branding; illustrations and the Maya video; animations; navigation and footer; pricing page; Product page (WA-1 output); Creative Nook everywhere; MakerNote (founder voice, already outcome-framed); the Hero headline, eyebrow, CTAs, and "Free tier available" line (public "Free" per founder decision); page metadata and JSON-LD.

---
**STOP.** Awaiting your approval on: (a) the implemented Sections 2–3, (b) recommendation R1 (hero support line), (c) recommendation R2 (duplicate-heading retitle). No build, commit, or deployment performed.
