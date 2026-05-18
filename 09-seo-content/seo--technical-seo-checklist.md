# SEO: Technical SEO Audit Checklist

## Overview
Technical SEO is the foundation that allows search engines to discover, crawl, interpret, and index your content. Without it, great content remains invisible. Technical issues compound — a misconfigured robots.txt can silently block thousands of pages, and duplicate content splits ranking signals across URLs, diluting authority for all of them.

## Crawlability

**robots.txt**
- Exists at domain root (`/robots.txt`)
- Does not accidentally block CSS, JS, or media files (Googlebot renders pages — blocked assets = partial render)
- Disallow directives are intentional (filter pages, session URLs, admin paths)
- Sitemap URL is declared in robots.txt

**XML Sitemap**
- All indexable pages present; no noindex pages included
- `<lastmod>` dates are accurate (stale = signal to ignore)
- Sitemap index for sites >50K pages
- Submitted to Google Search Console and Bing Webmaster Tools
- Updated automatically on publish/unpublish

**Crawl depth**
- No important pages more than 3 clicks from homepage
- Pagination chains are finite and navigable
- No orphan pages (pages with zero internal links)

## Indexability

**noindex directives**
- Applied intentionally: tag archives, search results, filter pages, thank-you pages, staging environments
- Not accidentally applied to key landing pages (verify via GSC Coverage report)
- Consistent between `<meta name="robots">` and `X-Robots-Tag` HTTP header

**Canonical tags**
- Every page has a self-referencing canonical (including the canonical itself)
- Paginated pages canonical to page 1 only if truly duplicate; otherwise self-canonical
- HTTP and HTTPS versions canonicalize to HTTPS
- www and non-www canonicalize to preferred variant
- Canonical always matches the URL that gets the link equity (don't canonical to a 301)

## Duplicate Content

- HTTP vs HTTPS — only one serves content; other 301 redirects
- www vs non-www — only one serves content; other 301 redirects
- Trailing slash consistency (`/page` vs `/page/`) — pick one, redirect the other
- URL parameter handling declared in GSC (or use canonical)
- Printer-friendly, AMP, mobile pages use canonical pointing to canonical URL

## HTTPS

- All pages serve over HTTPS (no mixed content warnings)
- HSTS header set
- Certificate auto-renews
- Internal links use HTTPS URLs (not HTTP)
- Canonical tags use HTTPS

## Mobile-Friendliness

- Responsive design (single URL for desktop/mobile, not m.subdomain)
- No horizontal scroll on 375px viewport
- Touch targets ≥ 48px
- Font size ≥ 16px body text
- No intrusive interstitials (popups that block content on mobile on load)

## Structured Data (JSON-LD)

- Schema present and valid: Article, Product, LocalBusiness, BreadcrumbList as relevant
- No mismatches between schema content and visible page content (Google penalizes this)
- Test with Google Rich Results Test before deploying
- No schema on noindex pages (wasted signal)

## Core Web Vitals

- LCP < 2.5s (measure with field data from CrUX, not just Lighthouse)
- INP < 200ms
- CLS < 0.1
- Measured for both mobile and desktop
- Real-user data in GSC Core Web Vitals report — lab data alone is insufficient

## Key Rules

- Fix crawl issues before content issues — no point optimizing content that can't be indexed
- One canonical URL per piece of content — pick it and make everything point there
- Audit technical health quarterly; new features often introduce regressions
- Always verify changes in GSC after deploying (coverage, indexing, manual actions)
- Staging environments must block all crawlers via robots.txt AND noindex headers
