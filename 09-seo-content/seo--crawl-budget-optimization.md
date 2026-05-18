# SEO: Crawl Budget Optimization

## Overview
Googlebot allocates a finite crawl budget to each site — a combination of crawl rate (how fast it crawls) and crawl demand (how many URLs it considers worth crawling). For small sites (< 1000 pages), crawl budget is rarely a concern. For large sites (10K+ pages), wasted crawl budget means important pages go undiscovered or are crawled infrequently. The goal is ensuring Googlebot spends its budget on pages worth indexing.

## Where Crawl Budget Is Wasted

**Faceted navigation / URL parameters**
The most common source of crawl waste on e-commerce and real estate sites. A `/products?color=red&size=M&sort=price` URL is a new URL to Googlebot even if the content barely differs from `/products?color=blue&size=L`.

**Infinite scroll / paginated content**
If pagination URLs are accessible (not loaded via JS that Googlebot doesn't render), `/page/2`, `/page/3`... `/page/847` all get crawled — consuming budget for near-duplicate content.

**Session IDs and tracking parameters**
URLs containing `?sessionid=abc123`, `?utm_source=newsletter`, `?ref=email` are treated as unique URLs. Each is a new crawl target.

**Soft 404s**
Pages that return 200 status but display "no results" or "page not found" content — Googlebot treats them as crawlable but worthless pages.

**Low-quality or thin pages**
Tag archives with 1 post, author pages with no content, empty category pages — crawled repeatedly, never ranked.

## Solutions by Problem Type

**URL parameters**: Declare parameter behavior in Google Search Console (URL Parameters tool, though being deprecated) OR use `rel="canonical"` pointing to the canonical unfiltered URL. Best practice: combine both.

**Faceted navigation**:
- `noindex` on generated facet pages (crawled but excluded from index — doesn't fully solve crawl waste)
- `robots.txt Disallow` on parameter patterns (stops crawling entirely — best for crawl budget, but also prevents any facet pages from indexing)
- Decision: if zero facet pages should rank → Disallow; if some should rank → noindex + canonical

**Session IDs**: Never generate session IDs in URLs. Use cookies. If legacy system already does this, Disallow in robots.txt.

**Soft 404s**: Return 404 or 410 HTTP status on "no results" pages. Audit with Screaming Frog or GSC Coverage report.

**Low-quality pages**: `noindex` + `nofollow` on tag archives, empty categories, author pages with < 5 posts.

## XML Sitemap Hygiene

The sitemap is a crawl request — only include pages you want crawled and indexed:
- Remove noindex pages from sitemap
- Remove 404 pages from sitemap immediately
- Keep `<lastmod>` accurate (stale dates cause Googlebot to deprioritize recrawl)
- Submit sitemap in GSC and monitor "Excluded" URLs report for surprises

## Robots.txt Strategy

Disallow paths that should never be crawled:
```
Disallow: /search
Disallow: /filter?
Disallow: /admin/
Disallow: /checkout/
Disallow: /account/
Disallow: /*?sort=
Disallow: /*?page=
```

Important: robots.txt blocks crawling, not indexing. A page with inbound links can still appear in the index with "No information is available for this page." Use noindex for indexing control; use robots.txt for crawl efficiency.

## Monitoring

- **GSC Coverage report**: shows discovered URLs, indexed, excluded — review monthly
- **GSC Crawl Stats report**: shows Googlebot response codes, crawl rate, top crawled URLs
- **Log file analysis**: most accurate picture of what Googlebot is actually crawling (requires server log access)

## Key Rules

- Crawl budget only matters at scale (> 10K pages) — don't over-engineer for small sites
- Robots.txt Disallow ≠ noindex — they have different effects
- XML sitemap should contain only indexable pages — not a complete site map
- Fix soft 404s: return proper HTTP 404/410 status codes
- Log file analysis is the ground truth — GSC crawl stats are approximate
