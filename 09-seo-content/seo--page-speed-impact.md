# SEO: Page Speed Impact

## Overview
Page speed affects rankings directly (Core Web Vitals are ranking signals) and indirectly (slow pages have higher bounce rates, lower session depth, and lower conversion rates — all of which reduce the revenue SEO drives). The compounding effect matters: a page that ranks #3 but loads slowly will be outcompeted by a #5 page that ranks slightly lower but delivers a better experience. Over time, user engagement signals influence rankings.

## Speed as Ranking Signal

- Core Web Vitals (LCP, INP, CLS) are confirmed Google ranking signals since 2021
- Google weights them as a tiebreaker between otherwise equivalent pages — not a substitute for relevance
- Mobile CWV matters more (Google uses mobile-first indexing)
- The signal is from real-user field data (CrUX), not lab benchmarks

## Speed as Conversion Signal

Research benchmarks:
- 100ms → ~1% conversion drop (Akamai/Deloitte study)
- 1s delay in mobile load time → up to 20% conversion drop (Google)
- LCP > 4s: bounce rate roughly doubles vs LCP < 2.5s

This creates a compounding effect: slow pages rank lower AND convert worse, reducing ROI from every click earned.

## Biggest Impact Wins (Ranked by Effort:Impact)

### 1. Image Optimization (Highest Impact)
Images are the LCP element on most pages and account for 50–70% of page weight on typical sites.
- **Format**: WebP = ~30% smaller than JPEG with equivalent quality; AVIF = ~50% smaller but lower browser support
- **Lazy loading**: `loading="lazy"` on all images below the fold
- **Never lazy load the LCP image**: add `fetchpriority="high"` to hero/LCP image instead
- **Responsive images**: `srcset` so mobile devices don't download desktop-sized images
- **Compression**: target < 100KB for above-fold images; < 250KB for full-page hero images

### 2. Server Response Time / TTFB
Time to First Byte > 800ms creates a ceiling on achievable LCP.
- CDN + edge caching: static assets served from PoP closest to user
- HTML caching: cache rendered HTML for non-personalized pages
- Database query optimization: TTFB often reflects slow server-side query execution
- Edge functions (Cloudflare Workers, Vercel Edge): move compute to the edge

### 3. JavaScript Optimization
JS blocks the main thread and delays INP.
- Defer non-critical scripts: `<script defer>` or `<script async>`
- Remove unused JavaScript (bundle analysis: check with Coverage tab in DevTools)
- Code split: don't load the entire app bundle on the landing page
- Avoid synchronous third-party scripts (analytics, chat widgets) in `<head>` — they block rendering

### 4. CSS Optimization
Render-blocking CSS in `<head>` delays FCP/LCP.
- Inline critical CSS (above-the-fold styles) in `<head>`
- Load non-critical CSS asynchronously (`rel="preload"` + `onload`)
- Remove unused CSS

### 5. Font Loading
Web fonts cause FOUT (Flash of Unstyled Text) and contribute to CLS.
- `font-display: swap` or `optional` (prevents invisible text during load)
- Preload critical fonts: `<link rel="preload" as="font">`
- Self-host fonts (avoids DNS lookup + extra round trip to Google Fonts CDN)

## Measurement

- **Field data**: CrUX via GSC Core Web Vitals report, PageSpeed Insights field tab
- **Lab data**: Lighthouse, WebPageTest (useful for debugging, not the ranking signal)
- **RUM**: `web-vitals` npm package + analytics to capture real sessions
- **Audit before and after each deployment** — regressions are common when adding third-party scripts

## Key Rules

- Optimize for field data (CrUX), not just Lighthouse score
- Never lazy load the first viewport image — this alone causes many LCP failures
- Third-party scripts are the #1 source of INP and speed regressions on business sites
- CDN is table stakes — direct origin serving from a single region is slow for global audiences
- Image format conversion (JPG → WebP) is the fastest high-impact win with no visual quality loss
