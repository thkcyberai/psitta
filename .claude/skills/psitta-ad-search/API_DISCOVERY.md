# AdLibrary.com API Discovery — Phase A

## a. Run Metadata

- **Timestamp (UTC, ISO 8601):** 2026-05-11T00:35:08Z
- **Script version:** 1.0
- **Search endpoint:** `POST https://adlibrary.com/api/search`
- **Enrichment endpoint:** `POST https://adlibrary.com/api/enrichment`
- **Search keyword:** `speechify`

## b. Search Request Payload

```json
{
  "keyword": "speechify",
  "appType": "2",
  "geo": [
    "USA"
  ],
  "daysBack": 7,
  "pageSize": 10
}
```

## c. Search Response Schema

### Top-level fields

| Field | Type | Example |
|---|---|---|
| `total` | int | `0` |
| `page` | int | `1` |
| `pageSize` | int | `10` |
| `results` | array<object> | `[{"ad_features": ["10002"], "ad_key": "6594a37e552d0f61d06dffc5a0eb0580", "ads_…` |
| `nextCursor` | string | `c2NyYXBpbmdfY3Vyc29yOk1UYzNPRFF3TXpVd05Eb3hNekUzTmpFd09ETXpOelkzT1RZAMwZDZD` |
| `_credits` | object | `{"used": 1, "remaining": 1009}` |

### `results[0]` fields (first ad)

| Field | Type | Example |
|---|---|---|
| `ad_features` | array<string> | `["10002"]` |
| `ad_key` | string | `6594a37e552d0f61d06dffc5a0eb0580` |
| `ads_promote_type` | string | `2` |
| `ads_type` | int | `2` |
| `advertiser_name` | string | `Speechify - Listen to text with Speechify` |
| `all_exposure_value` | int | `2064` |
| `app_developer` | string | `` |
| `app_support_pc` | boolean | `false` |
| `app_type` | int | `3` |
| `body` | string | `` |
| `call_to_action` | string | `Installer` |
| `comment_count` | int | `0` |
| `created_at` | int | `1769225728` |
| `custom_store_identifier` | string | `` |
| `days_count` | int | `1` |
| `dislike_count` | int | `0` |
| `dynamic_number` | array (empty) | `[]` |
| `ecom_advertiser_id` | string | `speechify.com` |
| `exposure_top` | object | `{}` |
| `fb_merge_channel` | array (empty) | `[]` |
| `first_seen` | int | `1778439550` |
| `has_advertiser_id` | boolean | `true` |
| `has_page_id` | boolean | `false` |
| `has_post_id` | boolean | `false` |
| `has_source_url` | boolean | `false` |
| `has_store_url` | boolean | `true` |
| `heat` | int | `51` |
| `image_ahash_md5` | string | `8720d33b87ab97182d4d9a0ccc3687bc` |
| `impression` | int | `5080` |
| `is_fb_show` | boolean | `false` |
| `is_playlet_creative` | boolean | `false` |
| `last_seen` | int | `1778440153` |
| `like_count` | int | `0` |
| `logo_url` | string | `` |
| `message` | string | `` |
| `new_week_exposure_value` | int | `2064` |
| `os` | int | `2` |
| `page_name` | string | `` |
| `pin_count` | int | `0` |
| `platform` | string | `admob` |
| `preview_img_url` | string | `https://adlibrary.com/api/media?u=fQZXQIRR04wpj-jSDotQqAZgWNrtLW3hyjlLWzKgFJ9yY…` |
| `resource_urls` | array<object> | `[{"type": 2, "image_url": "https://adlibrary.com/api/media?u=JbL0-IZuelK0i0YUkD…` |
| `resume_advertising_flag` | boolean | `true` |
| `search_flag` | int | `145458` |
| `share_count` | int | `0` |
| `text_md5` | string | `` |
| `title` | string | `` |
| `video_duration` | int | `30` |
| `video2pic` | int | `0` |
| `view_count` | int | `0` |
| `collect_flag` | int | `0` |
| `custom_tag` | array (empty) | `[]` |
| `ads_archived` | boolean | `false` |
| `is_web_advertiser` | boolean | `false` |
| `estimated_spend` | int | `28` |
| `estimated_spend_currency` | string | `USD` |

## d. Enrichment Request Payload

```json
{
  "ad": {
    "ad_key": "6594a37e552d0f61d06dffc5a0eb0580",
    "platform": "admob",
    "advertiser_name": "Speechify - Listen to text with Speechify",
    "body": "",
    "preview_img_url": "https://adlibrary.com/api/media?u=fQZXQIRR04wpj-jSDotQqAZgWNrtLW3hyjlLWzKgFJ9yY03TIlHsNtn1w4dfGO1JqlVp46-tcYdI9AYzfqvV-EOHk_KRnNtjc9D6IlrGc54jq0qopz33jtgWnnZfJEmzbSLcEVLrgQ"
  }
}
```

## e. Enrichment Response Schema

| Field | Type | Example |
|---|---|---|
| `enrichment` | object | `{"summary": "**Brand:** Speechify\n**Product:** An app that reads text aloud.\n…` |
| `cached` | boolean | `false` |
| `balance` | int | `1008` |
| `creditsUsed` | int | `1` |

## f. Schema-Gap Resolutions

GAP 1: Does search `response.list[i]` include a field indicating ad format (video / image / carousel)?

**FAIL** — No format-indicating field found in `list[0]`.

Recommended derivation strategy: at Phase B, derive ad format from enrichment URL fields. Inspect the enrichment response: presence of `video_url` (or any field ending in `video`) → format=`video`; absence of video URL but presence of `image_url`/`preview_img_url` → format=`image`; presence of an array of media items (e.g. `assets`/`carousel_cards` with length > 1) → format=`carousel`. This costs 1 enrichment credit per ad to determine format.

GAP 2: Does search `response.list[i]` include `landing_page_url`?

**FAIL** — No landing/destination URL field found in `list[0]`.

Implication: the enrichment endpoint's input schema accepts ad fields including (per docs) `landing_page_url`, but search does not provide it. Phase B options: (a) supply landing_page_url externally if a downstream caller has it, (b) omit the field from the enrichment payload and rely on the API's tolerance of its absence, (c) parse the landing URL out of the enrichment response after the call (round-trip is required regardless).

GAP 3: Does search `response.list[i]` include any field representing call-to-action (CTA)?

**PASS** — Field `call_to_action` present in `list[0]`. Example: `Installer`.

## g. Credit Consumption

Search consumed: 1; Enrichment consumed: 1; Remaining credits after both calls: 1008.

- Search response `_credits.used`: `1`
- Search response `_credits.remaining`: `1009`
- Enrichment response `balance`: `1008`

## h. Rate-Limit Headers Observed

None observed.

## i. Phase B Design Implications

- Ad format is not present in search results; Phase B must derive it from enrichment URL fields, which means every row in the Excel output requires an enrichment credit (no shortcut for image-only filtering).
- Landing page URL is absent from search results; the Phase B enrichment payload must omit `landing_page_url` or supply it externally. The skill should not fabricate a value.
- CTA is present via `call_to_action` in search results; Excel column populates directly without enrichment.
- Token never appears in stdout, log, or saved files — discovery script's redaction sweep (`adl_*` regex + literal token replace) is the canonical pattern for the Phase B production skill.
- Re-run safety must persist into Phase B: any production CLI that consumes paid credits should require an explicit `--force` flag to overwrite cached results.

---

_Generated by `discovery.py` — Phase A is read-only and consumes 2 API credits._
