# Page Speed as an SEO Factor

Page speed has been a ranking signal since 2010, but the mechanism changed in 2021 when Google replaced vague "speed" signals with the Core Web Vitals (CWV) framework. CWV measures specific user experiences — not server response time or abstract scores — and uses real-world Chrome user data (CrUX) rather than synthetic lab tests. Understanding this distinction changes how you prioritize optimizations.

## The Three Core Web Vitals

**LCP (Largest Contentful Paint)** — how quickly the largest visible element loads. Target: < 2.5s. This is almost always a hero image, a large heading, or a video poster. LCP is the most impactful CWV for SEO because it directly correlates with perceived load speed.

**CLS (Cumulative Layout Shift)** — how much the page unexpectedly moves while loading. Target: < 0.1. Caused by images without dimensions, late-loading ads, fonts causing text reflow, or dynamic content inserted above existing content. CLS hurts both rankings and user experience — a button that shifts before click causes misclicks.

**INP (Interaction to Next Paint)** — how quickly the page responds to user interactions. Target: < 200ms. Replaced FID in 2024. Caused by heavy JavaScript on the main thread, long tasks during scroll, or unoptimized event handlers. INP problems are almost always JavaScript problems.

## Tools: Lab vs Field Data

**PageSpeed Insights** (`pagespeed.web.dev`) shows both lab data (Lighthouse) and field data (CrUX). Always optimize against field data — that's what Google uses for rankings. Lab data is useful for debugging specific issues, not for gauging ranking impact.

**Google Search Console → Core Web Vitals report** shows your actual CWV status across all pages grouped by issue type. This is the authoritative source for which pages are "Poor", "Needs Improvement", or "Good" in Google's view. Fix "Poor" pages first.

**CrUX data requires enough traffic to populate.** New pages or low-traffic pages won't have field data for 28 days. Use lab data as a proxy during development.

## Quick Wins by Impact

**1. Preload the LCP image.** If your LCP element is an image, add `<link rel="preload" as="image" href="...">` in `<head>`. This alone can improve LCP by 300–800ms by eliminating the browser's image discovery delay.

**2. Eliminate render-blocking JS.** Scripts loaded synchronously in `<head>` block all rendering. Move non-critical scripts to `defer` or `async`. Each blocking script adds its execution time directly to LCP.

**3. Add `width` and `height` to all images.** This eliminates CLS caused by images whose dimensions aren't known until they load. One missing dimension attribute on a hero image can push CLS above 0.1.

**4. Self-host fonts.** Google Fonts adds a cross-origin DNS lookup + stylesheet fetch. Self-hosting with `font-display: swap` eliminates this and reduces FOUT-induced CLS.

**5. Reduce long tasks for INP.** Audit with Chrome DevTools Performance tab for tasks > 50ms on the main thread. Break them up with `scheduler.postTask()` or `setTimeout(..., 0)` to yield to the browser between chunks.

## Speed and Bounce Rate

Faster pages have lower bounce rates and higher engagement time — both indirect ranking signals. Google's studies show bounce rate increases ~32% as page load time goes from 1s to 3s and ~90% going from 1s to 5s. CWV improvements earn direct ranking benefit, but the downstream engagement improvements amplify the SEO impact.

## Key Rules

- Optimize against CrUX field data (Search Console), not just Lighthouse lab scores
- Fix "Poor" CWV pages first — they have the most ranking headroom
- Preload the LCP image as the single highest-ROI speed intervention
- Add explicit width/height to every image to prevent CLS
- Move non-critical JS to defer/async to unblock rendering
- Track CWV per page type (home, product, blog) — issues are usually clustered by template
- Speed improvements affect bounce rate, which amplifies the direct ranking signal
