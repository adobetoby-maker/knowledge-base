# Content Refresh Strategy

## Why Content Decays

Published content loses rankings because:
- Competitors publish newer, more comprehensive articles
- Information becomes outdated (prices, services, hours change)
- Google re-evaluates pages over time (freshness signal)
- Internal linking patterns change as new articles are added

Refreshing existing articles is 3-5x more efficient than writing new ones for maintaining rankings.

## Identifying Articles to Refresh

Priority order for refresh:

1. **Traffic decline** — was ranking, now dropped 3+ positions
2. **Near-first-page** — ranking #5-15 for a high-value keyword
3. **Outdated information** — mentions past dates, old pricing, services you no longer offer
4. **Short articles** — under 600 words for competitive topics (competitors have 1200+)
5. **Thin FAQs** — FAQ sections with < 5 Q&As for a topic that has common questions

## Refresh Checklist

For each article being refreshed:

**Content audit:**
- [ ] Are all prices, hours, service names accurate?
- [ ] Does the intro mention current year or recently dated info?
- [ ] Are the FAQ questions still what people actually ask?
- [ ] Is the word count competitive with top-3 ranking pages?
- [ ] Are there questions the article should answer but doesn't?

**SEO audit:**
- [ ] Is the primary keyword in the H1?
- [ ] Are secondary keywords in H2 subheadings?
- [ ] Is there an internal link to the most relevant service page?
- [ ] Does the meta description have a call to action?
- [ ] Are there at least 3 related internal links?

**Schema audit:**
- [ ] Does a service article have FAQPage schema?
- [ ] Does a how-to article have HowTo schema?

## TypeScript Refresh Procedure (jrs-auto-repair)

All articles in `lib/articles.ts`. Refresh = edit the `body` string and update `date`:

```typescript
// lib/articles.ts
{
  slug: 'brake-pad-replacement-twin-falls',
  title: 'Brake Pad Replacement in Twin Falls, ID: What to Expect',
  excerpt: 'Learn how brake pad replacement works at Jr.\'s Auto Repair...',
  category: 'repair',
  date: '2025-09-15',  // update to today's date on refresh
  readTime: 7,
  body: `...updated content...`,
}
```

Update `date` to the current date — search engines treat it as a freshness signal.

## Adding the Refresh Date

When refreshing, add a note to the article body (visible to users):

```
*Updated September 2025 with current pricing and service availability.*
```

Put it near the top, before the main content. This signals freshness to both users and search engines.

## What to Add During a Refresh

Common additions that improve rankings:

**Expand the FAQ** — add 3-5 new Q&As targeting questions people ask but the article doesn't answer. Use "People also ask" in Google for question ideas.

**Add a comparison table** — "brake pads vs rotors: when to replace" — tables often capture featured snippets.

**Add specific local context** — mention Twin Falls weather's effect on brake wear, Magic Valley driving conditions, common car models at the shop.

**Add an expert tip callout:**
```html
<div class="bg-muted p-4 rounded-md">
  <strong>Pro tip from Jr.'s:</strong> In Twin Falls winters, we recommend checking 
  brake fluid every 2 years — moisture absorption accelerates brake fade in cold weather.
</div>
```

## Tracking Refresh Progress

Keep a simple log in `lib/articles.ts` comments or a separate metadata file:

```typescript
// In article metadata, add optional refresh tracking:
interface Article {
  slug: string
  title: string
  // ...
  lastRefreshedDate?: string    // ISO date of last manual refresh
  refreshPriority?: 'high' | 'medium' | 'low'
}
```

Schedule systematic review: mark all articles > 6 months old as candidates for review.
