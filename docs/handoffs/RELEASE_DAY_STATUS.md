# Release Day — Repository Health Check
**Date:** 2026-07-23 · **Branch:** `develop` @ `180584e` · **Ahead of origin: 0** (everything through WA-2 is pushed) · Staging index: empty.

## 1. Working tree summary (18 modified tracked files — zero unexpected)

**Group 1 — PAC-3 (10 files, awaiting commit):** `features/auth/plan_selection_screen.dart` (Explore card, six capability groups, trial/subscriber banners, Manage-subscription portal, Phase-4 analyzer fixes) + 4 `.arb` + 5 generated localization classes (18 new keys ×4 languages, 5 vocabulary updates). Validated: analyze 708, focused +33, full suite 207/2/44 byte-match.

**Group 2 — Website Freeze (3 files, approved WA-3/WA-4, awaiting the freeze commits):** `app/download/page.tsx`, `app/support/page.tsx`, `components/pricing/PricingTiers.tsx`. Export already built and verified clean (Explore card, platform wording).

**Group 3 — Fix B (1 file):** `apps/desktop/lib/app.dart` — verified present (the `RB-01 (Fix B)` persistent `ref.listen<AsyncValue<Capabilities>>` at line ~123, exactly one listener). What it changes: keeps the capability provider chain alive for the app's lifetime (billing-chain pattern), so event-handler reads always see resolved entitlements instead of a cold fail-closed baseline. Changes nothing else: fail-closed loading semantics, auth-refresh invalidation, and `autoDispose` all preserved. Founder decision to keep it stands; yesterday's clean-state verification ran with it in the build.

**Group 4 — Pre-existing unrelated (4 files, stay uncommitted):** `CLAUDE.md`, `data/api/api_client.dart`, `data/services/auth_service.dart`, `components/NewsletterForm.tsx`.

**Group 5 — Unexpected: none.** File count and membership match yesterday's PRE_MSIX_CLEANUP_REPORT exactly. Untracked files are the known operator documents/assets/reports.

## 2. RB03 verification — CLEAN
Repo-wide grep across desktop lib and website source: **zero `RB03` references.** Both formerly-instrumented files remain byte-identical to their pre-instrumentation state (md5-proven yesterday) and clean against HEAD.

## 3. Release readiness

READY: PAC-3 code (all automated gates green), Fix B, website freeze content (built + verified export), backend/website production (deployed, green), RC-1 matrix + MSIX procedure documents.
OPEN before MSIX: the four commits below; freeze public verification; RC-1 execution on the new MSIX.

## 4. Recommended commit order (each isolated; commands on approval)

1. **WA-3 commit** — `download/page.tsx` + `support/page.tsx` + WA3 report → `refactor(website): align download and support pages with Psitta platform`
2. **WA-4 commit** — `PricingTiers.tsx` + WA4 report → `refactor(website): align pricing page with the platform Explore state`
   → push (fires CI + Release + Website Deploy) → public verification of all 5 pages → **WEBSITE FROZEN** declaration + `WEBSITE_FREEZE_REPORT.md`.
3. **PAC-3 commit** — 10 files + PAC3 review/implementation/validation reports → the prepared `feat(desktop)` message. *Requires your verdict decision (below).*
4. **Fix B commit** — `app.dart` + RB01/RB02/RB03/cleanup reports → the prepared `fix(entitlement)` message.
   → push desktop commits (CI + Release; no website deploy) → then the MSIX procedure (version bump 1.2.0 = its own commit, per the release gate doc).

**Remain outside the release:** the four pre-existing files (triage post-release), untracked operator documents/assets, `tatus --short` junk file.

## 5. Risks

- **PAC-3 manual-state verdict is the one open gate.** `PAC3_VALIDATION_REPORT.md` does not exist yet (a prior commit attempt failed on exactly this). Yesterday's clean-install verification ran the working-tree build and validated Projects→Play→Writing Desk in all 4 languages — strong evidence, but the PAC-3-specific states (Explore card, trial banner + days remaining, Manage-subscription from Plans) were validated only partially (subscriber portal PASS recorded; earlier session results are tainted by the old-binary finding). **Decision needed:** either (a) accept yesterday's clean-state run + the subscriber PASS as the basis, do a 5-minute Plans-screen check (Explore + one entitled state) on the fresh build, and I'll write the validation report with an honest evidence trail; or (b) run the full remaining matrix first.
- Trial-state banner has never been visually confirmed (needs a trialing account once, ideally during RC-1).
- RC-1 carry-overs: production signing cert required (never the dev pfx — MEDIUM M1), Summarize-it billing-gate (MEDIUM M2, PAC-2C), cold-start lock flicker (LOW).
- Website deploy on step 2's push changes the live site (approved WA-3/WA-4 content) — propagation + verification before the freeze declaration.

## 6. Requiring approval

1. Commit order §4 (or reorder). 2. PAC-3 verdict basis (a) or (b). 3. Go for the freeze push (live-site change). 4. MSIX version confirmation: 1.2.0.0 per the release procedure.

---
**STOP.** No commit, no push, no build. Awaiting approvals.

---

## Addendum — 2026-07-23: Version 2.0.0 approvals recorded

- **Release version: Psitta 2.0.0** (supersedes the 1.2.0.0 recommendation in RC1_MSIX_RELEASE_PROCEDURE.md — every mechanic in that procedure applies verbatim with `2.0.0+0` / MSIX `2.0.0.0` / `releases/2.0.0.0/` substituted).
- Approved: commit order (§4), Website Freeze execution, PAC-3 validation basis Option A (clean-state run + recorded subscriber evidence; Trial banner honestly documented as not visually validated, carried to RC-1).
- Generated this session: PAC3_VALIDATION_REPORT.md (verdict: READY FOR COMMIT), WEBSITE_FREEZE_REPORT.md (prepared; declaration on verification), RELEASE_NOTES_2_0_0.md.
- Note for the version-bump commit: Explore-state Settings pins the label "Psitta v1.1.0" (tier-aware, L2) — with 2.0.0 branding, founder may want this line updated in the bump commit (one string, four locales not required — it is hardcoded); flagged, not changed.

## Addendum 2 — Final approved commit order (supersedes §4)

Founder-approved release sequence: **Commit 1 PAC-3 → Commit 2 Fix B → Commit 3 WA-3 → Commit 4 WA-4** — desktop first, website second, for cleaner rollback. Mandatory gate before every commit: `git diff --cached --name-only`, verify only intended files staged. Single push to develop after all four commits; wait for CI + Release + Deploy Website; **STOP after green** — no MSIX build, no version bump, no signing, no publication until the next approval.
