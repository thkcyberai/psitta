#!/usr/bin/env python3
"""Audit the ElevenLabs voices used in Psitta's catalog against what those IDs
actually are in *your* ElevenLabs account.

Why: the catalog's non-English ElevenLabs voices were added by ID, and some IDs
point to the wrong voice (e.g. "Matheus" resolving to a female / English voice).
This script calls GET /v1/voices with your key and, for every ElevenLabs voice
in the catalog, prints what WE claim vs what ElevenLabs actually reports
(name, language, gender, accent), flagging mismatches. It also lists every
Portuguese / Spanish / French voice already in your account, with IDs, so you
can copy the correct ones straight into voice_catalog_static.py.

Run (Git Bash / PowerShell), from the backend dir, with your key in the env:

    export ELEVENLABS_API_KEY=sk_...        # (PowerShell: $env:ELEVENLABS_API_KEY="sk_...")
    python scripts/audit_elevenlabs_voices.py

Nothing is written or changed — this is read-only.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.request

# The ElevenLabs entries from voice_catalog_static.py (id, our label, our lang,
# our gender). Kept inline so the script runs standalone.
CATALOG_EL = [
    ("21m00Tcm4TlvDq8ikWAM", "Rachel",   "en-US", "female"),
    ("EXAVITQu4vr4xnSDxMaL", "Bella",    "en-US", "female"),
    ("AZnzlk1XvdvUeBnXmlld", "Domi",     "en-US", "female"),
    ("MF3mGyEYCl7XYWbV9V6O", "Elli",     "en-US", "female"),
    ("XB0fDUnXU5powFXDhCwa", "Glinda",   "en-US", "female"),
    ("pNInz6obpgDQGcFmaJgB", "Adam",     "en-US", "male"),
    ("29vD33N1CtxCmqQRPOHJ", "Drew",     "en-US", "male"),
    ("ErXwobaYiN019PkySvjV", "Antoni",   "en-US", "male"),
    ("2EiwWnXFnvU5JabPnv8n", "Clyde",    "en-US", "male"),
    ("TxGEqnHWrfWFTfGW9XjX", "Josh",     "en-US", "male"),
    ("VR6AewLTigWG4xSOukaG", "Arnold",   "en-US", "male"),
    ("yoZ06aMxZJJ28mfd3POQ", "Sam",      "en-US", "male"),
    # non-English "native premium" — the suspect set
    ("oArP4WehPe3qjqvCwHNo", "Matheus",  "pt-BR", "male"),
    ("sXSV9RZ095VZyL64w3ap", "Alexa",    "pt-BR", "female"),
    ("Cmqnney5svFebDMl5Y9L", "Gael",     "es-ES", "male"),
    ("AxFLn9byyiDbMn5fmyqu", "Aitana",   "es-ES", "female"),
    ("UBXZKOKbt62aLQHhc1Jm", "Francois", "fr-FR", "male"),
    ("cuo3D4C6LVenyV7b2Kpd", "Anna",     "fr-FR", "female"),
    ("hOLl3246BMBsdy0qtYLb", "Nelson",   "pt-PT", "male"),
    ("nJ5NFqyKb8kn9JBPmo6i", "Joana",    "pt-PT", "female"),
]

API = "https://api.elevenlabs.io/v1/voices"


def fetch_voices(key: str) -> dict:
    req = urllib.request.Request(API, headers={"xi-api-key": key})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    out = {}
    for v in data.get("voices", []):
        labels = v.get("labels", {}) or {}
        out[v["voice_id"]] = {
            "name": v.get("name", "?"),
            "gender": (labels.get("gender") or "?").lower(),
            "language": labels.get("language") or labels.get("accent") or "?",
            "accent": labels.get("accent") or "?",
            "descriptive": labels.get("descriptive") or "",
        }
    return out


def norm_lang(s: str) -> str:
    s = (s or "").lower()
    if "portug" in s or s.startswith("pt"):
        return "pt"
    if "spanish" in s or "espa" in s or s.startswith("es"):
        return "es"
    if "french" in s or "fran" in s or s.startswith("fr"):
        return "fr"
    if "english" in s or s.startswith("en"):
        return "en"
    return s[:2]


def main() -> int:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        print("ERROR: set ELEVENLABS_API_KEY in your environment first.", file=sys.stderr)
        return 2
    try:
        account = fetch_voices(key)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR calling ElevenLabs: {exc}", file=sys.stderr)
        return 1

    print("=" * 92)
    print("CATALOG AUDIT  (our label  ->  what ElevenLabs actually says for that ID)")
    print("=" * 92)
    print(f"{'OUR NAME':10} {'ID':22} {'OURS':14} {'ELEVENLABS ACTUAL':34} FLAG")
    print("-" * 92)
    for vid, name, lang, gender in CATALOG_EL:
        ours = f"{lang}/{gender}"
        real = account.get(vid)
        if real is None:
            print(f"{name:10} {vid:22} {ours:14} {'** NOT IN YOUR ACCOUNT **':34} MISSING")
            continue
        rlang = norm_lang(real["language"])
        real_s = f"{real['name']}·{real['language']}·{real['gender']}"
        flags = []
        if real["gender"] not in ("?", gender):
            flags.append("GENDER")
        if norm_lang(lang) != "en" and rlang not in ("?",) and rlang != norm_lang(lang):
            flags.append("LANG/ACCENT")
        flag = ",".join(flags) if flags else "ok"
        print(f"{name:10} {vid:22} {ours:14} {real_s:34} {flag}")

    print()
    print("=" * 92)
    print("VOICES IN YOUR ACCOUNT TAGGED Portuguese / Spanish / French")
    print("(copy the correct IDs into voice_catalog_static.py)")
    print("=" * 92)
    for want in ("pt", "es", "fr"):
        rows = [
            (vid, m) for vid, m in account.items() if norm_lang(m["language"]) == want
        ]
        label = {"pt": "PORTUGUESE", "es": "SPANISH", "fr": "FRENCH"}[want]
        print(f"\n-- {label} ({len(rows)}) --")
        if not rows:
            print("   (none in your account — add some from the ElevenLabs Voice Library)")
        for vid, m in rows:
            print(f"   {vid:22} {m['name']:16} {m['gender']:8} {m['language']}  {m['descriptive']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
