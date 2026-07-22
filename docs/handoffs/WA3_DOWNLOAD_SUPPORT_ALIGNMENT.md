# WA-3 — Download & Support Narrative Alignment

**Date:** 2026-07-21 · **Scope:** wording only, two pages · **Status:** implemented in the working tree — NOT committed to git, NOT deployed. Pricing page untouched (reserved for the final WA task).

## 1. Download page review

The page is structurally excellent and the hero — "Write it. Shape it. Hear it come to life." — is kept verbatim as instructed. The review found no old-product or Reading-product wording, but recurring **"studio" language** (five occurrences) predating the platform vocabulary, and a **subscription-first conversion block** whose CTA ("See plans and subscribe") and closing line ("the complete studio serious authors subscribe to…") sold the subscription before the platform. The value points were already outcome-framed and needed only two "studio" touch-ups. System requirements, install steps, and the newsletter block are narrative-neutral and untouched.

## 2. Support page review

FAQ-only review as instructed. Ten questions existed; eight are technical/operational and remain appropriate (install, web/mobile, document types, offline, plan change/cancel, SmartScreen, troubleshooting, hours, alpha feedback). One question reflected the retired feature-first frame — "What happens when I run out of premium voice characters?" — leading the commercial FAQ with a quota edge case. The support experience lacked any question explaining the platform itself, the trial, upgrades, or Creative Nook.

## 3. Summary of wording changes

**Download (7 changes):**
1. Metadata + hero lead: "the complete book-writing studio" → **"the writing platform for people finishing books"** (matches the homepage hero support line verbatim — one sentence, same story, every page).
2. Download-card eyebrow: "The complete writing studio for authors" → **"The professional writing platform for authors"**.
3. Trial microcopy: "the full Writing Nook **studio** free for 14 days" → "the full Writing Nook **experience** free for 14 days" (per your example; no-card and auto-update notes kept).
4. Value point "In your language…": "switches the entire studio… get the full studio" → "switches the entire **platform**… get the full **Writing Nook**".
5. Conversion heading: "Keep the **studio** that finishes your book." → "Keep the **platform** that finishes your book."
6. Conversion body: rewritten platform-first — "Your 14-day trial opens the complete Writing Nook — the Writing Desk, Blueprints, narrative frameworks, Summarize It, Story-Coach, and **Reading & Revision**, all working together on your book. One platform, every stage of your manuscript — so the book you're proud of actually gets finished." (Also renames "read-aloud" to the capability-group name.)
7. CTA: "See plans and subscribe" → **"See everything included in Writing Nook"** (your preferred option; href `/pricing` unchanged — understanding before subscription).

**Support (FAQ now 13 questions; 4 new, 1 retired-into-merged, 8 kept verbatim):**
- NEW **"What is included in Writing Nook?"** — the full platform inventory plus the allowance details; the old premium-voice-characters answer is folded here in full (switch to standard voices, never interrupts, resets each cycle), so no information was lost.
- NEW **"What happens after my Writing Nook trial ends?"** — replaces the quota question as the commercial entry point; covers conversion, cancel-before-charge, and the continue-writing-free path (documents stay, standard voices, premium locks) — also answering your "Can I continue writing after my trial?" in the same breath.
- NEW **"How do upgrades work?"** — in-app trial start from the Plans screen, Stripe checkout, switch/cancel via Manage Subscription.
- NEW **"What is Creative Nook?"** — coming soon, builds on Writing Nook, same application (the no-second-shell principle, publicly stated), waitlist on pricing.
- Metadata description updated to name Writing Nook/trials instead of "voices".
- FAQ order: platform questions sit between "Can I use Psitta offline?" and "How do I change my plan or cancel?", so the arc runs install → basics → platform/commercial → operational → troubleshooting.

## 4. Files modified

- `apps/website/app/download/page.tsx`
- `apps/website/app/support/page.tsx`

## 5. Reasoning behind each change

The "studio → platform" sweep makes every page use one noun for one concept — "platform" is what the homepage, product page, and architecture documents now say; two vocabularies would read as two products again. Repeating the exact homepage sentence ("the writing platform for people finishing books") in the download metadata/lead makes search snippets and the landing flow tell the identical story. The conversion CTA rewrite follows your stated goal directly: a visitor should want to *understand Writing Nook* before being asked to subscribe — the button now promises information, not a transaction, while pointing at the same pricing page. In the FAQ, leading the commercial section with a quota edge case framed Psitta as a metered voice service; leading with "what's included / what happens after the trial" frames it as a platform with a trial — and the quota mechanics remain fully documented one question up. The Creative Nook answer publicly commits to "same application, no separate app," aligning support copy with the architectural requirement that no Nook ever introduces another shell.

## 6. Intentionally left unchanged

Download hero (verbatim, per instruction), all six value-point titles and four bodies not quoted above, system requirements, install steps, newsletter block, and the "no card until you subscribe. Auto-updates as new versions ship." microcopy tail. Support: the eight technical/operational FAQs verbatim — including "How do I change my plan or cancel?" (already aligned), the SmartScreen answer (its "development certificate" honesty stands until the 1.2.0 signing decision), and the alpha-tester question (still a real audience). All layout, spacing, components, styling, navigation, footer, illustrations, animations. The Pricing page — untouched, reserved as the final Website Alignment task before the freeze.

---
**STOP.** No build, no commit, no deploy. Awaiting your approval.
