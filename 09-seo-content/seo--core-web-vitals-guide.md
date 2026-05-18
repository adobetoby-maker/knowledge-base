# SEO: Core Web Vitals Guide

## Overview
Core Web Vitals became a Google ranking signal in 2021. They measure real-user experience — not hypothetical load times, but actual interaction quality in the field. The critical distinction: Google uses Chrome User Experience Report (CrUX) field data, not Lighthouse lab scores. A page can score 95 in Lighthouse and still fail CWV if real users on slower connections experience worse performance.

## The Three Metrics

### LCP — Largest Contentful Paint
**Threshold:** Good < 2.5s, Needs Improvement 2.5–4s, Poor > 4s

Measures when the largest visible content element renders (usually a hero image or H1).

**Root causes of slow LCP:**
- Slow server response (TTFB > 800ms) — address with CDN, caching, edge functions
- Render-blocking resources (CSS, JS loaded synchronously in `<head>`)
- Large, unoptimized images — biggest win: use WebP/AVIF, add `fetchpriority="high"` to the LCP image
- Lazy loading the LCP image — never lazy load the first viewport image

**Fix priority:**
1. Identify the LCP element (DevTools > Performance > LCP marker)
2. Ensure it loads from a fast origin (CDN-cached, preloaded)
3. Add `<link rel="preload" as="image">` for LCP images
4. Avoid lazy loading on above-the-fold images

### INP — Interaction to Next Paint
**Threshold:** Good < 200ms, Needs Improvement 200–500ms, Poor > 500ms

Replaced FID in March 2024. Measures responsiveness from user input (click, tap, key) to next frame paint. Captures the worst interaction over a session, not just first input.

**Root causes of slow INP:**
- Long tasks blocking the main thread (JS > 50ms per task)
- Third-party scripts (analytics, chat, ads) competing for main thread
- Synchronous operations (localStorage, DOM queries) in event handlers
- React/Vue hydration blocking

**Fix approaches:**
- Break long tasks with `scheduler.yield()` or `setTimeout(0)` to yield to the browser
- Defer non-critical third-party scripts
- Move heavy computation off main thread to Web Workers
- Debounce high-frequency event listeners (scroll, resize, input)

### CLS — Cumulative Layout Shift
**Threshold:** Good < 0.1, Needs Improvement 0.1–0.25, Poor > 0.25

Measures unexpected visual movement. Each shift = (impact fraction × distance fraction). Accumulates over page lifetime.

**Common causes:**
- Images without explicit `width` and `height` attributes (browser doesn't reserve space)
- Ads, embeds, iframes without reserved dimensions
- Dynamic content injected above existing content (banners, cookie notices)
- Web fonts causing FOUT (Flash of Unstyled Text) that shifts text reflow

**Fixes:**
- Always set `width` and `height` on `<img>` (CSS `aspect-ratio` is the modern equivalent)
- Reserve space for ads/iframes with `min-height`
- Use `font-display: optional` to prevent font-induced reflow
- Inject new content below the fold, not above existing content

## Measuring Correctly

- **Lab data** (Lighthouse, PageSpeed Insights): useful for debugging, not the ranking signal
- **Field data** (CrUX): the actual signal Google uses — requires real users, takes 28-day rolling window to update
- **GSC Core Web Vitals report**: shows which URLs are "Poor" vs "Good" in field data
- **Real User Monitoring (RUM)**: add `web-vitals` npm package to collect field data on your users

## Key Rules

- Fix LCP first — it has the most impact on perceived load speed and is easiest to improve
- Never lazy load the LCP image — this is the single most common CWV mistake
- CrUX data lags 28 days — improvements won't show in GSC immediately
- Mobile CWV thresholds are the same as desktop but harder to achieve (slower CPUs, networks)
- Third-party scripts (chat widgets, analytics) frequently cause INP failures — audit them
- CWV is one ranking signal, not the only one — a poor CWV score won't kill a strong page, but it creates a competitive disadvantage
