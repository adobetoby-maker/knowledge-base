# Keeping Content Fresh for SEO

## Why Freshness Matters (and When It Doesn't)

Google's Query Deserves Freshness (QDF) algorithm boosts recency for queries where freshness is relevant: breaking news, product comparisons, "best X in 2026", statistics-heavy topics, evolving how-to content. For evergreen queries ("how does compound interest work"), freshness is irrelevant and updates don't provide a ranking boost.

Audit each article before updating: if the SERP for the target keyword shows results dated within the past 6 months, freshness matters. If the top results are 3–5 years old and ranking stably, the query doesn't have a freshness signal — spend your update time elsewhere.

## When to Update vs When to Create New

**Update the existing page when:**
- The URL has established authority (backlinks, impressions in Search Console)
- The topic hasn't changed fundamentally — only facts, stats, or examples have aged
- You're targeting the same keyword intent as before
- The article ranks in positions 5–20 and could move up with better content

**Create a new page when:**
- The existing page targets a different intent than what users now search
- The topic has shifted enough that the existing article would be contradicted by the update
- The existing URL has no authority worth preserving (0 backlinks, <100 impressions/month)
- You're targeting a meaningfully different query angle

A common mistake: creating a new article on a topic you already cover, splitting authority between two similar URLs. Consolidate instead — redirect the weaker URL to the stronger one after updating.

## `dateModified` Schema Property

Update `datePublished` and `dateModified` in your Article schema only when the content has actually changed substantively. Don't update the date as a trick to look fresh — Google can detect "date-only" changes with no content change.

```json
{
  "@type": "Article",
  "datePublished": "2024-03-15",
  "dateModified": "2026-05-17"
}
```

Also update the `<meta property="article:modified_time">` Open Graph tag and the `<time datetime="">` HTML element if present. Inconsistency across these signals reduces trust.

The `dateModified` in the sitemap `<lastmod>` element should match — update the sitemap after the page update.

## What to Update

In priority order:

1. **Statistics and data** — outdated stats are cited as the main reason users bounce from informational content. Update every specific number, percentage, or year-referenced figure.
2. **Product/tool recommendations** — check that linked products still exist, prices are roughly accurate, and recommended tools haven't been superseded.
3. **Screenshots and images** — UI changes make screenshots look like the content is abandoned. Replace screenshots that show outdated interfaces.
4. **Examples** — examples using deprecated technologies, dead companies, or old cultural references signal staleness even when the underlying advice is still correct.
5. **New sections** — if the topic has evolved to include something your article doesn't cover, add a new section rather than rewriting existing sections. Preserve URL history and user context.

What not to change: the URL, the H1, the primary keyword focus. These are anchor points for your existing authority and rankings.

## Adding Sections vs Rewriting

Prefer adding new sections over rewriting existing ones. Rewrites:
- Risk breaking the ranking signals the existing text already carries (exact-match phrases, semantic coverage)
- Make it impossible to audit what changed if rankings shift

New sections are additive — they expand coverage without disturbing what's working. Add an H2 section at the bottom for new information ("Updated: [Topic] in 2026") before deciding whether to integrate it into the main article flow.

Full rewrites are warranted only when the article's structure is fundamentally wrong for the current SERP or the primary angle needs to change.

## Tracking Freshness Score

Maintain a freshness score per article to prioritize update queue:

```
freshness_score = days_since_last_update 
                  × freshness_sensitivity  (1.0 for news, 0.5 for evergreen, 0.1 for timeless)
                  × traffic_value          (weekly organic impressions × avg_position_multiplier)
```

Articles with high traffic value + high freshness sensitivity + long time since update go first. Pure evergreen content with stable rankings doesn't need to be touched.

Review the update queue quarterly. Articles that consistently need updates on short cycles are signal that the topic belongs in a database-driven page (dynamic data), not a static article.

## Key Rules

- Only update `dateModified` when content has substantively changed; date-only updates without content changes are detectable and ineffective.
- Check SERP freshness before updating — not all queries have a freshness signal.
- Update statistics, tool links, and screenshots first; these produce the highest signal-to-effort ratio.
- Prefer adding new sections over rewriting existing ones; rewrites carry more risk than additions.
- Consolidate duplicate articles rather than updating both; split authority kills both pages.
- Track freshness score per article to prioritize the update queue; not all content needs the same update cadence.
