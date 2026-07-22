# Psitta Platform — MSIX Release Procedure (Version 2.0.0)
## Release gate only — DO NOT EXECUTE the publish steps until the RC smoke matrix is run and the founder issues GO

**Current shipped:** 1.1.2+0 (MSIX 1.1.2.0) · **This release: 2.0.0+0 (MSIX 2.0.0.0)** — founder-approved major version for the Writing Nook Platform release (product consolidation + capability architecture + trial entitlement fix + platform-aligned Plans/website). Supersedes this document's earlier 1.2.0.0 recommendation. **MSIX versions must be strictly increasing — App Installer will not downgrade** (this drives the rollback design).

## 0. Preconditions (hard gate)

- [x] The five release commits deployed and green (PAC-3 `4942fd8`, Fix B `5d09c8f`, WA-3 `4ff1d57`, WA-4 `46ae571`, product hero `d2c7e21`): CI ✓ Release ✓ Deploy Website ✓ (founder-confirmed 2026-07-24).
- [ ] Version-bump commit landed and CI green on it.
- [ ] RC smoke matrix executed on the RC build; zero BLOCKER, zero open HIGH.
- [ ] Production signing certificate available per `Psitta_Release_Signing_Tutorial_v1_0` — NOT `psitta-dev.pfx` for anything public (finding M1).
- [ ] `download.psitta.ai` upload access confirmed (S3/CloudFront serving `psitta.appinstaller` + `releases/`).

## 1. Version bump (one isolated commit — see VERSION_2_0_0_RELEASE_CHECKLIST.md)

`pubspec.yaml` → `version: 2.0.0+0` + `msix_version: 2.0.0.0`; `psitta.appinstaller` → `Version="2.0.0.0"` (AppInstaller AND MainPackage) + `MainPackage Uri=".../releases/2.0.0.0/psitta.msix"`; Settings version label unified to the real build version (removes the hardcoded v1.1.0 pin). Staging gated by `git diff --cached --name-only`; message `release: bump desktop to v2.0.0 (MSIX 2.0.0.0)`. Push, verify CI green before building.

## 2. Build the Release Candidate

```bash
cd /c/products/psitta/apps/desktop
flutter clean && flutter pub get
flutter analyze            # expect 708 parity
flutter build windows --release
dart run msix:create       # sign_msix: false → UNSIGNED psitta.msix
```
Gates: zero build errors; produced MSIX reports **2.0.0.0**; record SHA256 (`certutil -hashfile build\windows\x64\runner\Release\psitta.msix SHA256` — path per msix output).

## 3. RC signing for local validation — FOUNDER DECISION REQUIRED

Windows will not install an unsigned MSIX, so the install/uninstall/identity rows of the smoke matrix cannot run on the artifact from §2 as-is.

**Recommended:** sign a COPY of the RC with the dev certificate, strictly for local validation:
```bash
signtool sign /fd SHA256 /f psitta-dev.pfx /p <dev password> /tr http://timestamp.digicert.com /td SHA256 psitta-rc.msix
```
Quarantine rules (non-negotiable): the dev-signed artifact is named `psitta-rc.msix`, never leaves the machine, is never uploaded anywhere, and is deleted after validation. The public release is the §2 artifact signed with the PRODUCTION certificate only (§5). The dev cert must be in the machine's trusted store for install to succeed (it is, from prior dev installs — otherwise import to Local Machine → Trusted People first).
**Alternative (weaker):** validate the unpackaged `flutter build windows` release build only — loses installation, identity, uninstall/reinstall, and update-mechanism coverage. Not recommended for a major release.

## 4. RC smoke validation

Run `RC1_SMOKE_MATRIX.md` against the RC install. **Step 0 (RB-03 lesson): verify build identity FIRST** — Settings/Plans must show v2.0.0 and the platform Plans screen before any other row counts. Priority rows for this release: fresh install → startup → login + signup → Projects → Play → Writing Desk → document playback/highlighting → Blueprints + Structure Analyzer + Story Coach → subscription detection (subscriber account) → trial detection (trialing account — the never-yet-seen Trial banner, H2/H3) → Explore locks → Settings (incl. version label on BOTH an entitled and a free account) → uninstall → reinstall. Record PASS/FAIL per row; screenshots for the record. Upgrade path is validated in §6 (staged publish), not here — a dev-signed RC is not a valid upgrade source for the production-signed 1.1.2.0 install.

## 5. Production signing (after founder GO only — never the dev pfx)

```bash
signtool sign /fd SHA256 /f <PROD_CERT.pfx> /p <PROD_PASSWORD> /tr http://timestamp.digicert.com /td SHA256 psitta.msix
signtool verify /pa psitta.msix
```
Gate: signature verifies AND cert subject matches the package Publisher (`CN=Facti AI LLC, O=Facti AI LLC, L=Colorado Springs, S=Colorado, C=US`) — mismatch bricks installation for every user. Timestamping mandatory.

## 6. Staged publish — ORDER MATTERS (upgrade path proven before exposure)

1. Upload the production-signed MSIX to `releases/2.0.0.0/psitta.msix` FIRST. Verify it serves (200, correct size, SHA256 match). The public `psitta.appinstaller` still points at 1.1.2.0 — no user is exposed yet.
2. **Upgrade-path validation:** on one machine running production 1.1.2.0, open the NEW local `psitta.appinstaller` (2.0.0.0) directly → the in-place upgrade must apply and launch as v2.0.0 with account/documents intact. This is the true production-signed upgrade test.
3. Only then upload the 2.0.0.0 `psitta.appinstaller` to the root, replacing 1.1.2.0's.
4. Invalidate the CDN path for `/psitta.appinstaller` if cached.
5. **Do NOT delete `releases/1.1.2.0/`** — rollback forensics + pinned installs.

## 7. Release verification

- [ ] Fresh machine (or clean uninstall): public appinstaller link installs → v2.0.0 launches.
- [ ] Auto-update: a second 1.1.2.0 machine relaunches → picks up 2.0.0.0 within the 24h OnLaunch window (non-blocking).
- [ ] Post-install critical smoke: login, play/pause/highlight, Explore locks, Trial entitlement incl. Customer Portal tile, doc-cap prompt.
- [ ] Settings shows v2.0.0 (all tiers — the pin is gone).
- [ ] Optional: tag `v2.0.0` on the release commit (note: a `v*` tag also triggers release.yml's tag path — backend GHCR image + GitHub Release; harmless, but deliberate).

## 8. Rollback procedure (forward-fix from last-good — MSIX cannot downgrade)

1. Immediate mitigation: re-upload the 1.1.2.0 `psitta.appinstaller` → stops NEW installs/updates of the bad build (existing 2.0.0.0 installs keep running it).
2. Build the rollback from the last-good commit with a HIGHER version (e.g. `2.0.0.1`), production-sign, publish per §5–6. Auto-update replaces the bad build within 24h.
3. Server-side-mitigable defects (entitlement, billing): prefer a backend fix via develop — faster than any client rollout.
4. Record the incident; the bad `releases/<ver>/` directory is retained, never reused.

---
**STOP.** Publish steps (§5–§8) execute only after founder GO on the RELEASE_CANDIDATE_REPORT.
