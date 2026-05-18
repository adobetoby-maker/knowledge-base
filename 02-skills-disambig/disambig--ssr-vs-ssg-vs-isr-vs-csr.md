# Next.js Rendering Mode Selection — SSG vs ISR vs SSR vs CSR

## Why the Decision Matters

Rendering mode determines where and when HTML is produced, which drives SEO, performance, infrastructure cost, and data freshness. Getting this wrong means paying for SSR on content that never changes, or shipping blank HTML to crawlers on pages that need SEO.

## SSG — Static Site Generation

HTML is generated at build time and served as a static file. The fastest possible delivery — CDN-cached, zero server cost per request, instant TTFB.

**Use when:** Content does not change between deploys, or changes infrequently enough that a redeploy is acceptable. Marketing pages, documentation, blog posts, pricing pages. Also use for pages with no personalization where SEO matters.

**Pitfall:** Build time grows linearly with page count. A 50,000-product catalog with `generateStaticParams` can take 20+ minutes to build. Above ~5,000 static paths, consider ISR instead.

## ISR — Incremental Static Regeneration

Like SSG, but pages regenerate in the background after a `revalidate` interval (seconds). A stale page is served immediately; regeneration happens on the next request after the interval expires.

**Use when:** Content changes regularly but not instantly — blog posts that get updated, product pages where 60-second staleness is acceptable, news feeds with low edit frequency. ISR is the best trade-off for most content-heavy sites.

**Pitfall:** Stale data is always possible. If a price change must be reflected immediately, ISR with a 60-second revalidate is not acceptable. Use `revalidatePath()` / `revalidateTag()` from a webhook to force on-demand revalidation when content changes — this makes ISR behave like SSR for cache-busting without the per-request compute cost.

## SSR — Server-Side Rendering

HTML is generated on every request, using fresh data each time.

**Use when:** Content is personalized per user (dashboards, feeds, account pages), data changes faster than any acceptable revalidation window, or the page must reflect real-time state. Also use when you need access to request headers or cookies to determine what to render.

**Pitfall:** Every request hits your server or serverless function. SSR pages cannot be CDN-cached without careful Vary headers and surrogate key logic. Cold starts in serverless environments add latency. If a page is accessed by 10,000 users simultaneously, you pay for 10,000 renders.

**Common mistake:** Using SSR for pages that look dynamic but are actually the same for all users (e.g., a public leaderboard). ISR or SSG with client-side hydration handles this at a fraction of the cost.

## CSR — Client-Side Rendering

No server-rendered HTML for the data — the shell is served statically, and the browser fetches data directly via API calls after JavaScript loads.

**Use when:** The content is private (behind auth), SEO is irrelevant, and you are already loading the page shell. User dashboards, admin panels, tool UIs, and any page that is never indexed by search engines. Also appropriate when the data is user-owned and changes in real time (e.g., a live feed the user controls).

**Pitfall:** The page is blank HTML until JS loads and the API call resolves. Crawlers see nothing. If this page ever needs to be indexed, CSR is the wrong choice. Time to first meaningful content is also slower than server-rendered alternatives.

## Decision Tree

```
Does the content vary per user?
  → Yes: Is SEO needed? No → CSR. Yes → SSR.
  → No: Does it change faster than ~60s? Yes → SSR.
        Does it change at all? No → SSG.
        Changes sometimes → ISR with revalidate + on-demand revalidation via webhook.
```

## Key Rules

- **Default to SSG or ISR** for public pages — only use SSR when you genuinely need per-request fresh data.
- **Do not use SSR for marketing pages** — they never change per user and the compute cost is pure waste.
- **Combine modes:** SSR the shell (with user nav state), CSR the main content area for real-time data. Next.js lets you mix rendering strategies per component via `"use client"`.
- ISR's `revalidate` is a minimum, not a guarantee — regeneration happens lazily on request, not on a timer.
- When using on-demand revalidation (`revalidateTag`), tag your fetches at the data-dependency level, not the page level — coarse tags invalidate too much.
