# SEO: Crawl Budget

## Overview

Crawl budget is the number of URLs Googlebot will crawl on your site in a given time period. Most small sites (under 10K pages) don't need to worry about it. Large sites, e-commerce with faceted search, and sites with pagination do. Wasted crawl budget on thin or duplicate pages means important pages get crawled less frequently.

## What Wastes Crawl Budget

| Issue | Impact |
|---|---|
| Faceted search URLs (`/shoes?color=red&size=10&brand=nike`) | Infinite URL space |
| Session IDs in URLs (`/page?sessionid=abc123`) | Millions of duplicate pages |
| Tracking parameters in internal links | Duplicate content |
| Low-value pages (empty categories, paginated past page 10) | Dilutes budget |
| Soft 404s (200 status but "no results" content) | Crawled but valueless |
| Internal redirects (especially chains) | Wastes slots following redirects |
| Duplicate content across www/non-www, http/https | Same content crawled twice |

## Diagnosing in Google Search Console

```
Search Console → Settings → Crawl Stats
Look for: crawl rate, pages crawled/day, average response time
```

High crawl rates with low indexing = crawl budget being wasted on low-value pages.

## Control Crawling with robots.txt

```
# Block parameter-based duplicate pages
User-agent: *
Disallow: /search?           # Faceted search variants
Disallow: /products?sort=    # Sort variations (same content)
Disallow: /products?filter=  # Filter variations

# Allow the canonical listing page
Allow: /products
Allow: /search
```

## Canonicals to Consolidate Crawl

```ts
// For paginated product listings, canonical page 2+ to page 1 (old approach)
// Current Google recommendation: separate canonicals per page, use rel="next"/"prev"
// (Google deprecated rel=next/prev but still uses it as a hint)

// For filter variants, canonical to the base URL
alternates: {
  canonical: `${baseUrl}/products/shoes`,  // All filter combos point here
}
```

## Noindex + Nofollow for Low-Value Pages

```ts
// Category pages with fewer than 3 products
if (products.length < 3) {
  return {
    robots: { index: false, follow: true },
    // follow: true to pass PageRank to product pages
  }
}

// Internal search results — often thin content
export const metadata = {
  robots: { index: false, follow: false },
}
```

## Pagination Strategy

```
/blog                    → Page 1 (indexable)
/blog?page=2             → Indexable with own canonical
/blog?page=3             → Indexable
...
/blog?page=50            → noindex (diminishing value)
```

```ts
export async function generateMetadata({ searchParams }) {
  const page = Number(searchParams?.page ?? 1)

  if (page > 20) {
    return { robots: { index: false, follow: false } }
  }

  return {
    alternates: {
      canonical: page === 1 ? `${baseUrl}/blog` : `${baseUrl}/blog?page=${page}`,
    },
  }
}
```

## Fix Soft 404s

A soft 404 is a page that returns 200 but contains "no results", "page not found", or empty content:

```ts
// Route handler for product page
export async function GET(req: Request, { params }) {
  const product = await getProduct(params.slug)

  if (!product) {
    // Hard 404 — tells Google to remove from index
    return new Response(null, { status: 404 })
  }

  // Don't return 200 with "product not found" HTML
  return renderProduct(product)
}
```

## Log Crawl Activity

Monitor which URLs bots are accessing via access logs to spot crawl waste:

```bash
# Parse Nginx/Cloudflare logs for Googlebot activity
grep -i "googlebot" /var/log/nginx/access.log \
  | awk '{print $7}' \
  | sort | uniq -c | sort -rn | head -50

# URLs visited most by Googlebot — high count on parameter URLs = wasted budget
```

## Key Rules

- Faceted search creates the most crawl budget waste — disallow URL parameter combinations in robots.txt.
- Never return 200 for "not found" content — always return a 404 or redirect.
- Canonical tags consolidate crawl credit but don't prevent crawling — robots.txt Disallow prevents the crawl.
- Crawl budget matters when indexing is slow or high-value pages aren't appearing in Google despite being live.
- Internal links to low-value pages spread crawl budget thin — don't link to empty search results or stub pages.
