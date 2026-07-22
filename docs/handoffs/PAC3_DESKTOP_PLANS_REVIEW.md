# PAC-3 — Desktop Plans Platform Alignment
## Phase 1 Review + Phase 2 UX Proposal (NO CODE — awaiting approval)

**Date:** 2026-07-21 · **File under review:** `apps/desktop/lib/features/auth/plan_selection_screen.dart` (as of `a7248ec`, unchanged since PAC-2A commit `c4321e7`) · **Status:** review and proposal only; zero code modified.

---

## 1. Current architecture (as implemented)

**Screen:** `/plan` route → `PlanSelectionScreen` (ConsumerStatefulWidget). Header "Plans" + back-to-Settings; subtitle `planSubtitle` ("Choose how you finish your book."); loading/error affordances driven by `billingStatusProvider` (error → retry banner; loading → spinner, no card marked current).

**Three cards in a Row (maxWidth 1020), each a `_PlanCard`:**

| Card | tierName | title (l10n) | Price | Features | Button logic |
|---|---|---|---|---|---|
| `_freeCard` | **"Free"** | `planTaglineRead` = **"Read"** | $0, no subtitle | 3 included (Listen, Basic voices, 10 docs) + 4 **excluded** rows (Premium voices, Word-by-word, Desk & Blueprints, Story-Coach & AI) | `Current Plan` if rank 0 else `Get Started`; onPressed **null** (never actionable) |
| `_writingCard` | "Writing Nook" | `planTaglineWrite` ("Write. Structure. Finish.") | $17.99/mo · $183/yr; subtitle `planTrial14` ("14-day free trial") both periods; Save 15% badge annual | 4 group headers (`featHdrWorkspace` "Workspace" / `featHdrBookDev` "Book development" / `featHdrAiIntel` "AI intelligence" / `featHdrListening` "Listening & revision") + 14 rows | rank-gated: `Current Plan` / `Included` / `Upgrade — finish your book` → `_startCheckout('writing_nook_pro')` |
| `_creativeCard` | "Creative Nook" | `planTaglineCreate` | $29.99/mo · $305/yr; "Launching soon" | "Everything in Writing, plus" header + 7 coming rows | `Notify me when it launches` → `_joinWaitlist` (POST `/waitlist/creativity-nook`); comingSoon badge |

**State/entitlement mapping:** `currentRank` = `_rank[plan]` from `/billing/status` **plan field only** (`free:0, reading_nook_pro:1 (compat), writing_nook_pro:2, creative_nook_pro:3`); −1 while loading/error. The `status` field (active/trialing) is read ONLY by the post-checkout poller (A4 contract) — **never for display**. `PlanStatus.currentPeriodEnd` (trial end for trialing subscribers) exists in the parsed billing payload and is **unused on this screen**.

**Stripe integration points:** `POST /billing/checkout-session` with `lookup_key = writing_nook_pro_{monthly|annual}` → external browser → 3s×N status polling → success snackbar. Error mapping for 400/409/502/network. Customer Portal is NOT on this screen (Settings-only tile, `isStripeSubscribed`-gated). Billing-period toggle mirrors the website (Monthly/Annual + Save 15%).

**Capability gating:** none — the screen renders from billing plan rank, not from `/users/me/capabilities`. (It is a billing surface, so this was correct under PAC-2B's keep-list; PAC-3 changes what it *displays*, not what enforces entitlement.)

**Icons/visuals:** `_PlanCard` with check rows, dimmed/dash excluded rows, "Most Popular" and "Coming Soon" badges, primary/secondary CTA hierarchy — visually the sibling of the website's `PricingTiers` (which was WA-4-aligned; the desktop was not).

## 2. Problems discovered — every artifact of the retired architecture

1. **P1 — "Free / Read" card:** tierName "Free", title literally "Read" (`planTaglineRead`) — reading presented as the free product's identity. The direct desktop twin of the WA-4 problem, now the last "Read-as-product" surface in the company.
2. **P2 — three-products presentation:** three peer cards imply three products; the platform story is ONE product (Writing Nook) in states, plus Creative Nook coming.
3. **P3 — restriction-first Explore story:** the free card leads with limits and dimmed exclusions instead of outcomes-then-locked-capabilities-then-limits.
4. **P4 — no Trial state presentation:** a trialing subscriber sees only "Current Plan" — no "Trial active", days remaining, or expiration, despite `status == 'trialing'` and `current_period_end` being present in the payload. The website FAQ now promises trial transparency; the app shows none.
5. **P5 — stale group vocabulary:** card headers ("Workspace", "Book development", "AI intelligence", "Listening & revision") predate the six approved WA-1 group names.
6. **P6 — no Manage-Subscription affordance for Subscriber/Trial on the Plans screen:** a subscriber landing on /plan gets a dead "Current Plan" button; portal access requires knowing it lives in Settings.
7. **P7 — `featHdrEverythingReading` and `planChooseReading`/`planTaglineReadRefine`** dead l10n keys still present (known PAC-6 cleanup; not rendered).
8. **P8 — `_rank` legacy map:** internal-only compat, correctly documented; no user-visible impact (keep).

## 3. Screenshots

Not producible from this environment (the Flutter app cannot run in the sandbox, and the device bridge has no display access). In their place, §4 provides exact before/after card diagrams reconstructed from the widget code, which is deterministic for this screen. If screenshots are wanted for the record: run the app, open Settings → Plans, and capture the three states (free account, trialing account, subscriber) — a 2-minute operator task I can annotate afterwards.

## 4. Before / After diagrams

**BEFORE (current):**
```
┌──────────────┐  ┌────────────────────┐  ┌──────────────┐
│ FREE         │  │ WRITING NOOK  ★    │  │ CREATIVE NOOK│
│ Read         │  │ Write. Structure.  │  │ Create. …    │
│ $0           │  │ $17.99/mo          │  │ $29.99/mo    │
│ ✓ Listen     │  │ 14-day free trial  │  │ Launching soon│
│ ✓ Basic voices│ │ [4 old-name groups │  │ [coming rows]│
│ ✓ 10 docs    │  │  + 14 rows]        │  │              │
│ ─ Premium ✗  │  │                    │  │              │
│ ─ Word-by-…✗ │  │                    │  │              │
│ ─ Desk & …✗  │  │                    │  │              │
│ [Get Started]│  │ [Upgrade — finish] │  │ [Notify me]  │
└──────────────┘  └────────────────────┘  └──────────────┘
   product #1          product #2            product #3
```

**AFTER (proposed — same 3-column layout, same `_PlanCard` widget):**
```
┌──────────────────┐  ┌──────────────────────┐  ┌──────────────┐
│ WRITING NOOK     │  │ WRITING NOOK    ★    │  │ CREATIVE NOOK│
│ Explore          │  │ Write. Structure.    │  │ Create. …    │
│ $0 · Free forever│  │ Finish.              │  │ $29.99/mo    │
│ ✓ Create writing │  │ $17.99/mo            │  │ Launching soon│
│   projects       │  │ 14-day free trial    │  │ [unchanged]  │
│ ✓ Organize your  │  │ ── Writing Workspace │  │              │
│   manuscript     │  │ ── Story Development │  │              │
│ ✓ Listen to your │  │ ── AI Writing        │  │              │
│   writing        │  │    Intelligence      │  │              │
│ Waiting for you  │  │ ── Reading & Revision│  │              │
│ 🔒 Blueprints    │  │ ── Project           │  │              │
│ 🔒 Story-Coach   │  │    Organization      │  │              │
│ 🔒 Structure     │  │ ── Native Desktop    │  │              │
│    Analyzer      │  │ (mirror of every     │  │              │
│ 🔒 AI Writing    │  │  Explore lock,       │  │              │
│ 🔒 Premium Voices│  │  unlocked)           │  │              │
│ 🔒 Word & Sent.  │  │                      │  │              │
│    Highlighting  │  │ [Start your 14-day   │  │ [Notify me / │
│ Technical limits │  │  free trial] or      │  │  On waitlist]│
│ • 10 documents   │  │  state banner (§5)   │  │              │
│ • Standard voices│  │                      │  │              │
│ [You're in       │  └──────────────────────┘  └──────────────┘
│  Explore]        │
└──────────────────┘
  ONE product, two cards = two views of it     next capability area
```

## 5. Desktop state flow — Explore → Trial → Subscriber → Creative Nook

Driven by `/billing/status` `plan` + `status` (+ `current_period_end`), all already in the payload:

| State (derivation) | Explore card | Writing card | CTA |
|---|---|---|---|
| **Explore** (`plan == free`) | Marked "Your current experience" | Locks shown as unlocked-in-full list | **Start your 14-day free trial** → existing `_startCheckout` |
| **Trial** (`plan != free && status == 'trialing'`) | De-emphasized (not current) | **"Trial active · N days remaining · ends {date}"** banner (N from `current_period_end`); everything shown unlocked; "Current Plan" | **Manage subscription** (opens the existing Stripe portal flow — same `isStripeSubscribed` gate as Settings) |
| **Subscriber** (`plan != free && status == 'active'`) | De-emphasized | Same card, no trial banner; "Current Plan" | **Manage subscription** (same) |
| **Creative Nook** (future) | — | — | Card unchanged today: Coming Soon + waitlist; when it ships it becomes another capability area with the same state model — no new screen, no new shell |
| Loading / error | Current behavior preserved: no card marked current; retry banner | fail-safe unchanged | — |

Same card in every state — the Writing card never duplicates; only its status banner and button change. The progression is emotional ("you're already inside; here's what unlocks"), never architectural vocabulary — "Explore" appears only as the card title, exactly as on the website.

## 6. Files that will require modification (implementation phase, upon approval)

- `apps/desktop/lib/features/auth/plan_selection_screen.dart` — card restructure, state banner, trial-days computation from `current_period_end`, Manage-subscription CTA for entitled states (reusing the Settings portal-session call), lock rows on Explore card.
- **l10n (the heavy part):** 4 `.arb` files + `app_localizations.dart` + 4 generated concrete classes — new keys (~12: Explore title/current-state label, "Waiting for you", "Technical limits", locked capability labels where not reusable, "Trial active", "{n} days remaining", "Ends {date}", "Manage subscription", six group headers aligned to WA vocabulary — `featHdrListening` → Reading & Revision etc., reusing existing keys where the string already matches). All hand-mirrored into generated files (no `flutter gen-l10n` in the sandbox) ×4 languages.
- Possibly `test/` — a widget/unit test pinning the state derivation (Explore/Trial/Subscriber from plan+status) would be cheap and valuable.
- **NOT modified:** backend, Stripe endpoints/lookup keys, `billing.py`, capabilities, router/navigation, shells, Settings portal tile, `_rank` compat map, checkout/polling/waitlist logic, Creative card.

## 7. Implementation risk assessment

- **LOW — business logic:** checkout, polling, waitlist, and error paths are untouched; changes are presentation + one new portal-session call reused from Settings' existing implementation.
- **MEDIUM — l10n mechanics:** ~12 new keys ×4 languages hand-edited into checked-in generated files; mechanical but the established error class of this project. Mitigation: JSON validation + operator compile gate (the same routine as Phase 1/PAC-2B, which shipped clean).
- **LOW/MEDIUM — trial-days correctness:** `current_period_end` for a trialing sub IS the trial end (A4); days-remaining must round sanely (ceil, floor at 0) and tolerate null (hide banner). A unit test pins it.
- **LOW — visual regression:** same `_PlanCard`, same Row/toggle; content-only. The 44-failure test baseline includes theme-build widget tests for other screens — flutter analyze 708-parity and full-suite baseline gates apply as always.
- **Rollback:** single-surface commit(s), git-revertible; no data or backend coupling.

## 8. Impact on Backend / Stripe / Capabilities / Navigation

- **Backend: none.** All data needed (plan, status, current_period_end) already ships in `/billing/status` (A4). No new endpoints.
- **Stripe: none.** Same checkout lookup keys, same portal-session endpoint (one more call site, Settings-identical gating). No catalog, webhook, or trial changes.
- **Capabilities: none required.** This remains a billing surface on the PAC-2B keep-list. (Optional consistency note for the implementation discussion: the Explore card's lock list could render from the capability payload instead of hardcoded copy, but marketing copy ≠ entitlement enforcement — recommend hardcoded l10n copy mirroring the website, exactly as PricingTiers does.)
- **Desktop navigation: none.** Same `/plan` route, same back-to-Settings, no shell or nav changes.

---
**STOP — Phase 3.** No code written. Awaiting approval of the Phase 2 UX proposal before implementation. This is the final Platform Architecture alignment before RC-1.
