#!/usr/bin/env python3
"""Phase C enrichment pass for the psitta-ad-search skill.

Iterates the gold + silver ads kept by Phase B, calls AdLibrary's
/api/enrichment endpoint once per ad (1 credit each, cached responses
free), and merges the AI-generated enrichment object (summary +
transcription + analysis + ugc_script) onto each ad record.

  Input:  samples/phase_b_results.json
  Output: samples/phase_c_results.json
          PHASE_C_SUMMARY.md

Failure tolerance:
  - 401/403 -> fatal: halt run, write checkpoint, exit 2.
  - 429 -> respect Retry-After, retry once; otherwise mark and continue.
  - 5xx -> retry once after throttle; otherwise mark and continue.
  - Network exception -> mark and continue.
  - Schema mismatch (no "enrichment" key) -> mark and continue.
  - Per-ad failures never halt the run.

Stdlib only. Token is read from .env and never written to disk or logs.
Checkpoints every CHECKPOINT_EVERY ads so a mid-run crash leaves a
resumable artifact behind.
"""
from __future__ import annotations

import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# TODO: factor token loading + redaction + http_post_json into a shared
# helpers module once a fourth script enters the skill. Duplicated from
# discovery.py / phase_b_search.py for now.

SCRIPT_VERSION = "1.0"
ENRICHMENT_URL = "https://adlibrary.com/api/enrichment"
USER_AGENT = "psitta-ad-search-phase-c/1.0 (+https://psitta.ai)"

THROTTLE_MS = 100
MAX_RETRIES_PER_AD = 2
CHECKPOINT_EVERY = 25

SCRIPT_PATH = Path(__file__).resolve()
SCRIPTS_DIR = SCRIPT_PATH.parent
SKILL_DIR = SCRIPTS_DIR.parent
SAMPLES_DIR = SKILL_DIR / "samples"
INPUT_PATH = SAMPLES_DIR / "phase_b_results.json"
OUTPUT_PATH = SAMPLES_DIR / "phase_c_results.json"
SUMMARY_PATH = SKILL_DIR / "PHASE_C_SUMMARY.md"

MAX_CALLS_HARD_CAP = 230  # halts before a 231st call

ADL_TOKEN_RE = re.compile(r"adl_[A-Za-z0-9_\-]+")

AUTH_FATAL = object()  # sentinel returned from enrich_one on 401/403


# ── Token loading ──────────────────────────────────────────────────────────


def resolve_env_path() -> Path:
    candidates = [
        Path("/c/products/psitta/.env"),
        Path("C:/products/psitta/.env"),
        SCRIPT_PATH.parents[4] / ".env" if len(SCRIPT_PATH.parents) > 4 else None,
    ]
    for cand in candidates:
        if cand is None:
            continue
        try:
            if cand.exists():
                return cand
        except OSError:
            continue
    return Path("/c/products/psitta/.env")


def read_token(env_path: Path) -> str:
    try:
        with env_path.open("r", encoding="utf-8") as fh:
            for raw_line in fh:
                line = raw_line.strip()
                if not line.startswith("ADLIBRARY_API_KEY="):
                    continue
                value = line[len("ADLIBRARY_API_KEY="):].strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
                    value = value[1:-1]
                if not value:
                    sys.stderr.write("ERROR: ADLIBRARY_API_KEY is present but empty.\n")
                    sys.exit(3)
                return value
    except FileNotFoundError:
        sys.stderr.write(f"ERROR: .env not found at {env_path}\n")
        sys.exit(3)
    sys.stderr.write("ERROR: ADLIBRARY_API_KEY line not found in .env\n")
    sys.exit(3)


# ── Redaction ──────────────────────────────────────────────────────────────


def redact_text(text: str, token: str) -> str:
    if not isinstance(text, str):
        return text
    out = text
    if token and token in out:
        out = out.replace(token, "[REDACTED]")
    out = ADL_TOKEN_RE.sub("[REDACTED]", out)
    return out


def redact_obj(obj, token: str):
    if isinstance(obj, dict):
        return {k: redact_obj(v, token) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_obj(v, token) for v in obj]
    if isinstance(obj, str):
        return redact_text(obj, token)
    return obj


def write_json(path: Path, obj, token: str) -> None:
    redacted = redact_obj(obj, token)
    text = json.dumps(redacted, indent=2, ensure_ascii=False)
    text = redact_text(text, token)
    path.write_text(text, encoding="utf-8")


# ── HTTP ────────────────────────────────────────────────────────────────────


def http_post_json(url: str, payload: dict, token: str, allow_429_retry: bool = True):
    body_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body_bytes,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.getcode(), dict(resp.headers.items()), resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        headers = dict(e.headers.items()) if e.headers else {}
        if e.code == 429 and allow_429_retry:
            ra = headers.get("Retry-After", "5")
            try:
                wait = int(ra)
            except ValueError:
                wait = 5
            time.sleep(min(max(wait, 1), 60))
            return http_post_json(url, payload, token, allow_429_retry=False)
        try:
            err_body = e.read().decode("utf-8", errors="replace")
        except Exception:  # noqa: BLE001 — urllib non-standard read variants
            err_body = ""
        return e.code, headers, err_body
    except urllib.error.URLError:
        return -1, {}, ""  # network failure sentinel


# ── Payload + per-ad enrichment ────────────────────────────────────────────


def build_enrichment_payload(ad: dict) -> dict:
    """Build the /api/enrichment request payload from an ad record."""
    ad_key = ad.get("ad_key") or ""
    if not ad_key:
        raise ValueError("ad_key required")
    return {
        "ad": {
            "ad_key": ad_key,
            "platform": ad.get("platform") or "",
            "advertiser_name": ad.get("advertiser_name") or "",
            "body": ad.get("body") or "",
            "preview_img_url": ad.get("preview_img_url") or "",
        }
    }


def short_key(ad_key: str) -> str:
    if not ad_key:
        return "<no-key>"
    return ad_key[:8] + "…" if len(ad_key) > 9 else ad_key


def enrich_one(ad: dict, idx: int, total: int, token: str):
    """Call /api/enrichment once. Returns 'continue', 'auth_fatal', or 'no_key'."""
    try:
        payload = build_enrichment_payload(ad)
    except ValueError:
        ad["_enrichment_status"] = "no_ad_key"
        ad["_enrichment_cached"] = False
        sys.stderr.write(f"[{idx}/{total}] no ad_key — skipping\n")
        return "no_key"

    attempts = 0
    while attempts < MAX_RETRIES_PER_AD:
        attempts += 1
        status, _hdrs, raw = http_post_json(ENRICHMENT_URL, payload, token)

        if status in (401, 403):
            ad["_enrichment_status"] = f"auth_{status}"
            ad["_enrichment_cached"] = False
            sys.stderr.write(
                f"[{idx}/{total}] FATAL HTTP {status} on ad_key={short_key(ad.get('ad_key', ''))}\n"
            )
            return "auth_fatal"

        if status == 200:
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError as e:
                if attempts < MAX_RETRIES_PER_AD:
                    time.sleep(THROTTLE_MS / 1000.0)
                    continue
                ad["_enrichment_status"] = "bad_json"
                ad["_enrichment_cached"] = False
                sys.stderr.write(
                    f"[{idx}/{total}] bad JSON ad_key={short_key(ad.get('ad_key', ''))}: {e}\n"
                )
                return "continue"

            enrichment = obj.get("enrichment") if isinstance(obj, dict) else None
            if not isinstance(enrichment, dict):
                ad["_enrichment_status"] = "schema_mismatch"
                ad["_enrichment_cached"] = False
                sys.stderr.write(
                    f"[{idx}/{total}] schema mismatch (no 'enrichment') "
                    f"ad_key={short_key(ad.get('ad_key', ''))}\n"
                )
                return "continue"

            ad["enrichment"] = enrichment
            ad["_enrichment_status"] = "ok"
            ad["_enrichment_cached"] = bool(obj.get("cached"))
            ad["_enrichment_credits_used"] = obj.get("creditsUsed", 0)
            ad["_enrichment_balance_after"] = obj.get("balance")
            adv = (ad.get("advertiser_name") or "")[:40]
            print(
                f"[{idx}/{total}] ad_key={short_key(ad.get('ad_key', ''))} "
                f"advertiser={adv} status=ok cached={ad['_enrichment_cached']}"
            )
            return "continue"

        # transient failures — retry once after throttle
        if status == 429 or status >= 500 or status == -1:
            if attempts < MAX_RETRIES_PER_AD:
                time.sleep(max(THROTTLE_MS / 1000.0, 1.0))
                continue
            if status == 429:
                ad["_enrichment_status"] = "rate_limited"
            elif status == -1:
                ad["_enrichment_status"] = "network_error"
            else:
                ad["_enrichment_status"] = f"server_error_{status}"
            ad["_enrichment_cached"] = False
            sys.stderr.write(
                f"[{idx}/{total}] {ad['_enrichment_status']} "
                f"ad_key={short_key(ad.get('ad_key', ''))}\n"
            )
            return "continue"

        # other 4xx (e.g., 400 bad request, 404) — log and continue without retry
        ad["_enrichment_status"] = f"http_{status}"
        ad["_enrichment_cached"] = False
        masked_body = redact_text((raw or "")[:200], token)
        sys.stderr.write(
            f"[{idx}/{total}] http_{status} ad_key={short_key(ad.get('ad_key', ''))} "
            f"body={masked_body}\n"
        )
        return "continue"

    # Should not reach here, but be defensive.
    ad["_enrichment_status"] = "exhausted_retries"
    ad["_enrichment_cached"] = False
    return "continue"


# ── Summary ────────────────────────────────────────────────────────────────


def build_summary(
    run_ts_iso: str,
    ads: list,
    counters: dict,
    credits_used: int,
    credits_remaining_after,
    input_count: int,
    halted_on_auth: bool,
) -> str:
    lines = []
    lines.append("# AdLibrary Phase C — Enrichment Pass")
    lines.append("")

    lines.append("## a. Run Metadata")
    lines.append("")
    lines.append(f"- **Timestamp (UTC):** {run_ts_iso}")
    lines.append(f"- **Script version:** {SCRIPT_VERSION}")
    lines.append(f"- **Input ad count:** {input_count}")
    lines.append(f"- **Ads processed:** {sum(counters.values())}")
    lines.append(f"- **Throttle:** {THROTTLE_MS}ms between calls")
    lines.append(f"- **Halted early on auth fatal:** {halted_on_auth}")
    lines.append(f"- **Credits used:** {credits_used}")
    lines.append(f"- **Credits remaining after:** {credits_remaining_after}")
    lines.append("")

    # Outcome counts
    lines.append("## b. Outcome Counts")
    lines.append("")
    lines.append("| Outcome | Count |")
    lines.append("|---|---|")
    for k in (
        "ok", "cached", "rate_limited", "server_error",
        "network_error", "schema_mismatch", "no_ad_key", "other",
    ):
        lines.append(f"| {k} | {counters.get(k, 0)} |")
    lines.append("")

    # Per-tier success rate
    gold_ads = [a for a in ads if a.get("_tier") == "gold"]
    silver_ads = [a for a in ads if a.get("_tier") == "silver"]
    gold_ok = sum(1 for a in gold_ads if a.get("_enrichment_status") == "ok")
    silver_ok = sum(1 for a in silver_ads if a.get("_enrichment_status") == "ok")
    lines.append("## c. Per-Tier Success Rate")
    lines.append("")
    lines.append("| Tier | Total | OK | Failed | Success % |")
    lines.append("|---|---|---|---|---|")
    if gold_ads:
        lines.append(
            f"| gold | {len(gold_ads)} | {gold_ok} | "
            f"{len(gold_ads) - gold_ok} | {100 * gold_ok / len(gold_ads):.1f}% |"
        )
    if silver_ads:
        lines.append(
            f"| silver | {len(silver_ads)} | {silver_ok} | "
            f"{len(silver_ads) - silver_ok} | {100 * silver_ok / len(silver_ads):.1f}% |"
        )
    lines.append("")

    # Sample preview — first gold ad's enrichment.summary
    ok_gold = [a for a in gold_ads if a.get("_enrichment_status") == "ok"]
    if ok_gold:
        first_gold = ok_gold[0]
        summary = (first_gold.get("enrichment") or {}).get("summary") or ""
        snippet = summary[:200].replace("\n", " ").strip()
        lines.append("## d. Sample Enrichment Preview")
        lines.append("")
        lines.append(f"_First gold-tier ad's `enrichment.summary` (first 200 chars):_")
        lines.append("")
        lines.append(f"> **{first_gold.get('advertiser_name', '?')}** — {snippet}…")
        lines.append("")
    else:
        lines.append("## d. Sample Enrichment Preview")
        lines.append("")
        lines.append("_(no successfully enriched gold ad available for preview)_")
        lines.append("")

    # Top 3 by heat — show ugc_script first 100 chars
    sorted_by_heat = sorted(
        [a for a in ads if a.get("_enrichment_status") == "ok"],
        key=lambda a: a.get("heat", 0) or 0,
        reverse=True,
    )
    lines.append("## e. Top 3 Enriched Ads by Heat (UGC-script preview)")
    lines.append("")
    if not sorted_by_heat:
        lines.append("_(none)_")
        lines.append("")
    else:
        for i, ad in enumerate(sorted_by_heat[:3], 1):
            adv = ad.get("advertiser_name", "?")
            heat = ad.get("heat", 0)
            tier = ad.get("_tier")
            ugc = (ad.get("enrichment") or {}).get("ugc_script") or ""
            snippet = ugc[:100].replace("\n", " ").strip()
            lines.append(
                f"**{i}. {adv}** _(tier={tier}, heat={heat})_  "
            )
            lines.append(f"   ugc_script: {snippet}…")
            lines.append("")

    # Phase D next step
    ok_total = counters.get("ok", 0) + counters.get("cached", 0)
    lines.append("## f. Next Step — Phase D")
    lines.append("")
    lines.append(
        f"Phase D (Excel writer) will produce a workbook of {ok_total} "
        "successfully-enriched ads. No further credits required."
    )
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("_Generated by `phase_c_enrich.py`._")
    lines.append("")
    return "\n".join(lines)


# ── Main ────────────────────────────────────────────────────────────────────


def write_checkpoint(
    ads: list, counters: dict, credits_used: int, credits_remaining,
    input_count: int, checkpoint: bool, token: str,
) -> None:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    doc = {
        "metadata": {
            "run_timestamp_utc": ts,
            "script_version": SCRIPT_VERSION,
            "input_ad_count": input_count,
            "checkpoint": checkpoint,
            "ok": counters.get("ok", 0),
            "cached": counters.get("cached", 0),
            "rate_limited": counters.get("rate_limited", 0),
            "server_error": counters.get("server_error", 0),
            "network_error": counters.get("network_error", 0),
            "schema_mismatch": counters.get("schema_mismatch", 0),
            "no_ad_key": counters.get("no_ad_key", 0),
            "other": counters.get("other", 0),
            "skipped": counters.get("no_ad_key", 0),
            "credits_used": credits_used,
            "credits_remaining_after": credits_remaining,
        },
        "ads": ads,
    }
    write_json(OUTPUT_PATH, doc, token)


def main(argv) -> int:
    if OUTPUT_PATH.exists():
        print(
            f"Phase C already run. Delete {OUTPUT_PATH.relative_to(SKILL_DIR)} "
            "or use --force."
        )
        return 4

    if not INPUT_PATH.exists():
        sys.stderr.write(f"ERROR: input not found at {INPUT_PATH}\n")
        return 3

    try:
        with INPUT_PATH.open("r", encoding="utf-8") as fh:
            phase_b_doc = json.load(fh)
    except (OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"ERROR: cannot read input {INPUT_PATH}: {e}\n")
        return 3

    ads = phase_b_doc.get("ads")
    if not isinstance(ads, list) or not ads:
        sys.stderr.write("ERROR: input has no 'ads' array or it is empty.\n")
        return 3

    input_count = len(ads)
    print(f"[init] loaded {input_count} ads from {INPUT_PATH.relative_to(SKILL_DIR)}")

    env_path = resolve_env_path()
    token = read_token(env_path)
    print(f"[init] token loaded from {env_path}")

    counters = {
        "ok": 0, "cached": 0, "rate_limited": 0, "server_error": 0,
        "network_error": 0, "schema_mismatch": 0, "no_ad_key": 0, "other": 0,
    }
    credits_used = 0
    credits_remaining_after = None
    halted_on_auth = False
    calls_made = 0

    for i, ad in enumerate(ads, 1):
        if calls_made >= MAX_CALLS_HARD_CAP:
            sys.stderr.write(f"FATAL: hard cap of {MAX_CALLS_HARD_CAP} calls hit.\n")
            break

        outcome = enrich_one(ad, i, input_count, token)
        calls_made += 1

        if outcome == "auth_fatal":
            halted_on_auth = True
            break

        if outcome == "no_key":
            counters["no_ad_key"] += 1
            continue

        st = ad.get("_enrichment_status", "")
        if st == "ok":
            counters["ok"] += 1
            if ad.get("_enrichment_cached"):
                counters["cached"] += 1
            cu = ad.get("_enrichment_credits_used", 0) or 0
            credits_used += cu
            bal = ad.get("_enrichment_balance_after")
            if bal is not None:
                credits_remaining_after = bal
        elif st == "rate_limited":
            counters["rate_limited"] += 1
        elif st.startswith("server_error"):
            counters["server_error"] += 1
        elif st == "network_error":
            counters["network_error"] += 1
        elif st == "schema_mismatch":
            counters["schema_mismatch"] += 1
        else:
            counters["other"] += 1

        # Checkpoint every CHECKPOINT_EVERY ads.
        if i % CHECKPOINT_EVERY == 0:
            write_checkpoint(
                ads, counters, credits_used, credits_remaining_after,
                input_count, checkpoint=True, token=token,
            )
            print(
                f"[checkpoint] wrote partial after {i} ads — "
                f"ok={counters['ok']} credits_used={credits_used}"
            )

        time.sleep(THROTTLE_MS / 1000.0)

    # Final write (checkpoint=False signals completion).
    write_checkpoint(
        ads, counters, credits_used, credits_remaining_after,
        input_count, checkpoint=False, token=token,
    )

    run_ts_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    summary = build_summary(
        run_ts_iso=run_ts_iso,
        ads=ads,
        counters=counters,
        credits_used=credits_used,
        credits_remaining_after=credits_remaining_after,
        input_count=input_count,
        halted_on_auth=halted_on_auth,
    )
    summary = redact_text(summary, token)
    SUMMARY_PATH.write_text(summary, encoding="utf-8")

    print(
        f"DONE. ok={counters['ok']} cached={counters['cached']} "
        f"credits_used={credits_used} credits_remaining={credits_remaining_after}"
    )

    if halted_on_auth:
        return 2

    failure_count = (
        counters["rate_limited"] + counters["server_error"] + counters["network_error"]
        + counters["schema_mismatch"] + counters["other"]
    )
    if failure_count > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
