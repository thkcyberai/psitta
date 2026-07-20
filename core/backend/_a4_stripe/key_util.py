"""Shared Stripe key loading for the A4 scripts — robust in Git Bash.

Load order:
  1. STRIPE_API_KEY environment variable
  2. STRIPE_KEY_FILE environment variable → path to a file whose first
     line is the key (create it with notepad; delete it afterwards)
  3. --key-file <path> command-line argument (same file format)

The interactive `read -rsp` approach proved unreliable in Git Bash
(mintty can silently drop pasted input on hidden prompts), so the
key-file method is now the recommended path: the key never appears on
screen, never enters shell history, and the file is deleted right
after use.

On rejection this module prints a MASKED diagnostic — first 8
characters and total length only, never the key — so the failure mode
is identifiable (e.g. a publishable pk_test_… key pasted instead of
the secret sk_test_… key).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

_VALID_PREFIXES = ("sk_test_", "rk_test_", "sk_live_", "rk_live_")


def _die(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)


def _mask(raw: str) -> str:
    return f"{raw[:8]}… (length {len(raw)})" if raw else "(empty)"


def load_stripe_key() -> tuple[str, str]:
    """Return (key, mode) where mode is 'test' or 'live'. Exits on error."""
    key = os.environ.get("STRIPE_API_KEY", "").strip().strip("'\"")
    source = "STRIPE_API_KEY env var"

    if not key:
        path = os.environ.get("STRIPE_KEY_FILE", "").strip()
        if "--key-file" in sys.argv:
            idx = sys.argv.index("--key-file")
            if idx + 1 >= len(sys.argv):
                _die("--key-file requires a path argument.")
            path = sys.argv[idx + 1]
        if path:
            p = Path(path)
            if not p.exists():
                _die(f"key file not found: {path}")
            key = p.read_text(encoding="utf-8-sig").strip().strip("'\"")
            source = f"key file {path}"

    if not key:
        _die(
            "no Stripe key provided. Either:\n"
            "  export STRIPE_API_KEY=sk_...          (env var), or\n"
            "  notepad _a4_stripe/key.txt            (paste key, save), then\n"
            "  run with:  --key-file _a4_stripe/key.txt\n"
            "  (delete the file afterwards: rm _a4_stripe/key.txt)"
        )

    if not key.startswith(_VALID_PREFIXES):
        hint = ""
        if key.startswith("pk_"):
            hint = (
                "\nThis is a PUBLISHABLE key (pk_…). The audit needs the "
                "SECRET key: Stripe Dashboard → Developers → API keys → "
                "'Secret key' → Reveal. It starts with sk_test_ or sk_live_."
            )
        elif key.startswith("whsec_"):
            hint = "\nThis is a webhook signing secret, not an API key."
        _die(
            f"value from {source} does not look like a Stripe secret key: "
            f"{_mask(key)}{hint}"
        )

    mode = "test" if "_test_" in key[:8] else "live"
    print(f"Using {mode.upper()}-mode key from {source} ({_mask(key)})")
    return key, mode
