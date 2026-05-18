# SEO: E-Commerce SEO

## Overview
E-commerce sites face SEO challenges at scale: thousands of product pages with thin content, faceted navigation that creates millions of near-duplicate URLs, and category structures that often bury products too deep for crawlers to prioritize. Getting the architecture right from the start prevents crawl waste and duplicate content penalties that are painful to unwind later.

## Product Page Optimization

**Schema markup**
- `Product` schema with `name`, `description`, `image`, `sku`, `brand`
- `Offer` nested in Product: `price`, `priceCurrency`, `availability`, `url`
- `AggregateRating` nested in Product when reviews exist (enables star rich results)
- Use actual in-stock price — schema that mismatches visible content triggers manual action

**Content requirements**
- Unique product description — manufacturer copy = duplicate content risk (other sites have it too)
- At minimum: unique first 150 characters, then manufacturer description
- Image alt text: "[Product Name] [key attribute]" — not "product_image_1.jpg"
- User-generated reviews add unique, long-tail keyword content naturally

**URL structure**
- `/category/product-name` — not `/product?id=12345`
- Human-readable slugs: `blue-widget-12oz` not `sku-1234-bw12`
- Canonical on all product URLs (faceted navigation generates variants)

## Faceted Navigation (Critical Issue at Scale)

Faceted navigation (/products?color=blue&size=medium) creates combinatorial URL explosion. A 1000-product catalog with 10 filter attributes = potentially millions of crawlable URLs. Most are thin and near-duplicate.

**Solutions:**
- `noindex` on facet combination pages (most common — keeps them crawlable but not indexed)
- `canonical` facet URLs to the unfiltered category page
- Block crawling of filter parameters in robots.txt (use only if facet pages have zero ranking value)
- Allow indexing for facet combinations with real search demand ("red running shoes women's size 8") — these can rank

**Decision rule:** Index a facet page only if (a) it has keyword demand and (b) its content differs meaningfully from the parent category.

## Category Page Optimization

- Introductory text above the fold (100–200 words) targeting the category head term
- Don't bury text below 48 product thumbnails — Google weights above-fold content more heavily
- Breadcrumb navigation with `BreadcrumbList` schema
- Internal links from product pages back to their category
- Pagination: use `rel="next"` / `rel="prev"` or ensure all products are crawlable via sitemap

## Thin Content (Product Stubs)

Products with minimal description, no reviews, and no unique content score poorly. At scale, thin pages dilute overall site quality (Panda-era quality signals persist).

**Options for thin products:**
- Consolidate into "variant" pages (multiple sizes/colors on one URL, use structured data for variants)
- Noindex until content is added
- Block crawling via robots.txt if products are not meant to rank

## Pagination

- `rel="prev"` / `rel="next"` officially deprecated by Google (2019) but still used by Bing
- Include all paginated products in XML sitemap for crawl discovery
- Canonical on page 2+ of category: self-canonical (not to page 1 — they have different content)
- Use infinite scroll with fragment URLs (`#page=2`) only if Googlebot can crawl the fragments

## Key Rules

- Product schema mismatch (price in schema ≠ price on page) triggers manual action — keep in sync
- Faceted navigation is the #1 source of crawl waste on e-commerce sites — address it early
- Breadcrumb schema on every product and category page — it's low effort and improves SERP appearance
- Out-of-stock pages: keep the page, redirect only on permanent discontinuation (retains link equity)
- Image optimization is outsized for e-commerce — product images are often LCP elements
