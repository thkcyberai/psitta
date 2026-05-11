---
name: psitta-ad-search
description: Competitive ad research skill for Psitta marketing. Pulls high-performing competitor and category ads from AdLibrary's API, classifies them into Gold (proven winners) and Silver (promising) tiers based on multi-signal quality filters (days_count, heat, impression, estimated_spend), enriches each with AI-generated UGC replication briefs, and outputs an Excel workbook for the marketing agent to consume.
---

# psitta-ad-search

Pulls high-performing competitor and category ads from AdLibrary's API, tier-classifies them by quality signals, and outputs an Excel workbook ready for marketing-agent consumption.

## When to use

Trigger this skill when:
- Producing new marketing creative for Psitta and needing competitor / adjacent-market reference ads
- Refreshing the marketing intelligence library quarterly
- Investigating a specific keyword's high-performing ads ahead of a campaign launch

## Pipeline

The skill runs in four sequential phases (scripts/discovery.py, phase_b_search.py, phase_c_enrich.py, phase_d_excel.py):

| Phase | Purpose | Credits | Output |
|---|---|---|---|
| A — Discovery | Probe API, document schema | 2 | API_DISCOVERY.md |
| B — Batch search + tier classify | 12 keywords × /api/search, tier ads | 12 | samples/phase_b_results.json |
| C — Enrichment | Per-ad /api/enrichment with AI brief | ~230 | samples/phase_c_results.json |
| D — Excel writer | Format final workbook | 0 | psitta_ad_research_<YYYYMMDD>.xlsx |

Default total credit cost per full run: ~244 (1 search per keyword + 1 enrichment per kept ad).

## Tier classification

| Tier | Days running | AND any one of |
|---|---|---|
| Gold | ≥ 30 | heat ≥ 100 OR impression ≥ 50,000 OR estimated_spend ≥ $300 |
| Silver | ≥ 14 | heat ≥ 30 OR impression ≥ 5,000 OR estimated_spend ≥ $50 |

Thresholds are tunable as constants at the top of phase_b_search.py.

## Default keyword set

12 keywords across 3 buckets:

- **direct_analog**: speechify, audible, blinkist, headway, shortform, text to speech
- **audience_overlap**: grammarly, ai writing, writing app
- **pattern_source**: notion, productivity app, ai tool

Edit SEARCH_KEYWORDS in phase_b_search.py to customize.

## Dependencies

- Python 3.10+
- openpyxl (only required for Phase D Excel writer; Phases A-C are stdlib-only)
- ADLIBRARY_API_KEY in repo .env (47-char adl_* key)

## Re-running

Each phase has a re-run guard. To re-run:
- Delete the relevant output file from samples/ (or the skill root for the XLSX)
- Or use --force flag (Phase B and C support this; will overwrite existing output and burn fresh credits)

## Known calibration notes

- appType=2 was the in-app-ads bucket as of May 2026; AdLibrary support flagged migration to appType=3 for future-proofing. Edit APP_TYPE constant in phase_b_search.py after the migration completes.
- heat, impression, estimated_spend scales are platform-specific (admob ≠ meta ≠ tiktok). Thresholds may need recalibration per platform mix.
- ai tool keyword historically produces zero kept ads — generic-noun search-relevance noise. Consider replacing with a specific tool name.

## Output column reference

The XLSX has 20 columns per ad. Marketing agent consumes columns 17-20 (enrichment fields) for hook patterns, UGC scripts, and creative analysis. Filter on tier column for Gold-only when prioritizing high-confidence templates.
