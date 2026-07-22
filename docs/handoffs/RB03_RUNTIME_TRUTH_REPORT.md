# RB-03 — Runtime Truth Report
## (Section 1 complete from disk evidence; Sections 2–7 AWAITING the operator capture below)

**Date:** 2026-07-22 · **Rule of this report:** observed evidence only; every pending item is marked AWAITING, never inferred.

---

## 1. Build identity — MEASURED (filesystem evidence, decisive)

Executables present in the repository build tree (`apps/desktop/build/windows/x64/runner/`):

| Binary | Built | Contains |
|---|---|---|
| `Debug/psitta.exe` | **2026-07-15 17:49** | Code as of ~Jul 15 (A4-era `develop`, `922d5ec`) |
| `Release/psitta.exe` | **2026-07-14 12:59** | Code as of ~Jul 14 |
| `Release/psitta.msix` (local) | **2026-07-14 13:31** | Same as Release exe (v1.1.2.0) |

A `find` for any `.exe` newer than Jul 19 returns **nothing**.

**Measured conclusion:** every binary on this machine predates Phase 1 desktop consolidation (Jul 20–21), PAC-2A/2B (Jul 20–21), PAC-3 (Jul 21), and RB-01 Fix B (Jul 22). **No executable on this machine has ever contained the capability-driven navigation, the one-shell library dispatcher path under test, the PAC-3 Plans screen, or Fix B.** Unless the operator launched from a second checkout elsewhere, the RB-01 and RB-02 reproductions — and the screenshots — were captured on pre-consolidation code, where the legacy Library, legacy chrome, and legacy Player are simply *the app*.

**Open item the operator must resolve (AWAITING):** the earlier PAC-3 subscriber validation reported an "Active subscription" banner, which exists only in post-Jul-21 code no on-disk binary contains. Confirm which executable that session used (second checkout? installed app + recollection of the Stripe portal page rather than the in-app banner?). PowerShell for the installed app's identity:
```powershell
Get-AppxPackage com.factiai.psitta | Select-Object Name, Version, InstallLocation
```

## 2–6. Runtime capability payload · billing payload · comparison · auth state · navigation trace — AWAITING CAPTURE

Instrumentation is in place (temporary, marked `RB03-TEMP`, in `core/capabilities.dart` and `projects/widgets/project_documents_tab.dart`; pre-instrumentation md5s recorded — `edaa6e6e…`, `101a00bd…` — for verified removal).

**Operator capture protocol (one session, ~5 minutes):**
```bash
cd /c/products/psitta/apps/desktop
flutter run -d windows 2>&1 | tee /tmp/rb03_runtime.txt
```
This *guarantees* the working-tree build — eliminating binary ambiguity for the instrumented run (a fresh `Debug/psitta.exe` timestamp is itself Q1 evidence). Then, in the app, logged in as the **subscriber** account:
1. Let the app settle on the Library (note which library renders).
2. Open Plans (note: new Explore card + banner = working-tree confirmed on screen).
3. Projects → the RB-01/RB-02 project → Documents → click **▶ Play**.
4. Quit. Paste every `[RB03]` line from the console (or `grep "\[RB03\]" /tmp/rb03_runtime.txt`).

The `[RB03]` lines capture: the exact `/users/me/capabilities` HTTP status + body (or error) — §2; `billing.plan/status/source` at the decision moment — §3; agreement/divergence — §4; and `caps → decision → destination` — §6. For §5 (auth/installation state), additionally run:
```powershell
Get-AppxPackage com.factiai.psitta | Select Version, InstallLocation   # installed copies
```
and note whether the instrumented session required a fresh login (cached Cognito state).

## 7. Final diagnosis — WITHHELD until §2–6 data lands

**What can already be said from measurement alone:** the answer to "why did the operator reach the legacy Reading experience" is, on current evidence, **RB-02's H1 — the binary under test predates the platform architecture** (Section 1). This differs from RB-01's conclusion because RB-01 analyzed the *working tree* — correct for the code, silent on what was actually executing; and it sharpens RB-02, which had narrowed to two hypotheses. H2 (runtime capability fetch failing on an entitled session) remains formally open until the instrumented run prints the actual payload — the capture above closes it either way. No speculation beyond this line; the instrumented session completes the report.

---
**STOP.** No architecture changed; instrumentation is temporary and will be removed (md5-verified) immediately after capture. No commit, no push. Awaiting the operator capture output.
