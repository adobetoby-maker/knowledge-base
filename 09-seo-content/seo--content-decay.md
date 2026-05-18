# SEO: Content Decay

## Overview

Content decay is when a page's rankings and traffic drop over time without changes to the page. Causes: competitors publish better content, the topic evolves but the page doesn't, Google freshness signals favor newer updates, or the SERP changes format (adds featured snippets or shopping ads). Systematic decay detection and re-optimization is more efficient than constantly creating new content.

## Detecting Decaying Content

```ts
// Query Search Console API for declining pages
async function getDecayingPages(siteUrl: string, daysBack: number = 90) {
  const auth = new google.auth.GoogleAuth({ scopes: ['https://www.googleapis.com/auth/webmasters.readonly'] })
  const sc = google.searchconsole({ version: 'v1', auth })

  const endDate = new Date()
  const startDate = new Date(endDate)
  startDate.setDate(startDate.getDate() - daysBack)

  const prevEndDate = new Date(startDate)
  const prevStartDate = new Date(prevEndDate)
  prevStartDate.setDate(prevStartDate.getDate() - daysBack)

  // Current period
  const current = await sc.searchanalytics.query({
    siteUrl,
    requestBody: {
      startDate: startDate.toISOString().split('T')[0],
      endDate: endDate.toISOString().split('T')[0],
      dimensions: ['page'],
    },
  })

  // Previous period
  const previous = await sc.searchanalytics.query({
    siteUrl,
    requestBody: {
      startDate: prevStartDate.toISOString().split('T')[0],
      endDate: prevEndDate.toISOString().split('T')[0],
      dimensions: ['page'],
    },
  })

  // Find pages with >20% click decline
  const prevMap = new Map(previous.data.rows?.map(r => [r.keys![0], r.clicks!]) ?? [])

  return (current.data.rows ?? [])
    .filter(row => {
      const prev = prevMap.get(row.keys![0]) ?? 0
      return prev > 50 && row.clicks! < prev * 0.8  // >20% decline, significant pages only
    })
    .map(row => ({
      page: row.keys![0],
      currentClicks: row.clicks!,
      previousClicks: prevMap.get(row.keys![0])!,
      decline: Math.round((1 - row.clicks! / prevMap.get(row.keys![0])!) * 100),
    }))
    .sort((a, b) => b.decline - a.decline)
}
```

## Automated Last-Updated Dates

Freshness signals: update the page's `dateModified` when content is actually refreshed (not on trivial edits).

```ts
interface Article {
  slug: string
  title: string
  publishedAt: Date
  updatedAt: Date
  body: string
}

// In metadata
export async function generateMetadata({ params }: { params: { slug: string } }) {
  const article = await getArticle(params.slug)
  return {
    // Signals freshness to search engines
    other: {
      'article:published_time': article.publishedAt.toISOString(),
      'article:modified_time': article.updatedAt.toISOString(),
    },
  }
}
```

## Refresh Checklist for Decaying Pages

When a page is identified as decaying:

1. **Check position vs last year** — if position dropped, competitors beat you on quality
2. **Run the target keyword through Google** — has SERP format changed? (snippets, images, video)
3. **Check competitor content** — what do the top 3 results have that yours doesn't?
4. **Update stats and examples** — year-old data signals staleness
5. **Expand thin sections** — if content is < 1000 words, add depth
6. **Add FAQ schema** — if SERP has People Also Ask boxes you're not capturing

```ts
// Track content refresh dates in DB
await db.update(articles).set({
  updatedAt: new Date(),
  refreshNote: 'Updated Q2 2026 stats, added competitor comparison section',
}).where(eq(articles.id, article.id))
```

## Content Consolidation

Sometimes two pages compete for the same keyword (keyword cannibalization). Merge them:

```
BEFORE:
  /blog/seo-tips → 800 words, ranking #12
  /blog/seo-best-practices → 600 words, ranking #14

AFTER:
  /blog/seo-tips → 1800 words (merged), ranking #5
  /blog/seo-best-practices → 301 redirect to /blog/seo-tips
```

301 redirect passes link equity. The merged page ranks better because it's more comprehensive.

## Redirect Decayed Pages

If a page can't be refreshed and the topic is no longer relevant:

```ts
// next.config.ts
export default {
  redirects: async () => [
    {
      source: '/blog/old-topic',
      destination: '/blog',  // Redirect to closest relevant page, not 404
      permanent: true,
    },
  ],
}
```

Better a 301 redirect than a page ranking for nothing — the redirect passes any remaining link equity.

## Key Rules

- Monitor decaying content monthly using Search Console data — clicking decline is easier to reverse early.
- Updating `dateModified` on cosmetic changes (fixing typos) is seen as manipulation — only update when there's substantive content change.
- Keyword cannibalization (two pages competing) causes both to rank worse — consolidate and redirect.
- A page that's been stagnant for 2+ years while competitors update quarterly will decay even without changes — freshness is relative to competitors.
- Prioritize refresh over new content for high-traffic pages — ROI is much higher on existing pages with existing authority.
