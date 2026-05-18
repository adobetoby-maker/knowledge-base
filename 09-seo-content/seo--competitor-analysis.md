# SEO: Competitor Content Analysis

## What This Solves

Competitor analysis identifies content gaps, ranking opportunities, and topical authority signals that keyword tools alone miss. The goal is not to copy competitors but to find topics they rank for where you can produce a more complete or better-targeted piece.

## Finding Competitors

**True SEO competitors** are sites ranking for your target keywords, not business competitors. A national chain's blog post can outrank a local business because it has more authority, not because it serves the same customers.

To identify SEO competitors:
1. Search your 5 most important keywords
2. Note which domains appear in top 10 results across multiple keywords
3. Those domains are your SEO competitors regardless of whether they compete for customers

## Content Gap Analysis

Find topics competitors rank for that you don't:

```ts
// Conceptual process — implement with a crawl tool or Ahrefs/SEMrush export
interface ContentGapResult {
  keyword: string
  competitor_rank: number
  your_rank: number | null
  search_volume: number
  difficulty: number
}

// Steps:
// 1. Export: competitor's ranking keywords from SEO tool
// 2. Export: your ranking keywords
// 3. Subtract your keywords from competitor's list
// 4. Filter: volume > 100, difficulty < 40
// 5. Sort by: (volume / difficulty) desc — best opportunity first
```

## Article Coverage Comparison

For each topic you plan to write, check the top-ranking article:
1. What word count are they hitting? (Match or exceed for comprehensive topics)
2. What H2/H3 sections do they have? (Cover all + add your differentiation)
3. What questions do their FAQs answer? (Add to your FAQ section)
4. What schema markup do they use? (FAQ, HowTo, LocalBusiness)

## Local Business Competitor Analysis (jrs-auto-repair pattern)

```ts
// For local businesses, competitors are geographically bounded
const LOCAL_KEYWORDS = [
  'auto repair twin falls id',
  'mechanic twin falls idaho',
  'oil change twin falls',
  'transmission repair twin falls',
]

// Check top 10 Google results for each keyword
// Document: domain, title, word count, has schema markup, has reviews
// Find: topics covered by the #1 ranking local competitor that you haven't covered
```

For local SEO, the most actionable gap is usually:
- Service pages they have that you don't
- City/neighborhood pages they've built
- "Near me" intent pages

## Differentiating From Competitors

Don't just match competitor content — add:
- **First-hand expertise signals**: "In our 13 years in Twin Falls..."
- **Local specifics**: Road conditions, common vehicle problems in the area
- **Deeper how-to coverage**: Step-by-step vs competitor's vague overview
- **FAQ coverage of questions they skip**: Often the long-tail traffic opportunity

## Content Quality Signals to Check

On competitor pages:
- Last updated date (stale = opportunity to create fresher content)
- Author credentials listed?
- External citations/sources linked?
- User comments or reviews present?
- Breadcrumb navigation?
- Related content linked?

If their page is weak on these, a well-structured piece with these signals can outrank it.

## Monitoring Competitor New Content

Set a Google Alert for: `site:competitor.com` to get notified when they publish new pages. Or check their sitemap periodically:

```bash
# Fetch competitor sitemap to find recently added pages
curl -s https://competitor.com/sitemap.xml | grep -oP '(?<=<loc>)[^<]+' | head -50
```

## Gap to Content Pipeline

For each gap identified:
1. Is the search intent informational (blog post) or transactional (service page)?
2. Does a similar article already exist in `lib/articles.ts`? If so, update it.
3. If not, create a new entry targeting that specific keyword
4. Include the exact keyword in: title, first 100 words, one H2, meta description

## When to Prioritize Gaps

Prioritize content gaps when:
- Volume > 200/month AND difficulty < 35 (quick wins)
- Competitor is a national site (harder to match for broad terms, but local variation is easy to win)
- The gap is for a service you actually offer (don't create content for services you don't do)
- You have first-hand expertise to differentiate
