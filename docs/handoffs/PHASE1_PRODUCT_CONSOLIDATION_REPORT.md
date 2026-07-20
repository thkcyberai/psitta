# PHASE 1 — Product Consolidation Report

**Date:** 2026-07-20 · **Repo:** thkcyberai/psitta (working tree `C:\products\psitta`, branch `develop`)
**Scope:** Complete repository sweep for Reading Nook / Reading Plan / Reading Pro. Writing Nook is the only purchasable product (14-day free trial, $17.99/mo, $183/yr). Creative Nook is Coming Soon (waitlist only). Reading Nook removed from every customer-visible surface; internal compatibility preserved.
**Status:** COMPLETE. All edits written to the working tree and verified byte-identical (md5). Nothing committed to git; nothing pushed; no backend, Stripe, or infrastructure changes. Phase 2 NOT started.

---

## 1. Files changed (20)

Backups of the two most heavily rewritten files exist on disk as `*.bak_20260720_p1` (git-ignored).

### Website (4)
| File | Change |
|---|---|
| `apps/website/components/pricing/PricingTiers.tsx` | READING tier deleted; grid is now Free / Writing / Creative (`lg:grid-cols-3`). Writing tier features flattened (no "Everything in Reading Nook" ladder; Listening & revision section folded in). Subtitles: "14-day free trial, then billed monthly" / "14-day free trial · $15.25/mo billed annually". CTA: "Start your 14-day free trial". Footer: "Start your 14-day Writing Nook free trial from inside the app — cancel anytime." |
| `apps/website/app/page.tsx` | SoftwareApplication JSON-LD: 3 Reading offers removed; Free offer renamed "Psitta Free" ("standard voices"); Writing monthly description prefixed "14-day free trial." |
| `apps/website/app/product/page.tsx` | "Reading Nook" section renamed "Read & Listen" with copy "Listening is free — premium voices and word-level highlighting come with Writing Nook."; illustration alt text updated; Writing section intro now leads with the 14-day free trial. |
| `apps/website/app/support/page.tsx` | FAQ answer now: "Writing Nook includes 250,000 premium voice characters per billing period…" |

### Desktop — screens & gates (7)
| File | Change |
|---|---|
| `features/auth/plan_selection_screen.dart` | Reading card deleted; 3-card row (Free / Writing / Creative, maxWidth 1020). Writing card subtitle shows `planTrial14` ("14-day free trial") on both billing periods; features flattened to include the listening section. Post-checkout polling accepts `status == 'active' || 'trialing'` for `writing_nook_pro`/`creative_nook_pro`. Doc comment updated to three tiers. `_rank` map kept with compat comment. |
| `features/shell/desktop_shell.dart` | One shell for everyone: `const isWritingShell = true;` (legacy Reading shell unreachable, quarantined for later removal). Unused `plan_gate.dart` import removed. |
| `features/shell/widgets/sidebar_nav.dart` | Legacy shell brand header `'The Reading Nook'` → `'Psitta'` (defensive rename; widget unreachable after one-shell consolidation). |
| `core/plan_gate.dart` | Both upgrade-prompt defaults `requiredPlan = 'Reading Nook Pro'` → `'Writing Nook Pro'`; upload-limit dialog now says "Upgrade to Writing Nook Pro for 50 documents per month." |
| `core/quota_gate.dart` | Plan display map: `pro_monthly`, `pro_annual`, `reading_nook_pro` now all display "Writing Nook Pro" (keys preserved for grandfathered subscriptions); `writing_nook_pro` entry added. |
| `features/settings/settings_screen.dart` | Same pattern: `reading_nook_pro` displays "Writing Nook Pro" (key preserved). |
| `features/guide/guide_chat_script.dart` | Plans node in all 4 languages (en/pt/es/fr): Reading Nook bullet removed; three tiers — Free (standard voices), Writing Nook (full platform + premium voices + highlighting + 50 docs + 1M tokens, "starts with a 14-day free trial"), Creative Nook (coming soon). |

### Desktop — localization (9)
| File | Change |
|---|---|
| `l10n/app_en.arb`, `app_es.arb`, `app_fr.arb`, `app_pt.arb` | New key `planTrial14` ("14-day free trial" / "Prueba gratis de 14 días" / "Essai gratuit de 14 jours" / "Teste grátis de 14 dias"). `setSwhProGate` updated to "Available with Writing Nook Pro" (×4 languages). JSON validity of all 4 files verified. |
| `l10n/app_localizations.dart` | Abstract getter `planTrial14` added; `setSwhProGate` doc comment updated. (Generated files are checked in and hand-edited because `flutter gen-l10n` is unavailable in the sandbox.) |
| `l10n/app_localizations_{en,es,fr,pt}.dart` | Concrete `planTrial14` getters added; `setSwhProGate` values updated — matches the .arb sources exactly. |

---

## 2. Customer-visible changes (summary)

- **Pricing page (web):** 3 tiers instead of 4 — Free, Writing Nook (Most Popular, trial-forward copy), Creative Nook (Coming Soon). No Reading Nook tier, price, or feature ladder anywhere.
- **SEO/structured data:** Reading offers removed from JSON-LD, so search engines stop indexing Reading Nook prices.
- **Product page (web):** the reading feature set is presented as "Read & Listen" — a capability of Psitta (free listening; premium voices with Writing Nook), not a product.
- **Support/FAQ (web):** voice-allowance answer references Writing Nook.
- **In-app plan selection:** 3 cards; Writing Nook shows "14-day free trial" on both monthly and annual; checkout entitlement recognized immediately during Stripe trials (`trialing` accepted).
- **In-app upgrade prompts/dialogs/snackbars:** all name Writing Nook Pro.
- **In-app Settings & quota dialogs:** grandfathered legacy subscribers (`pro_monthly`, `pro_annual`, `reading_nook_pro`) see their plan displayed as "Writing Nook Pro".
- **Guide chat (4 languages):** plans explanation lists the three current tiers with the trial.
- **Settings voice gate (4 languages):** "Available with Writing Nook Pro".
- **Everyone gets the Writing shell** — the legacy Reading shell UI is unreachable.

## 3. Intentionally preserved (compatibility / internal — per your instruction)

- **Backend grandfathering untouched:** `plan_limits.py` aliases (`pro_monthly`/`pro_annual`/`reading_nook_pro` → `writing_nook_pro`), billing handlers, subscription service, DB migrations 017/019/023, tester allowlist — all keep `reading_nook_pro` internals. Historical subscriptions unaffected.
- **Client compat keys:** plan-id map keys `pro_monthly`, `pro_annual`, `reading_nook_pro` retained (display-only change); `_rank` map in plan selection retained.
- **Internal comments** mentioning Reading Nook in `providers.dart`, `audio_service.dart`, `player_bar.dart`, `desk_center_pane.dart`, `writing_desk_screen.dart`, `writing_library_screen.dart`, `app_shell.dart`, `plan_gate.dart` — historical context, never rendered.
- **Dead l10n key `featHdrEverythingReading`** ("Everything in Reading Nook, plus" ×4 languages): verified unreferenced by any widget after the Reading card removal; left in place rather than deleted (removing keys from checked-in generated files is riskier than leaving a dead getter). Also unused after this phase: `planChooseReading`, `planTaglineReadRefine` (never rendered).
- **Asset filename** `/brand/reading-nook-illustration_blended.png` kept (alt text updated) — renaming the binary asset is the agreed Phase B item.
- **Internal engineering docs** (`docs/architecture/reading_nook_architecture_review.md`, handoffs, product-strategy v1, runbooks): historical records, not customer-facing — unmodified.
- **Not mine / pre-existing local modifications** in your working tree, untouched: `api_client.dart`, `auth_service.dart`, `NewsletterForm.tsx`, plus untracked assets and `apps/website/out/` (stale static export — regenerates on next `next build`).

## 4. Verification performed

1. **Sweep inventory:** repo-wide grep (device) for `reading nook`, `reading_nook`, `Reading Plan`, `Reading Pro`, `ReadingNook`, `reading-nook` across `apps/`, `core/backend/src/`, `docs/` — every match categorized as fixed, compat-preserved, internal comment, historical doc, or stale build output. **Zero customer-visible occurrences remain in source.**
2. **l10n integrity:** all 4 .arb files parse as valid JSON; `planTrial14` defined in abstract class + all 4 concrete classes and referenced only from `plan_selection_screen.dart`; no other missing-key references introduced (all reused feature keys confirmed present, including `billedAnnuallyAt`).
3. **Write-back integrity:** all 20 files committed to `C:\products\psitta` via the device bridge and md5-verified byte-identical to the edited copies.
4. **Website:** `apps/website` source greps clean for all Reading terms (only the Phase B asset path remains).

### Operator validation (run on your machine — sandbox has no Flutter/Node toolchain for this repo)
```bash
cd /c/products/psitta/apps/desktop && flutter analyze          # expect issue-count parity with baseline (711)
cd /c/products/psitta/apps/desktop && flutter test             # compare failure SET against the 44-entry baseline — no NEW failures
cd /c/products/psitta/apps/website && npm run build            # expect clean build; regenerates out/ without Reading pages
```

---

**STOP.** Phase 1 ends here per instruction. Phase 2 not started; Checkout Matrix remains suspended pending your re-sequencing. Standing boundaries still in force (no production Stripe mutation, no production DB access, no MSIX publication, maintenance page active).
