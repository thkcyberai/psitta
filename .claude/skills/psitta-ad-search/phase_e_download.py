#!/usr/bin/env python3
"""Phase E media downloader for the psitta-ad-search skill.

Downloads the actual media asset (video/image) for every gold+silver ad in
samples/phase_c_results.json into a local, gitignored downloads/ tree, so the
marketing agent has files that actually play.

WHY THIS EXISTS
---------------
AdLibrary's /api/media endpoint returns the COMPLETE asset on a successful
GET (ffmpeg decode-proven 2026-05-15: 144/144 frames, zero decode errors,
no mid-clip black). BUT it is served `Transfer-Encoding: chunked`, with no
`Content-Length`, and Range requests are ignored (200, not 206). Browser
inline <video> players require HTTP Range for progressive playback, so
clicking the media_url to watch it inline breaks at ~1s (video stalls /
black, audio continues). The file itself is intact -- it just has to be
DOWNLOADED and played from disk. This script does that.

ORDERING / CROSS-REFERENCE
--------------------------
Ads are processed in the SAME sort order as the Phase D Excel writer
(phase_d_excel.sort_ads): gold before silver, then heat descending, stable
for ties. The 4-digit zero-padded `seq` therefore maps 1:1 to xlsx rows:

    xlsx row number  ==  seq + 2          (1 header row, rows are 1-based)
    e.g.  seq 0000 -> xlsx row 2 ,  seq 0007 -> xlsx row 9

OUTPUT LAYOUT
-------------
    downloads/{gold|silver|other}/{seq4}__{advertiser40}__{platform}__{type}[_{dur}s].{ext}

Extension is decided by the downloaded file's MAGIC BYTES, never the server
Content-Type header (AdLibrary mislabels some PNGs as image/jpeg -- the
Revoicer precedent):  ftyp -> .mp4 ,  FF D8 FF -> .jpg ,
89 50 4E 47 -> .png ,  RIFF..WEBP -> .webp ,  GIF8 -> .gif ,  else -> .bin.

HTTP CLIENT
-----------
Python `requests` with a single reused Session (connection pooling), or
stdlib urllib with a shared opener if requests is unavailable. We do NOT
shell out to Git's mingw curl: it flaps under repeated subprocess spawning
(KL 2026-05-08 / 2026-05-09 -- intermittent rc=2 init failures). A
last-resort fallback to the *Windows native* curl
(C:\\Windows\\System32\\curl.exe -- explicitly NOT mingw) is used only when
both Python clients fail on a given URL.

BEHAVIOR
--------
* 1-second polite delay between network fetches (skipped files cost no delay).
* Idempotent: an existing non-empty file for a seq is skipped, so re-runs
  resume instead of re-downloading.
* Retry guard: one retry after a 3-second backoff; persistent failures are
  appended to downloads/skipped.txt and the run continues.
* --single <row_index> downloads exactly one ad (seq == row_index) for
  spot-testing.

downloads/ is gitignored (.gitignore:6) -- assets never enter the repo.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent          # skill root
INPUT_PATH = SCRIPT_DIR / "samples" / "phase_c_results.json"
DOWNLOADS_DIR = SCRIPT_DIR / "downloads"
SKIPPED_LOG = DOWNLOADS_DIR / "skipped.txt"

USER_AGENT = "psitta-ad-search-phase-e/1.0 (+https://psitta.ai)"
POLITE_DELAY_S = 1.0
RETRY_BACKOFF_S = 3.0
REQUEST_TIMEOUT_S = 120
WIN_NATIVE_CURL = r"C:\Windows\System32\curl.exe"

TIER_RANK = {"gold": 0, "silver": 1}

try:
    import requests  # type: ignore
    _HAVE_REQUESTS = True
except Exception:  # noqa: BLE001 - requests is optional
    import urllib.error
    import urllib.request
    _HAVE_REQUESTS = False


def build_media_url(ad: dict) -> str:
    """Identical selection logic to phase_d_excel.build_media_url."""
    res = ad.get("resource_urls") or []
    if not res:
        return ""
    first = res[0]
    if (ad.get("video_duration") or 0) > 0:
        return first.get("video_url") or first.get("image_url") or ""
    return first.get("image_url") or first.get("video_url") or ""


def sort_ads(ads: list) -> list:
    """Gold first, silver after; within tier heat desc. Stable for ties --
    identical to phase_d_excel.sort_ads so seq aligns with xlsx rows."""
    def key(ad: dict):
        return (TIER_RANK.get(ad.get("_tier"), 99), -(int(ad.get("heat", 0) or 0)))
    return sorted(ads, key=key)


def sanitize(name: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", (name or "").strip()).strip("_").lower()
    return s[:40] or "unknown"


def sniff_ext(head: bytes) -> str:
    """Extension from magic bytes only -- never trust server Content-Type."""
    if head[4:8] == b"ftyp":
        return ".mp4"
    if head[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return ".webp"
    if head[:4] == b"GIF8":
        return ".gif"
    return ".bin"


def fetch_bytes(url: str, session) -> bytes:
    """One fetch attempt via the Python client. Raises on failure."""
    if _HAVE_REQUESTS:
        r = session.get(url, headers={"User-Agent": USER_AGENT},
                         timeout=REQUEST_TIMEOUT_S, allow_redirects=True)
        r.raise_for_status()
        return r.content
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_S) as resp:  # noqa: S310
        if resp.status != 200:
            raise RuntimeError(f"HTTP {resp.status}")
        return resp.read()


def fetch_native_curl(url: str, dest: Path) -> bytes:
    """Last resort: Windows native curl (never mingw). Raises on failure."""
    if not Path(WIN_NATIVE_CURL).exists():
        raise RuntimeError("native curl unavailable")
    cp = subprocess.run(
        [WIN_NATIVE_CURL, "-sS", "-L", "--ssl-no-revoke",
         "--max-time", str(REQUEST_TIMEOUT_S), "-A", USER_AGENT,
         "-o", str(dest), url],
        capture_output=True, text=True, timeout=REQUEST_TIMEOUT_S + 60,
    )
    if cp.returncode != 0 or not dest.exists() or dest.stat().st_size == 0:
        raise RuntimeError(f"native curl rc={cp.returncode} {cp.stderr.strip()[:160]}")
    return dest.read_bytes()


def existing_for_seq(tier_dir: Path, seq: int) -> Path | None:
    """Return an existing non-empty file for this seq (idempotent skip)."""
    if not tier_dir.exists():
        return None
    for p in tier_dir.glob(f"{seq:04d}__*"):
        try:
            if p.is_file() and p.stat().st_size > 0:
                return p
        except OSError:
            continue
    return None


def log_skip(seq: int, ad_key: str, advertiser: str, url: str, reason: str) -> None:
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    with SKIPPED_LOG.open("a", encoding="utf-8") as fh:
        fh.write(f"{seq:04d}\t{ad_key}\t{advertiser}\t{reason}\t{url}\n")


def process_one(i: int, total: int, seq: int, ad: dict, session) -> str:
    """Download one ad. Returns 'downloaded' | 'skipped' | 'failed'."""
    tier = ad.get("_tier") or "other"
    adv = ad.get("advertiser_name") or ""
    platform = (ad.get("platform") or "?").lower()
    is_video = (ad.get("video_duration") or 0) > 0
    typ = "video" if is_video else "image"
    dur = f"_{int(ad.get('video_duration') or 0)}s" if is_video else ""
    tier_dir = DOWNLOADS_DIR / tier

    existing = existing_for_seq(tier_dir, seq)
    if existing is not None:
        print(f"Skipping    {i}/{total}: {adv[:38]!r} {platform} {typ} "
              f"(already present: {existing.name})")
        return "skipped"

    url = build_media_url(ad)
    if not url:
        print(f"FAILED      {i}/{total}: {adv[:38]!r} {platform} {typ} (no media url)")
        log_skip(seq, ad.get("ad_key", ""), adv, "", "no_media_url")
        return "failed"

    print(f"Downloading {i}/{total}: {adv[:38]!r} {platform} {typ} ...")
    tier_dir.mkdir(parents=True, exist_ok=True)
    part = tier_dir / f"{seq:04d}.part"

    last_err = ""
    for attempt in (1, 2):
        try:
            try:
                data = fetch_bytes(url, session)
            except Exception as e_py:  # noqa: BLE001 - py client failed; try native curl
                last_err = f"py:{type(e_py).__name__}:{e_py}"
                data = fetch_native_curl(url, part)
            if not data:
                raise RuntimeError("empty body")
            ext = sniff_ext(data[:16])
            final = tier_dir / f"{seq:04d}__{sanitize(adv)}__{platform}__{typ}{dur}{ext}"
            final.write_bytes(data)
            if part.exists():
                part.unlink()
            warn = "" if ext != ".bin" else "  [WARN unknown magic -> .bin]"
            print(f"  -> {final.name} ({len(data):,} B){warn}")
            return "downloaded"
        except Exception as e:  # noqa: BLE001 - retry once, then log+continue
            last_err = f"{type(e).__name__}:{e}"
            if attempt == 1:
                time.sleep(RETRY_BACKOFF_S)

    if part.exists():
        try:
            part.unlink()
        except OSError:
            pass
    print(f"FAILED      {i}/{total}: {adv[:38]!r} {platform} {typ} ({last_err[:120]})")
    log_skip(seq, ad.get("ad_key", ""), adv, url, last_err[:200])
    return "failed"


def main(argv) -> int:
    ap = argparse.ArgumentParser(description="Phase E media downloader")
    ap.add_argument("--single", type=int, metavar="ROW_INDEX",
                    help="download only the ad at this seq (0-based; == xlsx row - 2)")
    args = ap.parse_args(argv)

    if not INPUT_PATH.exists():
        sys.stderr.write(f"ERROR: input not found: {INPUT_PATH}\n")
        return 2
    doc = json.loads(INPUT_PATH.read_text(encoding="utf-8"))
    ads = doc.get("ads")
    if not isinstance(ads, list) or not ads:
        sys.stderr.write("ERROR: phase_c_results.json has no 'ads' array\n")
        return 2

    ordered = sort_ads(ads)
    total = len(ordered)
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)

    session = None
    if _HAVE_REQUESTS:
        session = requests.Session()
        session.headers.update({"User-Agent": USER_AGENT})

    print(f"[init] {total} ads | client={'requests' if _HAVE_REQUESTS else 'urllib'} "
          f"| out={DOWNLOADS_DIR}")
    print("[init] cross-ref: xlsx row = seq + 2")

    if args.single is not None:
        if not (0 <= args.single < total):
            sys.stderr.write(f"ERROR: --single {args.single} out of range 0..{total-1}\n")
            return 2
        seq = args.single
        result = process_one(1, 1, seq, ordered[seq], session)
        print(f"\n[single] seq={seq:04d} result={result}")
        return 0 if result in ("downloaded", "skipped") else 1

    dl = sk = fa = 0
    for idx, ad in enumerate(ordered):
        result = process_one(idx + 1, total, idx, ad, session)
        if result == "downloaded":
            dl += 1
        elif result == "skipped":
            sk += 1
        else:
            fa += 1
        if result != "skipped":          # polite only when we hit the network
            time.sleep(POLITE_DELAY_S)

    print("\n=== PHASE E SUMMARY ===")
    print(f"  downloaded               : {dl}")
    print(f"  skipped (already present): {sk}")
    print(f"  failed                   : {fa}"
          + (f"   -> see {SKIPPED_LOG}" if fa else ""))
    print(f"  total                    : {total}")
    return 0 if fa == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
