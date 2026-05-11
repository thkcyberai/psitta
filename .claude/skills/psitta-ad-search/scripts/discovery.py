#!/usr/bin/env python3
"""Phase A discovery script for AdLibrary.com API integration.

Calls /api/search exactly once and /api/enrichment exactly once, captures
both raw responses to JSON files, and generates a markdown spec resolving
three documented schema gaps. Stdlib only. Token never written to disk.

Usage:
    python discovery.py            # first run; aborts if samples already exist
    python discovery.py --force    # re-run (consumes 2 more credits)
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_VERSION = "1.0"
SEARCH_URL = "https://adlibrary.com/api/search"
ENRICHMENT_URL = "https://adlibrary.com/api/enrichment"

SCRIPT_PATH = Path(__file__).resolve()
SCRIPTS_DIR = SCRIPT_PATH.parent
SKILL_DIR = SCRIPTS_DIR.parent
SAMPLES_DIR = SKILL_DIR / "samples"
SEARCH_SAMPLE = SAMPLES_DIR / "search_response.json"
ENRICHMENT_SAMPLE = SAMPLES_DIR / "enrichment_response.json"
DISCOVERY_DOC = SKILL_DIR / "API_DISCOVERY.md"

SEARCH_PAYLOAD = {
    "keyword": "speechify",
    "appType": "2",
    "geo": ["USA"],
    "daysBack": 7,
    "pageSize": 10,
}

ADL_TOKEN_RE = re.compile(r"adl_[A-Za-z0-9_\-]+")


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
    return Path("/c/products/psitta/.env")  # falls through to FileNotFoundError below


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


def redact_text(text: str, token: str) -> str:
    """Replace literal token and any adl_-prefixed string with [REDACTED]."""
    if not isinstance(text, str):
        return text
    out = text
    if token and token in out:
        out = out.replace(token, "[REDACTED]")
    out = ADL_TOKEN_RE.sub("[REDACTED]", out)
    return out


def redact_obj(obj, token: str):
    """Recursively redact strings inside a JSON-decoded object."""
    if isinstance(obj, dict):
        return {k: redact_obj(v, token) for k, v in obj.items()}
    if isinstance(obj, list):
        return [redact_obj(v, token) for v in obj]
    if isinstance(obj, str):
        return redact_text(obj, token)
    return obj


def http_post_json(url: str, payload: dict, token: str, allow_429_retry: bool = True):
    """POST JSON with Bearer auth; honor a single 429 Retry-After if present."""
    body_bytes = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body_bytes,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "psitta-ad-search-discovery/1.0",
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
        except Exception:  # noqa: BLE001 - urllib raises non-standard error variants on read
            err_body = ""
        return e.code, headers, err_body
    except urllib.error.URLError as e:
        sys.stderr.write(f"ERROR: network failure calling {url}: {e.reason}\n")
        sys.exit(2)


def write_json(path: Path, obj, token: str) -> None:
    """Write a JSON file with the token-redaction sweep."""
    redacted = redact_obj(obj, token)
    text = json.dumps(redacted, indent=2, ensure_ascii=False)
    text = redact_text(text, token)
    path.write_text(text, encoding="utf-8")


def extract_credits_from_search(search_obj) -> dict:
    credits = {}
    if isinstance(search_obj, dict):
        c = search_obj.get("_credits")
        if isinstance(c, dict):
            credits["used"] = c.get("used")
            credits["remaining"] = c.get("remaining")
    return credits


def schema_of(value):
    """Return a short type label for a JSON-decoded value."""
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "int"
    if isinstance(value, float):
        return "float"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        if not value:
            return "array (empty)"
        return f"array<{schema_of(value[0])}>"
    if isinstance(value, dict):
        return "object"
    return type(value).__name__


def example_of(value, token: str, max_len: int = 80) -> str:
    """One-line example value for a schema row."""
    if isinstance(value, (dict, list)):
        s = json.dumps(value, ensure_ascii=False)
    else:
        s = json.dumps(value, ensure_ascii=False) if not isinstance(value, str) else value
    s = redact_text(s, token)
    s = s.replace("\n", " ").replace("\r", " ").replace("|", "\\|")
    if len(s) > max_len:
        s = s[: max_len - 1] + "…"
    return s


def schema_rows(obj, token: str):
    """Build [(field, type, example)] rows for every key of an object."""
    rows = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            rows.append((k, schema_of(v), example_of(v, token)))
    return rows


def find_format_field(item: dict):
    """GAP 1: search for a field plausibly indicating ad format."""
    if not isinstance(item, dict):
        return None
    candidates = (
        "format", "ad_format", "media_type", "mediaType",
        "creative_type", "creativeType", "ad_type", "adType",
        "type", "asset_type", "assetType",
    )
    for c in candidates:
        if c in item:
            return c, item[c]
    return None


def find_landing_field(item: dict):
    """GAP 2: search for a landing-page URL field."""
    if not isinstance(item, dict):
        return None
    candidates = (
        "landing_page_url", "landingPageUrl", "landing_url", "landingUrl",
        "destination_url", "destinationUrl", "click_url", "clickUrl",
        "url", "target_url", "targetUrl",
    )
    for c in candidates:
        if c in item and isinstance(item[c], str) and item[c]:
            return c, item[c]
    return None


def find_cta_field(item: dict):
    """GAP 3: search for a CTA field."""
    if not isinstance(item, dict):
        return None
    candidates = (
        "cta", "call_to_action", "callToAction", "cta_text", "ctaText",
        "cta_label", "ctaLabel", "button_text", "buttonText",
    )
    for c in candidates:
        if c in item:
            return c, item[c]
    return None


def build_doc(
    timestamp_iso: str,
    search_payload: dict,
    search_obj,
    search_headers: dict,
    enrichment_payload: dict,
    enrichment_obj,
    enrichment_headers: dict,
    token: str,
) -> str:
    lines = []
    lines.append("# AdLibrary.com API Discovery — Phase A")
    lines.append("")
    lines.append("## a. Run Metadata")
    lines.append("")
    lines.append(f"- **Timestamp (UTC, ISO 8601):** {timestamp_iso}")
    lines.append(f"- **Script version:** {SCRIPT_VERSION}")
    lines.append(f"- **Search endpoint:** `POST {SEARCH_URL}`")
    lines.append(f"- **Enrichment endpoint:** `POST {ENRICHMENT_URL}`")
    lines.append(f"- **Search keyword:** `{search_payload.get('keyword')}`")
    lines.append("")

    lines.append("## b. Search Request Payload")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(search_payload, indent=2, ensure_ascii=False))
    lines.append("```")
    lines.append("")

    lines.append("## c. Search Response Schema")
    lines.append("")
    if isinstance(search_obj, dict):
        lines.append("### Top-level fields")
        lines.append("")
        lines.append("| Field | Type | Example |")
        lines.append("|---|---|---|")
        for k, t, ex in schema_rows(search_obj, token):
            lines.append(f"| `{k}` | {t} | `{ex}` |")
        lines.append("")
        lst = search_obj.get("results")
        if isinstance(lst, list) and lst and isinstance(lst[0], dict):
            lines.append("### `results[0]` fields (first ad)")
            lines.append("")
            lines.append("| Field | Type | Example |")
            lines.append("|---|---|---|")
            for k, t, ex in schema_rows(lst[0], token):
                lines.append(f"| `{k}` | {t} | `{ex}` |")
        else:
            lines.append("> `results` is missing, empty, or malformed.")
        lines.append("")
    else:
        lines.append("> Search response is not a JSON object; raw shape preserved in `samples/search_response.json`.")
        lines.append("")

    lines.append("## d. Enrichment Request Payload")
    lines.append("")
    lines.append("```json")
    lines.append(json.dumps(enrichment_payload, indent=2, ensure_ascii=False))
    lines.append("```")
    lines.append("")

    lines.append("## e. Enrichment Response Schema")
    lines.append("")
    if isinstance(enrichment_obj, dict):
        lines.append("| Field | Type | Example |")
        lines.append("|---|---|---|")
        for k, t, ex in schema_rows(enrichment_obj, token):
            lines.append(f"| `{k}` | {t} | `{ex}` |")
    elif isinstance(enrichment_obj, list):
        lines.append("> Enrichment response is a top-level array; first element schema below.")
        lines.append("")
        if enrichment_obj and isinstance(enrichment_obj[0], dict):
            lines.append("| Field | Type | Example |")
            lines.append("|---|---|---|")
            for k, t, ex in schema_rows(enrichment_obj[0], token):
                lines.append(f"| `{k}` | {t} | `{ex}` |")
    else:
        lines.append("> Enrichment response is not a JSON object; raw shape preserved in `samples/enrichment_response.json`.")
    lines.append("")

    # GAP RESOLUTIONS
    first_ad = {}
    if isinstance(search_obj, dict):
        lst = search_obj.get("results")
        if isinstance(lst, list) and lst and isinstance(lst[0], dict):
            first_ad = lst[0]

    lines.append("## f. Schema-Gap Resolutions")
    lines.append("")

    # GAP 1
    fmt = find_format_field(first_ad)
    lines.append("GAP 1: Does search `response.list[i]` include a field indicating ad format (video / image / carousel)?")
    lines.append("")
    if fmt is not None:
        fname, fval = fmt
        lines.append(f"**PASS** — Field `{fname}` present in `list[0]`. Example value: `{example_of(fval, token)}`.")
    else:
        lines.append("**FAIL** — No format-indicating field found in `list[0]`.")
        lines.append("")
        lines.append("Recommended derivation strategy: at Phase B, derive ad format from enrichment URL fields. "
                     "Inspect the enrichment response: presence of `video_url` (or any field ending in `video`) → format=`video`; "
                     "absence of video URL but presence of `image_url`/`preview_img_url` → format=`image`; "
                     "presence of an array of media items (e.g. `assets`/`carousel_cards` with length > 1) → format=`carousel`. "
                     "This costs 1 enrichment credit per ad to determine format.")
    lines.append("")

    # GAP 2
    landing = find_landing_field(first_ad)
    lines.append("GAP 2: Does search `response.list[i]` include `landing_page_url`?")
    lines.append("")
    if landing is not None:
        lname, lval = landing
        lines.append(f"**PASS** — Field `{lname}` present in `list[0]`. Example: `{example_of(lval, token)}`.")
    else:
        lines.append("**FAIL** — No landing/destination URL field found in `list[0]`.")
        lines.append("")
        lines.append("Implication: the enrichment endpoint's input schema accepts ad fields including (per docs) `landing_page_url`, "
                     "but search does not provide it. Phase B options: (a) supply landing_page_url externally if a downstream caller has it, "
                     "(b) omit the field from the enrichment payload and rely on the API's tolerance of its absence, "
                     "(c) parse the landing URL out of the enrichment response after the call (round-trip is required regardless).")
    lines.append("")

    # GAP 3
    cta = find_cta_field(first_ad)
    lines.append("GAP 3: Does search `response.list[i]` include any field representing call-to-action (CTA)?")
    lines.append("")
    if cta is not None:
        cname, cval = cta
        lines.append(f"**PASS** — Field `{cname}` present in `list[0]`. Example: `{example_of(cval, token)}`.")
    else:
        lines.append("**FAIL** — No CTA-indicating field found in `list[0]`.")
        lines.append("")
        lines.append("Recommendation: drop the CTA column from the Phase B Excel output, or populate it only from enrichment "
                     "if a CTA field surfaces there. Either way, the Excel writer must tolerate `None` rather than asserting a value.")
    lines.append("")

    # CREDITS
    sc = extract_credits_from_search(search_obj)
    used = sc.get("used")
    remaining_after_search = sc.get("remaining")
    enrichment_balance = None
    if isinstance(enrichment_obj, dict):
        enrichment_balance = enrichment_obj.get("balance")
    final_remaining = enrichment_balance if enrichment_balance is not None else remaining_after_search

    lines.append("## g. Credit Consumption")
    lines.append("")
    lines.append(f"Search consumed: 1; Enrichment consumed: 1; Remaining credits after both calls: {final_remaining}.")
    lines.append("")
    lines.append(f"- Search response `_credits.used`: `{used}`")
    lines.append(f"- Search response `_credits.remaining`: `{remaining_after_search}`")
    lines.append(f"- Enrichment response `balance`: `{enrichment_balance}`")
    lines.append("")

    # RATE LIMIT HEADERS
    lines.append("## h. Rate-Limit Headers Observed")
    lines.append("")
    rl_pat = re.compile(r"^(X-RateLimit-.*|Retry-After)$", re.IGNORECASE)
    seen = []
    for src_name, hdrs in (("search", search_headers), ("enrichment", enrichment_headers)):
        if not isinstance(hdrs, dict):
            continue
        for hk, hv in hdrs.items():
            if rl_pat.match(hk):
                seen.append((src_name, hk, redact_text(str(hv), token)))
    if seen:
        lines.append("| Source | Header | Value |")
        lines.append("|---|---|---|")
        for src, hk, hv in seen:
            lines.append(f"| {src} | `{hk}` | `{hv}` |")
    else:
        lines.append("None observed.")
    lines.append("")

    # PHASE B IMPLICATIONS
    lines.append("## i. Phase B Design Implications")
    lines.append("")
    bullets = []
    if fmt is None:
        bullets.append("Ad format is not present in search results; Phase B must derive it from enrichment URL fields, "
                       "which means every row in the Excel output requires an enrichment credit (no shortcut for image-only filtering).")
    else:
        bullets.append(f"Ad format is exposed directly via `{fmt[0]}` in search results, enabling pre-filtering before "
                       "enrichment (saves credits when caller wants only one format).")
    if landing is None:
        bullets.append("Landing page URL is absent from search results; the Phase B enrichment payload must omit `landing_page_url` "
                       "or supply it externally. The skill should not fabricate a value.")
    else:
        bullets.append(f"Landing page URL is present in search results via `{landing[0]}`, so the enrichment payload can be constructed "
                       "without an external lookup.")
    if cta is None:
        bullets.append("CTA is not on the search response; the Phase B Excel writer should drop the CTA column entirely "
                       "or fall back to the enrichment response if a CTA field is found there.")
    else:
        bullets.append(f"CTA is present via `{cta[0]}` in search results; Excel column populates directly without enrichment.")
    bullets.append("Token never appears in stdout, log, or saved files — discovery script's redaction sweep "
                   "(`adl_*` regex + literal token replace) is the canonical pattern for the Phase B production skill.")
    bullets.append("Re-run safety must persist into Phase B: any production CLI that consumes paid credits should require an explicit "
                   "`--force` flag to overwrite cached results.")
    if final_remaining is None:
        bullets.append("Credit balance is not reliably surfaced via the documented `_credits`/`balance` fields in this run; "
                       "Phase B should treat balance reporting as best-effort and not fail when absent.")
    for b in bullets:
        lines.append(f"- {b}")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("_Generated by `discovery.py` — Phase A is read-only and consumes 2 API credits._")
    lines.append("")

    return "\n".join(lines)


def main(argv) -> int:
    force = "--force" in argv[1:]

    samples_exist = SEARCH_SAMPLE.exists() or ENRICHMENT_SAMPLE.exists()
    if samples_exist and not force:
        print("Discovery already run. Use --force to re-run (will consume 2 more credits).")
        return 0

    SAMPLES_DIR.mkdir(parents=True, exist_ok=True)

    print("[1/4] Reading ADLIBRARY_API_KEY from .env")
    env_path = resolve_env_path()
    token = read_token(env_path)

    print("[2/4] Calling /api/search (1 credit)")
    s_status, s_headers, s_raw = http_post_json(SEARCH_URL, SEARCH_PAYLOAD, token)
    if s_status != 200:
        masked = redact_text(s_raw[:500], token)
        sys.stderr.write(f"ERROR: search returned HTTP {s_status}.\nResponse body (masked, first 500 chars):\n{masked}\n")
        return 3
    try:
        search_obj = json.loads(s_raw)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"ERROR: search response is not valid JSON: {e}\n")
        return 4

    # Persist raw response BEFORE any shape validation so failed runs still
    # leave a credit-funded sample on disk for diagnostic inspection.
    write_json(SEARCH_SAMPLE, search_obj, token)

    lst = None
    if isinstance(search_obj, dict):
        lst = search_obj.get("results")
    if not isinstance(lst, list) or not lst:  # API array key is "results", not "list"
        sys.stderr.write(
            f"No ads returned for keyword '{SEARCH_PAYLOAD['keyword']}' — "
            f"search sample captured to {SEARCH_SAMPLE.relative_to(SKILL_DIR)} "
            "for shape inspection. Exiting without calling enrichment.\n"
        )
        return 1

    first_ad = lst[0] if isinstance(lst[0], dict) else {}
    enrichment_ad = {
        "ad_key": first_ad.get("ad_key"),
        "platform": first_ad.get("platform"),
    }
    for opt in ("advertiser_name", "body", "preview_img_url"):
        if opt in first_ad:
            enrichment_ad[opt] = first_ad[opt]
    enrichment_payload = {"ad": enrichment_ad}

    print("[3/4] Calling /api/enrichment (1 credit)")
    e_status, e_headers, e_raw = http_post_json(ENRICHMENT_URL, enrichment_payload, token)
    enrichment_obj = None
    enrichment_failed = False
    if e_status != 200:
        enrichment_failed = True
        masked = redact_text(e_raw[:500], token)
        sys.stderr.write(f"ERROR: enrichment returned HTTP {e_status}.\nResponse body (masked, first 500 chars):\n{masked}\n")
    else:
        try:
            enrichment_obj = json.loads(e_raw)
        except json.JSONDecodeError as e:
            enrichment_failed = True
            sys.stderr.write(f"ERROR: enrichment response is not valid JSON: {e}\n")

    if not enrichment_failed:
        write_json(ENRICHMENT_SAMPLE, enrichment_obj, token)

    print("[4/4] Writing API_DISCOVERY.md")
    timestamp_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    doc = build_doc(
        timestamp_iso=timestamp_iso,
        search_payload=SEARCH_PAYLOAD,
        search_obj=search_obj,
        search_headers=s_headers,
        enrichment_payload=enrichment_payload,
        enrichment_obj=enrichment_obj if enrichment_obj is not None else {"_error": f"HTTP {e_status}"},
        enrichment_headers=e_headers,
        token=token,
    )
    doc = redact_text(doc, token)
    DISCOVERY_DOC.write_text(doc, encoding="utf-8")

    if enrichment_failed:
        sys.stderr.write("Enrichment failed — search sample saved; markdown spec still generated for review.\n")
        return 5

    print("DISCOVERY COMPLETE. Open .claude/skills/psitta-ad-search/API_DISCOVERY.md to review.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
