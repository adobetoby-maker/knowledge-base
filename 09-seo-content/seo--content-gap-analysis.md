# SEO: Content Gap Analysis

## What This Solves

Content gap analysis finds topics your target audience searches for where you have no ranking content. It's more actionable than keyword research because you know a competitor has already proven the ranking opportunity — someone is already winning the traffic.

## Three Types of Gaps

**1. Topic gaps** — competitor has a page on X, you don't
**2. Depth gaps** — both have content on X, but theirs is more comprehensive
**3. Intent gaps** — both have content, but yours mismatches what searchers actually want

## Process: Manual (No Tools)

For a small site with known competitors:

```ts
// 1. List competitor's pages (from their sitemap)
const competitorPages = await fetch('https://competitor.com/sitemap.xml')
  .then(r => r.text())
  .then(xml => parseXml(xml))

// 2. List your pages
const yourPages = getAllArticleSlugs() // from lib/articles.ts

// 3. Find topics they have that you don't
const yourTopics = new Set(yourPages.map(normalizeTopicFromSlug))
const gaps = competitorPages
  .filter(url => !yourTopics.has(normalizeTopicFromSlug(url)))
  .filter(url => estimatedSearchVolume(url) > 100)
```

## Process: Using Google Search Console

Your Search Console data shows:
- **Queries with impressions but 0 clicks** — ranking page 2+ for these queries; priority for optimization
- **Queries with 0 impressions** — topics you're not visible for at all; need new content

Export from: Search Console → Performance → Search Results → Download

## Depth Gap Detection

Check if your content is shallower than the ranking page:

Signals of depth gaps:
- Your word count is less than 60% of the ranking article
- Ranking article has an FAQ section, yours doesn't
- Ranking article covers a subtopic in H2 that you only mention in passing
- Ranking article has more internal links to related content

For depth gaps: don't create a new page — expand the existing one.

## Intent Gap Detection

Intent mismatch is harder to detect and more impactful to fix:

| Query | Typical Intent | Your Current Content | Problem |
|-------|---------------|---------------------|---------|
| "how to check brake pads" | How-to tutorial | Service page pitch | Wrong format |
| "brake pad replacement cost" | Price transparency | Long pitch without price | Missing the answer |
| "when to replace brake pads" | Diagnostic guide | Brake service overview | Wrong focus |

Fix: examine the top 3 ranking pages for a query — what format are they? (listicle, how-to, comparison, definition). Match that format.

## Gap Prioritization Matrix

```ts
interface ContentGap {
  topic: string
  estimated_volume: number
  competitor_rank: number
  difficulty_estimate: number // 1-10
  time_to_write: number // hours
}

// Priority score: volume × (1/difficulty) × (1/time)
const priorityScore = (gap: ContentGap) =>
  (gap.estimated_volume / 100) * (10 / gap.difficulty_estimate) * (4 / gap.time_to_write)

const prioritized = gaps.sort((a, b) => priorityScore(b) - priorityScore(a))
```

High priority: high volume + low difficulty + short write time.

## For jrs-auto-repair

The gap analysis pattern to run once:
1. Search each service in `lib/shopInfo.ts` + "twin falls"
2. Find which services have no dedicated article in `lib/articles.ts`
3. Find which services have an article but no H2 covering "how much does X cost"
4. Find FAQs on competitors' pages that aren't in the jrs articles

Most valuable gaps for a local auto shop:
- Cost/price pages ("how much does X cost in Twin Falls")
- Symptom-diagnosis pages ("why is my car making a grinding noise when braking")
- "Should I repair or replace" decision pages
- Brand-specific advice ("best oil for Toyota Tacoma")

## Turning Gaps Into Assignments

For each gap, create a structured spec before writing:
```ts
interface ArticleSpec {
  slug: string
  primary_keyword: string
  secondary_keywords: string[]
  target_word_count: number
  intent: 'informational' | 'transactional' | 'navigational'
  required_sections: string[]  // H2s
  required_faq_questions: string[]
  competitor_url_to_beat: string
}
```

This spec is the input to batch article generation scripts or to `/seo-aeo-blog-writer`.
