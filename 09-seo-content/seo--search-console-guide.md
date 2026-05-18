# Google Search Console Guide

Search Console is the direct channel between your site and Google's crawl/index systems. It surfaces what Google sees, not what you think Google sees — these often diverge. Use it proactively, not just when rankings drop.

## Submitting URLs for Indexing

New or updated pages should be submitted via the URL Inspection tool rather than waiting for Googlebot to recrawl organically. Use the "Request Indexing" button after inspection. This doesn't guarantee immediate indexing — it queues the URL for recrawl — but it accelerates indexing from days to hours for most sites.

For bulk URL submission, submit an updated sitemap via Sitemaps report → Submit. Sitemaps are the highest-priority signal for what you want indexed; pages not in the sitemap take longer to discover and index.

## Diagnosing Crawl Errors

The Pages report (Index Coverage) classifies URLs into: Indexed, Not Indexed (by reason), and Excluded. The reasons matter:

- **404 (Not Found)**: genuine missing pages. Redirect or recreate. 404s accumulate from deleted pages, restructured URLs, and external links pointing to old paths.
- **Soft 404**: the server returns 200 but the page content signals "nothing here" — empty search result pages, "no products found" pages, placeholder pages. Fix by redirecting to a relevant parent page or adding real content.
- **Crawled – currently not indexed**: Googlebot reached the page but chose not to index it. Usually signals thin content, near-duplicate content, or a low-quality signal. Improve the page's depth and utility.
- **Blocked by robots.txt**: Google is respecting your disallow rules. Confirm this is intentional.

## Core Web Vitals Report

The Core Web Vitals report shows LCP, INP (replaced FID in 2024), and CLS scores per URL group. It segments into mobile and desktop. Google uses field data (real user measurements), not lab data — a page that passes PageSpeed Insights may still fail field data if real users on slow connections experience poor LCP.

Focus on URL groups failing at the "Poor" threshold: LCP > 4s, INP > 500ms, CLS > 0.25. The report links to the affected URLs — open them in PageSpeed Insights for per-URL diagnostics.

## Search Analytics API for Data Export

The Search Console UI limits data to 1000 rows and 16 months. The Search Analytics API (`searchanalytics.query`) returns up to 25,000 rows per request with full historical data for your subscription window.

Use it to:
- Export click/impression/CTR/position data per query + page combination.
- Build rank tracking for specific keyword groups.
- Identify pages with high impressions but low CTR (title/meta description optimization candidates).
- Find queries where you appear at positions 8–15 (low-hanging fruit for content improvement).

Authenticate with a service account and cache results daily — the API has quota limits (200 requests per day per property for free).

## URL Inspection Tool

URL Inspection fetches the page as Googlebot and reports: index status, last crawl date, canonical URL Google selected (may differ from your declared canonical), mobile usability, and structured data validation.

Critical use: when your canonical URL differs from what Google selected, that means Google rejected your canonical declaration. Common reasons: low-quality page, content mismatch between declared and selected canonical, or internal linking pointing to the wrong URL variant.

## Key Rules

- Submit updated pages via URL Inspection + Request Indexing; don't wait for organic recrawl.
- Distinguish soft 404s (200 status, empty content) from hard 404s; each requires a different fix.
- "Crawled – currently not indexed" means content quality problem, not crawl problem — fix the page, not the robots.txt.
- Use Search Analytics API for any analysis requiring more than 1000 rows or more than 16 months of history.
- Check the Google-selected canonical in URL Inspection; if it differs from yours, Google is overriding you for a reason.
- INP replaced FID as a Core Web Vitals metric in March 2024; update monitoring accordingly.
