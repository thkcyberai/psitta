#!/usr/bin/env python3
"""Phase B search-and-classify pass for the psitta-ad-search skill.

Iterates a fixed list of 12 keywords across three intent buckets, calls
AdLibrary's /api/search once per keyword (1 credit each, 12 total budget),
classifies every returned ad into gold/silver/dropped via multi-signal
AND/OR thresholds, deduplicates by ad_key while preserving cross-keyword
provenance, and writes:

  - samples/phase_b_raw/<safe_keyword>.json   per-keyword raw response
  - samples/phase_b_results.json              dedup'd gold + silver ads
  - PHASE_B_SUMMARY.md                        operator-facing report

Phase C will consume this output by calling /api/enrichment on each kept
ad (1 credit per call). This script never calls /api/enrichment.

Stdlib only. Token is read from .env and never written to disk or logs.
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
# helpers module once a third script enters the skill. Duplicated from
# discovery.py for now.

SCRIPT_VERSION = "1.0"
SEARCH_URL = "https://adlibrary.com/api/search"

SCRIPT_PATH = Path(__file__).resolve()
SCRIPTS_DIR = SCRIPT_PATH.parent
SKILL_DIR = SCRIPTS_DIR.parent
SAMPLES_DIR = SKILL_DIR / "samples"
RAW_DIR = SAMPLES_DIR / "phase_b_raw"
RESULTS_FILE = SAMPLES_DIR / "phase_b_results.json"
SUMMARY_DOC = SKILL_DIR / "PHASE_B_SUMMARY.md"

APP_TYPE = "2"  # TODO: revisit when AdLibrary support clarifies appType=2 vs 3 taxonomy
GEO = ["USA"]
DAYS_BACK = 180  # search-freshness window; distinct from days_count (per-ad runtime)
PAGE_SIZE = 50

TIER_GOLD_DAYS = 30
TIER_GOLD_HEAT_MIN = 100
TIER_GOLD_IMPRESSION_MIN = 50000
TIER_GOLD_SPEND_MIN = 300

TIER_SILVER_DAYS = 14
TIER_SILVER_HEAT_MIN = 30
TIER_SILVER_IMPRESSION_MIN = 5000
TIER_SILVER_SPEND_MIN = 50

USER_AGENT = "psitta-ad-search-phase-b/1.0 (+https://psitta.ai)"

MAX_CALLS = 12  # hard budget cap; halts before a 13th call

SEARCH_KEYWORDS = [
    # Direct functional analogs (TTS / audio-first content consumption)
    {"keyword": "speechify",        "bucket": "direct_analog"},
    {"keyword": "audible",          "bucket": "direct_analog"},
    {"keyword": "blinkist",         "bucket": "direct_analog"},
    {"keyword": "headway",          "bucket": "direct_analog"},
    {"keyword": "shortform",        "bucket": "direct_analog"},
    {"keyword": "text to speech",   "bucket": "direct_analog"},
    # Audience overlap (writers, editors, knowledge workers)
    {"keyword": "grammarly",        "bucket": "audience_overlap"},
    {"keyword": "ai writing",       "bucket": "audience_overlap"},
    {"keyword": "writing app",      "bucket": "audience_overlap"},
    # Pattern source (productivity / AI tools — proven creative templates)
    {"keyword": "notion",           "bucket": "pattern_source"},
    {"keyword": "productivity app", "bucket": "pattern_source"},
    {"keyword": "ai tool",          "bucket": "pattern_source"},
]

ADL_TOKEN_RE = re.compile(r"adl_[A-Za-z0-9_\-]+")


# ── Token loading ──────────────────────────────────────────────────────────


def resolve_env_path() -> Path:
    """Locate the project .env file across Git-Bash and Windows path styles."""
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
    """Manual line-by-line parser for ADLIBRARY_API_KEY=... in .env."""
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
                    sys.exit(1)
                return value
    except FileNotFoundError:
        sys.stderr.write(f"ERROR: .env not found at {env_path}\n")
        sys.exit(1)
    sys.stderr.write("ERROR: ADLIBRARY_API_KEY line not found in .env\n")
    sys.exit(1)


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
    except urllib.error.URLError as e:
        sys.stderr.write(f"ERROR: network failure calling {url}: {e.reason}\n")
        sys.exit(2)


# ── Classification ─────────────────────────────────────────────────────────


def classify_tier(ad: dict) -> str:
    """Return 'gold', 'silver', or 'dropped' per the multi-signal AND/OR rules."""
    days_count = ad.get("days_count", 0) or 0
    heat = ad.get("heat", 0) or 0
    impression = ad.get("impression", 0) or 0
    spend = ad.get("estimated_spend", 0) or 0

    if days_count >= TIER_GOLD_DAYS and (
        heat >= TIER_GOLD_HEAT_MIN
        or impression >= TIER_GOLD_IMPRESSION_MIN
        or spend >= TIER_GOLD_SPEND_MIN
    ):
        return "gold"
    if days_count >= TIER_SILVER_DAYS and (
        heat >= TIER_SILVER_HEAT_MIN
        or impression >= TIER_SILVER_IMPRESSION_MIN
        or spend >= TIER_SILVER_SPEND_MIN
    ):
        return "silver"
    return "dropped"


def safe_filename(keyword: str) -> str:
    return keyword.lower().replace(" ", "_")


# ── Per-keyword stats ───────────────────────────────────────────────────────


def empty_keyword_stat(entry: dict) -> dict:
    return {
        "keyword": entry["keyword"],
        "bucket": entry["bucket"],
        "total_returned": 0,
        "gold": 0,
        "silver": 0,
        "dropped": 0,
        "status": "pending",   # pending / ok / http_<code> / no_results_array
        "credits_used": 0,
        "credits_remaining": None,
    }


# ── Summary doc ─────────────────────────────────────────────────────────────


def build_summary(
    run_ts_iso: str,
    keyword_stats: list,
    accumulator: dict,
    overlap_map: dict,
    credits_used_total: int,
    credits_remaining_after: int | None,
) -> str:
    lines = []
    lines.append("# AdLibrary Phase B — Search + Tier Classification")
    lines.append("")

    # Metadata
    keywords_ok = sum(1 for s in keyword_stats if s["status"] == "ok")
    keywords_failed = sum(1 for s in keyword_stats if s["status"] not in ("ok", "pending"))
    lines.append("## a. Run Metadata")
    lines.append("")
    lines.append(f"- **Timestamp (UTC):** {run_ts_iso}")
    lines.append(f"- **Script version:** {SCRIPT_VERSION}")
    lines.append(f"- **Keywords searched:** {len(keyword_stats)}")
    lines.append(f"- **Keywords succeeded:** {keywords_ok}")
    lines.append(f"- **Keywords failed/skipped:** {keywords_failed}")
    lines.append(f"- **Credits used (this run):** {credits_used_total}")
    lines.append(f"- **Credits remaining after:** {credits_remaining_after}")
    lines.append(f"- **App type:** `{APP_TYPE}`")
    lines.append(f"- **Geo:** `{GEO}`")
    lines.append(f"- **Days back:** `{DAYS_BACK}`")
    lines.append(f"- **Page size:** `{PAGE_SIZE}`")
    lines.append("")

    # Tier thresholds
    lines.append("## b. Tier Thresholds")
    lines.append("")
    lines.append("| Tier | days_count >= | AND any of (heat / impression / estimated_spend) |")
    lines.append("|---|---|---|")
    lines.append(
        f"| gold | {TIER_GOLD_DAYS} | "
        f"heat >= {TIER_GOLD_HEAT_MIN} OR impression >= {TIER_GOLD_IMPRESSION_MIN} "
        f"OR estimated_spend >= {TIER_GOLD_SPEND_MIN} |"
    )
    lines.append(
        f"| silver | {TIER_SILVER_DAYS} | "
        f"heat >= {TIER_SILVER_HEAT_MIN} OR impression >= {TIER_SILVER_IMPRESSION_MIN} "
        f"OR estimated_spend >= {TIER_SILVER_SPEND_MIN} |"
    )
    lines.append("")

    # Per-keyword table
    lines.append("## c. Per-Keyword Results")
    lines.append("")
    lines.append("| # | Keyword | Bucket | Returned | Gold | Silver | Dropped | Status |")
    lines.append("|---|---|---|---|---|---|---|---|")
    for i, s in enumerate(keyword_stats, 1):
        lines.append(
            f"| {i} | `{s['keyword']}` | {s['bucket']} | "
            f"{s['total_returned']} | {s['gold']} | {s['silver']} | {s['dropped']} | "
            f"{s['status']} |"
        )
    lines.append("")

    # Per-bucket aggregates
    lines.append("## d. Per-Bucket Aggregates")
    lines.append("")
    buckets = {}
    for s in keyword_stats:
        b = buckets.setdefault(s["bucket"], {"returned": 0, "gold": 0, "silver": 0, "dropped": 0})
        b["returned"] += s["total_returned"]
        b["gold"] += s["gold"]
        b["silver"] += s["silver"]
        b["dropped"] += s["dropped"]
    lines.append("| Bucket | Returned | Gold | Silver | Dropped |")
    lines.append("|---|---|---|---|---|")
    for bname, b in buckets.items():
        lines.append(f"| {bname} | {b['returned']} | {b['gold']} | {b['silver']} | {b['dropped']} |")
    lines.append("")

    # Cross-keyword overlap
    lines.append("## e. Cross-Keyword Overlap")
    lines.append("")
    multi_kw_ads = [ad for ad in accumulator.values() if len(ad.get("_source_keywords", [])) > 1]
    lines.append(f"- **Unique ads (gold + silver, post-dedup):** {len(accumulator)}")
    lines.append(f"- **Ads surfacing in 2+ keywords:** {len(multi_kw_ads)}")
    if multi_kw_ads:
        lines.append("")
        lines.append("| Advertiser | Heat | Tier | Source keywords |")
        lines.append("|---|---|---|---|")
        # sort by heat desc, top 10
        multi_kw_ads.sort(key=lambda a: a.get("heat", 0) or 0, reverse=True)
        for ad in multi_kw_ads[:10]:
            kws = ", ".join(ad.get("_source_keywords", []))
            lines.append(
                f"| {ad.get('advertiser_name', '?')[:40]} | "
                f"{ad.get('heat', 0)} | {ad.get('_tier')} | {kws} |"
            )
    lines.append("")

    # Top gold + silver previews
    all_ads = list(accumulator.values())
    gold_ads = sorted(
        [a for a in all_ads if a["_tier"] == "gold"],
        key=lambda a: a.get("heat", 0) or 0,
        reverse=True,
    )
    silver_ads = sorted(
        [a for a in all_ads if a["_tier"] == "silver"],
        key=lambda a: a.get("heat", 0) or 0,
        reverse=True,
    )

    def preview_table(ads, header):
        out = []
        out.append(f"## {header}")
        out.append("")
        if not ads:
            out.append("_(none)_")
            out.append("")
            return out
        out.append("| Advertiser | Days | Heat | Impression | Spend | Keyword |")
        out.append("|---|---|---|---|---|---|")
        for ad in ads[:5]:
            out.append(
                f"| {ad.get('advertiser_name', '?')[:40]} | "
                f"{ad.get('days_count', 0)} | {ad.get('heat', 0)} | "
                f"{ad.get('impression', 0)} | {ad.get('estimated_spend', 0)} | "
                f"`{ad.get('_source_keyword')}` |"
            )
        out.append("")
        return out

    lines.extend(preview_table(gold_ads, "f. Top 5 Gold (by heat)"))
    lines.extend(preview_table(silver_ads, "g. Top 5 Silver (by heat)"))

    # Phase C cost projection
    phase_c_cost = len(accumulator)
    remaining_after_c = (
        credits_remaining_after - phase_c_cost if credits_remaining_after is not None else None
    )
    lines.append("## h. Phase C Cost Projection")
    lines.append("")
    lines.append(
        f"Phase C will enrich {phase_c_cost} ads (gold + silver) at 1 credit each "
        f"= {phase_c_cost} credits. Remaining after = "
        f"{remaining_after_c if remaining_after_c is not None else 'unknown'}."
    )
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append(
        "_Generated by `phase_b_search.py` — 12 search calls consumed; "
        "no enrichment calls made._"
    )
    lines.append("")
    return "\n".join(lines)


# ── Main ────────────────────────────────────────────────────────────────────


def main(argv) -> int:
    if RESULTS_FILE.exists():
        print(
            "Phase B already run. Delete samples/phase_b_results.json + "
            "samples/phase_b_raw/ or use --force."
        )
        return 4

    SAMPLES_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    env_path = resolve_env_path()
    token = read_token(env_path)
    print(f"[init] token loaded from {env_path}")

    keyword_stats = [empty_keyword_stat(e) for e in SEARCH_KEYWORDS]
    accumulator: dict = {}            # ad_key -> ad
    overlap_map: dict = {}            # ad_key -> [keywords]
    credits_used_total = 0
    credits_remaining_after: int | None = None
    fatal_auth = False
    any_failure = False
    schema_mismatch = False

    for i, (entry, stats) in enumerate(zip(SEARCH_KEYWORDS, keyword_stats), 1):
        if i > MAX_CALLS:
            sys.stderr.write(f"FATAL: budget cap hit ({MAX_CALLS} calls); halting.\n")
            break

        keyword = entry["keyword"]
        bucket = entry["bucket"]
        print(f"[{i}/{len(SEARCH_KEYWORDS)}] keyword={keyword} bucket={bucket}")

        payload = {
            "keyword": keyword,
            "appType": APP_TYPE,
            "geo": GEO,
            "daysBack": DAYS_BACK,
            "pageSize": PAGE_SIZE,
        }
        status, _headers, raw = http_post_json(SEARCH_URL, payload, token)

        if status in (401, 403):
            masked = redact_text(raw[:300], token)
            sys.stderr.write(
                f"FATAL: HTTP {status} from /api/search on keyword='{keyword}'. "
                f"Body excerpt (masked): {masked}\n"
            )
            stats["status"] = f"http_{status}"
            fatal_auth = True
            break

        if status == 429:
            stats["status"] = "http_429"
            any_failure = True
            sys.stderr.write(f"WARN: HTTP 429 on keyword='{keyword}' after retry; skipping.\n")
            continue

        if status >= 500:
            masked = redact_text(raw[:300], token)
            stats["status"] = f"http_{status}"
            any_failure = True
            sys.stderr.write(
                f"WARN: HTTP {status} on keyword='{keyword}'. "
                f"Body excerpt (masked): {masked}\n"
            )
            continue

        if status != 200:
            masked = redact_text(raw[:300], token)
            stats["status"] = f"http_{status}"
            any_failure = True
            sys.stderr.write(
                f"WARN: HTTP {status} on keyword='{keyword}'. "
                f"Body excerpt (masked): {masked}\n"
            )
            continue

        try:
            obj = json.loads(raw)
        except json.JSONDecodeError as e:
            stats["status"] = "bad_json"
            any_failure = True
            sys.stderr.write(f"WARN: bad JSON on keyword='{keyword}': {e}\n")
            continue

        raw_path = RAW_DIR / f"{safe_filename(keyword)}.json"
        write_json(raw_path, obj, token)

        results = obj.get("results") if isinstance(obj, dict) else None
        if not isinstance(results, list):
            stats["status"] = "no_results_array"
            schema_mismatch = True
            sys.stderr.write(
                f"WARN: keyword='{keyword}' response has no 'results' array (schema mismatch). "
                f"Raw saved to {raw_path.relative_to(SKILL_DIR)}.\n"
            )
            continue

        credits = obj.get("_credits") if isinstance(obj, dict) else None
        if isinstance(credits, dict):
            stats["credits_used"] = credits.get("used") or 0
            stats["credits_remaining"] = credits.get("remaining")
            credits_used_total += stats["credits_used"] or 0
            if stats["credits_remaining"] is not None:
                credits_remaining_after = stats["credits_remaining"]

        stats["total_returned"] = len(results)
        stats["status"] = "ok"

        for ad in results:
            if not isinstance(ad, dict):
                continue
            tier = classify_tier(ad)
            if tier == "gold":
                stats["gold"] += 1
            elif tier == "silver":
                stats["silver"] += 1
            else:
                stats["dropped"] += 1
                continue

            ad_key = ad.get("ad_key")
            if not ad_key:
                continue

            if ad_key in accumulator:
                existing = accumulator[ad_key]
                if keyword not in existing.setdefault("_source_keywords", []):
                    existing["_source_keywords"].append(keyword)
                if bucket not in existing.setdefault("_source_buckets", []):
                    existing["_source_buckets"].append(bucket)
            else:
                ad["_tier"] = tier
                ad["_source_keyword"] = keyword
                ad["_source_keywords"] = [keyword]
                ad["_source_bucket"] = bucket
                ad["_source_buckets"] = [bucket]
                accumulator[ad_key] = ad

    run_ts_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    keywords_ok = sum(1 for s in keyword_stats if s["status"] == "ok")
    keywords_failed = sum(1 for s in keyword_stats if s["status"] not in ("ok", "pending"))

    results_doc = {
        "metadata": {
            "run_timestamp_utc": run_ts_iso,
            "script_version": SCRIPT_VERSION,
            "keywords_searched": len(SEARCH_KEYWORDS),
            "keywords_succeeded": keywords_ok,
            "keywords_failed": keywords_failed,
            "credits_used": credits_used_total,
            "credits_remaining_after": credits_remaining_after,
            "tier_thresholds": {
                "gold": {
                    "days_count_min": TIER_GOLD_DAYS,
                    "heat_min": TIER_GOLD_HEAT_MIN,
                    "impression_min": TIER_GOLD_IMPRESSION_MIN,
                    "estimated_spend_min": TIER_GOLD_SPEND_MIN,
                },
                "silver": {
                    "days_count_min": TIER_SILVER_DAYS,
                    "heat_min": TIER_SILVER_HEAT_MIN,
                    "impression_min": TIER_SILVER_IMPRESSION_MIN,
                    "estimated_spend_min": TIER_SILVER_SPEND_MIN,
                },
            },
        },
        "ads": list(accumulator.values()),
    }
    write_json(RESULTS_FILE, results_doc, token)

    summary = build_summary(
        run_ts_iso=run_ts_iso,
        keyword_stats=keyword_stats,
        accumulator=accumulator,
        overlap_map=overlap_map,
        credits_used_total=credits_used_total,
        credits_remaining_after=credits_remaining_after,
    )
    summary = redact_text(summary, token)
    SUMMARY_DOC.write_text(summary, encoding="utf-8")

    print(
        f"DONE. ads_kept={len(accumulator)} credits_used={credits_used_total} "
        f"credits_remaining={credits_remaining_after}"
    )

    if fatal_auth:
        return 2
    if schema_mismatch:
        return 3
    if any_failure:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
