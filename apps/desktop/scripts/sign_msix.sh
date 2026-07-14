#!/usr/bin/env bash
# sign_msix.sh — sign the Psitta MSIX with the SSL.com eSigner CKA certificate.
#
# WHY THIS SHAPE:
#   The .msix can ONLY be signed by eSigner CKA + signtool. SSL.com's
#   CodeSignTool does NOT support MSIX (its supported-types list excludes it);
#   eSigner CKA does, because it exposes the cert to signtool via the Windows
#   KSP. CKA owns the login + your phone's authenticator code, so this script
#   never sees or stores any credential — you authenticate inside the CKA app,
#   then this runs signtool against the cert CKA loads into your store.
#
# USAGE (from apps/desktop in Git Bash):
#   bash scripts/sign_msix.sh
#   # or point at a specific package:
#   bash scripts/sign_msix.sh "build/windows/x64/runner/Release/psitta.msix"
#
# If signtool isn't on PATH, set it first, e.g.:
#   SIGNTOOL="/c/Program Files (x86)/Windows Kits/10/bin/10.0.22621.0/x64/signtool.exe" bash scripts/sign_msix.sh

set -euo pipefail

MSIX="${1:-build/windows/x64/runner/Release/psitta.msix}"
CERT_SUBJECT="Facti AI LLC"          # must match the MSIX Publisher CN
TS_URL="http://ts.ssl.com"           # SSL.com RFC-3161 timestamp server
SIGNTOOL="${SIGNTOOL:-signtool}"     # override with a full path if not on PATH

echo "=== Psitta MSIX signing (eSigner CKA + signtool) ==="
echo "Package: $MSIX"
if [ ! -f "$MSIX" ]; then
  echo "ERROR: MSIX not found at: $MSIX"
  echo "Build it first:  flutter build windows --release && dart run msix:create"
  exit 1
fi

cat <<'STEP'

------------------------------------------------------------------------
STEP 1 — Log into eSigner CKA
  Your SSL.com login and your phone's authenticator code go HERE, inside
  SSL.com's own app — never into this script.

  1. Open "SSL.com CKA" / "eSigner CKA" from the Start menu.
  2. Sign in with your SSL.com username + password.
  3. Enter the 6-digit code from your authenticator app on your phone.
  4. If the cert is not already loaded, click "Install Certificate"
     (skipping this makes the cert disappear from Current User\Personal).
------------------------------------------------------------------------
STEP
read -r -p "Press Enter once CKA is logged in and the cert is loaded... " _

echo
echo "STEP 2 — Signing (SHA-256, timestamped)..."
MSYS_NO_PATHCONV=1 "$SIGNTOOL" sign /n "$CERT_SUBJECT" /fd sha256 /tr "$TS_URL" /td sha256 /v "$MSIX"

echo
echo "STEP 3 — Verifying the signature..."
MSYS_NO_PATHCONV=1 "$SIGNTOOL" verify /pa /v "$MSIX"

echo
echo "Done. If verify reports 'Successfully verified' and Publisher"
echo "CN=Facti AI LLC, the package is ready to upload to releases/1.1.0.0/."
