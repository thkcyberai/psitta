# IndexNow — psitta.ai

IndexNow is an open protocol that lets a site tell participating search
engines the moment a URL is created, updated, or deleted, instead of
waiting for the next crawl. Bing, Yandex, Seznam, and Naver participate.
Google does NOT — submit URLs to Google via Search Console's URL
Inspection tool instead.

## Key

Active key: `07802707e10db65b0a2242f1054e6ab6`

The key is published at two locations on this origin:

- `https://psitta.ai/07802707e10db65b0a2242f1054e6ab6.txt` — the
  canonical key file (URL path must match the key value, per protocol).
- `https://psitta.ai/indexnow-key.txt` — a human-friendly alias so the
  operator can look up the active key without listing the public dir.

Both files contain the same single-line value (no trailing newline) and
are served as static assets by the S3 + CloudFront distribution.

## Pinging IndexNow on publish

When a new page ships or an existing page changes materially, submit the
affected URLs to IndexNow with one POST:

```bash
curl -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json" \
  -d '{
    "host": "psitta.ai",
    "key": "07802707e10db65b0a2242f1054e6ab6",
    "keyLocation": "https://psitta.ai/07802707e10db65b0a2242f1054e6ab6.txt",
    "urlList": [
      "https://psitta.ai/",
      "https://psitta.ai/new-page/"
    ]
  }'
```

A `200 OK` means the submission was accepted; `202 Accepted` means the
request is being processed. Any `4xx` indicates a key or URL problem
worth investigating before retrying.

## Future automation

This is a manual workflow for now. A later iteration can wire a ping
into the website deploy workflow (after the S3 sync + CloudFront
invalidation), diffing the new sitemap against the previous build to
submit only changed URLs.
