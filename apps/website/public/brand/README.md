# Psitta Brand Bundle

Generated April 20, 2026 via Gemini Nano Banana + PIL resizing.
Source: STYLE-LOCKED prompt sequence (12 masters) + derived web sizes.

## Directory structure

Place these files in your repo at:

```
apps/website/public/brand/
```

For website use. Reference them as `/brand/<filename>` from HTML and components.

## Files

### Web master assets (from Gemini generation)

| File | Dimensions | Use case |
|------|-----------|----------|
| `psitta-horizontal.png` | 1456×720 | **CANONICAL LOGO** — website header, email signatures, invoices |
| `psitta-vertical.png` | 720×1456 | Vertical contexts (mobile splash, narrow containers) |
| `psitta-bird.png` | 1024×1024 | Bird icon alone (no wordmark) — compact contexts |
| `psitta-wordmark.png` | 2064×512 | Wordmark alone (no bird) — typography-only contexts |
| `psitta-mono-black.png` | 1456×720 | Single-color print, fax, embossed merchandise |
| `psitta-mono-white.png` | 1456×720 | Over photographs, dark scenes, watermarks |
| `psitta-dark-bg.png` | 1456×720 | For dark backgrounds (lightened gradient) |
| `psitta-favicon-master.png` | 1024×1024 | Source for favicon derivation (bird only) |
| `psitta-avatar-light.png` | 1024×1024 | Social media profile (Twitter, LinkedIn) — light theme |
| `psitta-avatar-dark.png` | 1024×1024 | Social media profile — dark theme |
| `psitta-banner.png` | 1792×592 | Twitter/LinkedIn cover image |
| `psitta-og-card.png` | 1424×752 | Open Graph meta card (link previews) |

### Derived web sizes (from psitta-favicon-master.png)

| File | Dimensions | Use case |
|------|-----------|----------|
| `favicon-16.png` | 16×16 | Browser tab, bookmarks (small) |
| `favicon-32.png` | 32×32 | Browser tab, bookmarks (standard) |
| `favicon-48.png` | 48×48 | Windows taskbar, pinned sites |
| `favicon-64.png` | 64×64 | HiDPI displays |
| `favicon.ico` | 16+32+48 | Multi-resolution ICO (old browsers, IE) |
| `apple-touch-icon-180.png` | 180×180 | iOS home screen icon |
| `android-chrome-192.png` | 192×192 | Android Chrome home screen |
| `android-chrome-512.png` | 512×512 | Android splash screen |

## HTML head snippet (for Next.js app/layout.tsx)

```tsx
<link rel="icon" type="image/png" sizes="16x16" href="/brand/favicon-16.png" />
<link rel="icon" type="image/png" sizes="32x32" href="/brand/favicon-32.png" />
<link rel="icon" href="/brand/favicon.ico" />
<link rel="apple-touch-icon" sizes="180x180" href="/brand/apple-touch-icon-180.png" />
<link rel="icon" type="image/png" sizes="192x192" href="/brand/android-chrome-192.png" />
<link rel="icon" type="image/png" sizes="512x512" href="/brand/android-chrome-512.png" />
<meta property="og:image" content="https://psitta.ai/brand/psitta-og-card.png" />
<meta name="twitter:image" content="https://psitta.ai/brand/psitta-og-card.png" />
```

## Known imperfections (queued as M8c.1 polish)

1. **Gemini watermark** (subtle) visible on assets: psitta-bird, psitta-mono-white, psitta-favicon-master, psitta-avatar-light, psitta-avatar-dark, psitta-og-card
2. **Social avatar centering** — bird is offset right-of-center in psitta-avatar-light and psitta-avatar-dark (fine before circular crop; verify after)
3. **No SVG versions yet** — queue SVG conversion via vectorizer.ai ($10) or hand-traced by designer ($50-150)

These are acceptable for M8a/M8b ship. Replace at M8c polish phase.

## SVG conversion (next step, not blocking)

Upload `psitta-horizontal.png` (1456×720) to [vectorizer.ai](https://vectorizer.ai):
- Detail level: High
- Edge fidelity: Smooth
- Color: Full color (preserve gradient)
- Output format: SVG

The resulting SVG becomes `psitta-logo.svg` in this folder and replaces the PNG in the website header for crisp rendering at all sizes.

## Constants for CSS / Tailwind

```css
:root {
  --psitta-gradient-start: #C7D2FE;  /* periwinkle */
  --psitta-gradient-mid:   #818CF8;  /* indigo-400 */
  --psitta-gradient-end:   #6366F1;  /* indigo-500 */
  --psitta-gradient-dark:  #4F46E5;  /* indigo-600 */
  --psitta-eye:            #1E1B4B;  /* indigo-950 */
  --psitta-paper:          #FAFAF7;  /* paper light background */
  --psitta-dark-bg:        #0F172A;  /* slate-900 dark bg */
  --psitta-text-tagline:   #334155;  /* slate-700 body */
}
```
