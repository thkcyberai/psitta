#!/usr/bin/env python3
"""Inspect / sync ElevenLabs voices for catalog curation.

Purpose
-------
``voice_catalog_static.py`` is a hand-curated list. To add real, native
Portuguese / Spanish / French premium voices we need *actual* voice IDs —
not fabricated ones. This tool uses the SAME key the backend uses
(``ELEVENLABS_API_KEY``) to:

  1. list the account's own voices (``GET /v1/voices``), and
  2. surface native candidates from the public Voice Library
     (``GET /v1/shared-voices``) for the target languages,

then writes everything to a JSON file for review. The API key is read from
the environment or ``core/backend/.env`` and is **never printed**.

Usage (run inside the backend venv, where httpx + .env live):
    ./.venv/Scripts/python.exe scripts/sync_elevenlabs_voices.py
    python scripts/sync_elevenlabs_voices.py --langs pt es fr --per-lang 8
    python scripts/sync_elevenlabs_voices.py --output elevenlabs_voices_dump.json
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
from collections import Counter

import httpx  # already a backend dependency

BASE = "https://api.elevenlabs.io/v1"


def load_key() -> str:
    """ELEVENLABS_API_KEY from env, else parsed from a nearby .env. Never logged."""
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if key:
        return key
    here = pathlib.Path(__file__).resolve()
    for d in [here.parent, *here.parents]:
        env = d / ".env"
        if env.exists():
            for line in env.read_text(encoding="utf-8").splitlines():
                s = line.strip()
                if s.startswith("ELEVENLABS_API_KEY") and "=" in s:
                    v = s.split("=", 1)[1].strip().strip('"').strip("'")
                    if v:
                        return v
    return ""


def account_voices(key: str) -> list[dict]:
    r = httpx.get(f"{BASE}/voices", headers={"xi-api-key": key}, timeout=20.0)
    if r.status_code != 200:
        raise RuntimeError(f"/v1/voices HTTP {r.status_code}: {r.text[:500]}")
    out = []
    for v in r.json().get("voices", []):
        labels = v.get("labels", {}) or {}
        out.append({
            "voice_id": v.get("voice_id"),
            "name": v.get("name"),
            "category": v.get("category"),
            "gender": labels.get("gender"),
            "language": labels.get("language"),
            "accent": labels.get("accent"),
            "description": labels.get("description"),
        })
    return out


def library_candidates(key: str, language: str, per_lang: int, accent: str | None = None) -> list[dict]:
    """Native voices from the public Voice Library for a language code (pt/es/fr)."""
    params = {"language": language, "page_size": per_lang, "sort": "trending"}
    if accent:
        params["accent"] = accent
    r = httpx.get(f"{BASE}/shared-voices", headers={"xi-api-key": key},
                  params=params, timeout=20.0)
    if r.status_code != 200:
        return [{"_error": f"shared-voices HTTP {r.status_code}"}]
    out = []
    for v in r.json().get("voices", []):
        out.append({
            "public_owner_id": v.get("public_owner_id"),
            "voice_id": v.get("voice_id"),
            "name": v.get("name"),
            "language": v.get("language"),
            "accent": v.get("accent"),
            "gender": v.get("gender"),
            "age": v.get("age"),
            "use_case": v.get("use_case"),
            "preview_url": v.get("preview_url"),
        })
    return out




def add_shared_voice(key: str, owner: str, vid: str, name: str) -> dict:
    """Add a public Voice-Library voice to the account. Returns the NEW voice_id."""
    r = httpx.post(f"{BASE}/voices/add/{owner}/{vid}",
                   headers={"xi-api-key": key}, json={"new_name": name}, timeout=30.0)
    if r.status_code not in (200, 201):
        return {"error": f"HTTP {r.status_code}: {r.text[:300]}"}
    return {"voice_id": r.json().get("voice_id")}


def run_add(key: str, picks_path: str, out_path: str) -> int:
    picks = json.loads(pathlib.Path(picks_path).read_text(encoding="utf-8"))
    catalog_entries = []
    for pk in picks:
        res = add_shared_voice(key, pk["public_owner_id"], pk["voice_id"], pk["display_name"])
        if "error" in res:
            print(f"  ADD FAIL {pk['display_name']} ({pk['language']}): {res['error']}")
            continue
        new_id = res["voice_id"]
        print(f"  added {pk['display_name']:10s} {pk['language']}  -> {new_id}")
        catalog_entries.append({
            "id": new_id,
            "name": pk["display_name"],
            "display_name": pk["display_name"],
            "language": pk["language"],
            "gender": pk["gender"],
            "provider": "elevenlabs",
            "tier": "premium",
        })
    pathlib.Path(out_path).write_text(
        json.dumps(catalog_entries, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nAdded {len(catalog_entries)}/{len(picks)}. Catalog-ready entries written to: {out_path}")
    return 0



def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--langs", nargs="*", default=["pt", "es", "fr"])
    ap.add_argument("--per-lang", type=int, default=8)
    ap.add_argument("--accent", default=None,
                    help="Filter Voice-Library results by accent (e.g. european).")
    ap.add_argument("--no-shared", action="store_true",
                    help="Skip the public Voice Library lookup.")
    ap.add_argument("--add", default=None,
                    help="Path to a picks JSON; adds those Voice-Library voices "
                         "to the account and writes catalog-ready entries to --output.")
    ap.add_argument("--output", default="elevenlabs_voices_dump.json")
    args = ap.parse_args()

    key = load_key()
    if not key:
        print("ERROR: ELEVENLABS_API_KEY not set and not found in a .env. "
              "Run from core/backend (where .env lives) or export the key.",
              file=sys.stderr)
        return 2

    if args.add:
        return run_add(key, args.add, args.output)

    result: dict = {"account_voices": [], "library_candidates": {}}
    try:
        result["account_voices"] = account_voices(key)
    except Exception as e:  # noqa: BLE001
        print(f"ERROR fetching account voices: {e}", file=sys.stderr)
        return 1

    if not args.no_shared:
        for lang in args.langs:
            result["library_candidates"][lang] = library_candidates(
                key, lang, args.per_lang, args.accent)

    pathlib.Path(args.output).write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")

    acct = result["account_voices"]
    by_lang = Counter((v.get("language") or "unknown") for v in acct)
    print(f"Account voices: {len(acct)}  |  by language: {dict(by_lang)}")
    for lang, cands in result["library_candidates"].items():
        real = [c for c in cands if "voice_id" in c]
        print(f"Voice Library — {lang}: {len(real)} native candidates")
    print(f"\nWritten to: {args.output}  (no secrets inside — safe to share)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
