# PAC-2B — Entitlement System Migration Report

**Dates:** 2026-07-21 · **Repo:** thkcyberai/psitta, branch `develop` · **Base:** `45f4043` (PAC-2A, CI + Release green)
**Status:** COMPLETE (this report ships inside commit 6). Stopped at the PAC-2B boundary — PAC-2C not begun.

## Objective and result

Remove the legacy permission system from the desktop client. Every production feature gate now renders from the server-resolved capability architecture (`core/capabilities.dart` ← `GET /users/me/capabilities` ← the same entitlement resolver the backend enforces with). No UI, copy, navigation, routing, shell, backend, Stripe, or website behavior changed — every migration was a behavior-preserving predicate swap, validated at analyzer and test-baseline parity at every step.

## Commits (Phase A + B + C)

| # | Commit | Content |
|---|---|---|
| 1 | `74ab846` `test(capabilities): lock the client capability contract` | 12-test safety net: vocabulary sync vs backend, payload parsing, fail-closed degradation, unavailable baseline. (Amended once: 23 test-only const lints fixed; analyzer restored to 708.) |
| 2 | `d14fcaf` `refactor(entitlement): gate voices on premium_voices capability` | `isProUserProvider` → `Capability.premiumVoices`; snackbar behavior preserved; `plan_gate` import narrowed to `showUpgradeSnackbar`. |
| 3 | `6583309` `refactor(entitlement): gate settings on capabilities` | Speed ceiling → `limits.max_playback_speed`; SWH lock row + toggles → `swh`; the single `plan == 'writing_nook_pro'` spread split per-capability: Story-Coach → `story_coach`, Help-Guide → `writing_desk`; version label → `writing_desk`. Portal gate (`isStripeSubscribed`) untouched. |
| 4 | `952fcd2` `refactor(entitlement): gate library on capabilities` | Upload preflight → `limits.doc_cap` with `-1` unlimited handling; both open-document predicates → `writing_desk` (same destinations); New Sheet/archive/download → `edit_document`; retry-vs-upgrade tooltip chain preserved via `caps.isUnavailable`. |
| 5 | `f4f0765` `refactor(entitlement): gate writing library and project tab on capabilities` | Library dispatcher → `writing_desk` (Explore keeps the legacy library until PAC-3); uploads → `doc_cap`; project-tab destination → `writing_desk`; right-rail badge → `caps.plan != 'free'` display state, param renamed `isPro` → `isPaidPlan`. |
| 6 | (this commit) `refactor(entitlement): retire the legacy isPro gating surface` | See below. |

## Commit 6 — retirement detail

- **Deleted:** `isProUserProvider`, `monthlyDocLimitFor`, `maxSpeedFor` (zero consumers after commits 2–5).
- **Deprecated, kept:** `PlanStatus.isPro` — `@Deprecated(...)`, zero production consumers; retained with its contract tests as the guard on the `/billing/status` entitlement contract until PlanStatus gating is retired in PAC-6 (founder decision).
- **Unchanged:** `isStripeSubscribed` (Stripe-record check for the Customer Portal, not entitlement); `entitledStatuses` (PAC-2A trial fix); `isFree` + the app.dart confirmed-Free downgrade clamp; the four limit constants (still backing `showUploadLimitPrompt` copy, the Settings speed-subtitle threshold, and the app.dart clamp — mirroring backend plan_limits).
- **Tests adapted (deviation, documented):** the requirement to preserve the 21 plan_gate tests conflicted with deleting `monthlyDocLimitFor`/`maxSpeedFor`, which 2 of the 21 exercised. Those 2 now pin the surviving limit constants (10/50 docs, 2.0/4.0 speed); the other 19 isPro/portal/parsing tests are untouched. Count stays 21. The test file carries `// ignore_for_file: deprecated_member_use_from_same_package` with a comment explaining it intentionally exercises the deprecated contract until PAC-6.

## Static sweep (commit-6 state)

| Sweep | Result |
|---|---|
| `isProUserProvider` in `lib/` | **0 code references** (one deletion-note comment in plan_gate.dart) |
| raw `== 'writing_nook_pro'` in `lib/` | **0 entitlement checks** — survivors are `plan_selection_screen.dart:201` (post-checkout polling) and `:436` (checkout-id compare), both documented billing/checkout surfaces, plus comments |
| legacy `isPro` feature gating in `lib/` | **0** — only historical comments in app.dart |
| `writing_nook_pro` string anywhere in `lib/` | display-name map keys (quota_gate, settings), checkout ids and rank map (plan_selection), doc comments — all documented keeps |

## Validation evidence

Every commit was validated by the operator before approval:
- Focused: 33 tests (12 capability contract + 21 plan_gate contract) — **all passed at every commit**.
- `flutter analyze`: **exactly 708** at every commit (one excursion to 731 during Phase A from 23 test-only `prefer_const_literals_to_create_immutables` infos — fixed via const literals and amended; production diagnostics never increased).
- Full suite (after commit 5): **+207 passing / 2 skipped / 44 failing** — the 44-failure baseline set unchanged, zero new failures (207 = 174 baseline + 33 new unit tests).
- Commit 6 revalidation: same focused + analyze + full-suite gates (operator commands below/in chat).

## Discovery — PAC-2C backlog

`features/writing_desk/summarize_it_panel.dart:126` gates Summarize-it on `billingStatusProvider → llm_tokens_per_period > 0`. Not one of the three legacy patterns (hence missed by every prior inventory), but it is a **non-capability entitlement gate**; the capability model maps it to `Capability.aiSummary`. Left untouched per commit-6 scope; **first item for PAC-2C**. (Backend enforcement via 403 already protects it server-side; its loading behavior is fail-open-to-idle with backend 403 backstop — worth aligning to fail-closed when migrated.)

Also queued (from PAC-1/2A, unchanged): UpgradeExperience (PAC-4) replaces `showUpgradePrompt`/`showUpgradeSnackbar`/`showUploadLimitPrompt`/`setSwhProGate` copy; app.dart clamp + PlanStatus retirement (PAC-6); shell/dispatcher deletion (PAC-3); dead l10n keys (PAC-6).

## Working-tree status at commit 6

`develop` = `f4f0765` + this commit; PAC-2B commits 2–6 are local (pushed at your discretion — desktop-only paths, website deploy will not fire). Pre-existing non-PAC modifications remain uncommitted and untouched: `CLAUDE.md`, `api_client.dart`, `auth_service.dart`, `NewsletterForm.tsx`.

## Rollback

Commits 2–5 independently revertible per surface; commit 6 must be reverted first if any of 2–5 need reverting after it (it deletes their legacy fallbacks). No operational component involved.

---

**STOP — PAC-2B boundary.** Not begun: PAC-2C, UserState, locked CapabilityGate redesign, UpgradeExperience, shell deletion, universal routing, Creative Nook scaffold, website changes.
