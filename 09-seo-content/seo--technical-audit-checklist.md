# Technical SEO Audit Checklist

## Core Web Vitals Targets

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP (Largest Contentful Paint) | <2.5s | 2.5–4s | >4s |
| INP (Interaction to Next Paint) | <200ms | 200–500ms | >500ms |
| CLS (Cumulative Layout Shift) | <0.1 | 0.1–0.25 | >0.25 |

These are measured at P75 (75th percentile of real user data). Good performance for the median user is not sufficient.

## Crawlability Checks

```
[ ] robots.txt exists and does not block important routes
[ ] sitemap.xml exists and is submitted to Google Search Console
[ ] No noindex on pages that should be indexed
[ ] Canonical tags point to the correct URL (no self-referencing canonicals that are wrong)
[ ] No orphaned pages (every indexed page is reachable by following links)
[ ] Internal links use relative paths or consistent protocol (no mixed http/https)
```

## URL Structure

```
[ ] Lowercase URLs only
[ ] Hyphens as word separators (not underscores)
[ ] Descriptive slugs with target keywords (not /article?id=123)
[ ] Trailing slash consistent (pick one; redirect the other)
[ ] No URL parameters on indexable pages (move filters to path segments)
```

## On-Page Structure

```
[ ] One H1 per page — contains the primary keyword
[ ] Heading hierarchy: H1 > H2 > H3 (no skipping levels)
[ ] Title tag: 50–60 characters, keyword near the front
[ ] Meta description: 150–160 characters, includes target keyword and CTA
[ ] Image alt text: descriptive, includes keyword where natural
[ ] No duplicate page titles or descriptions across the site
```

## Schema Markup (Structured Data)

Priority schema types by page type:

- **Local business pages:** `LocalBusiness` with address, phone, hours, geo coordinates
- **Blog posts:** `Article` or `BlogPosting` with author, datePublished, dateModified
- **Service pages:** `Service` with provider, area served, price range
- **FAQ content:** `FAQPage` with Question/Answer pairs
- **Review content:** `Review` or aggregate `AggregateRating`

All schema must validate at schema.org and Google's Rich Results Test with no errors.

## Page Speed — Next.js Specific

```
[ ] Images use next/image with width/height specified (prevents CLS)
[ ] Fonts loaded with next/font (eliminates FOUT and layout shift)
[ ] Large third-party scripts deferred with next/script strategy="lazyOnload"
[ ] Dynamic imports used for heavy client components (code splitting)
[ ] Static pages use generateStaticParams (SSG not SSR where possible)
[ ] API routes return Cache-Control headers for non-personalized responses
```

## Mobile Optimization

```
[ ] Viewport meta tag: <meta name="viewport" content="width=device-width, initial-scale=1">
[ ] Touch targets minimum 44×44px
[ ] No horizontal scroll on mobile
[ ] Font size minimum 16px for body text (prevents iOS zoom on focus)
[ ] Content not obscured by sticky headers on anchor navigation
```

## Internal Linking

```
[ ] Every core service/topic page linked from homepage or main nav
[ ] Blog posts link to relevant service pages (the "money pages")
[ ] Related articles section on blog posts
[ ] Breadcrumbs on deep content pages
[ ] No broken internal links (run link checker before deploy)
```

## Local SEO Additions (jrs-auto-repair, climb sites)

```
[ ] Google Business Profile claimed and complete
[ ] NAP (Name, Address, Phone) consistent across all pages and citations
[ ] City + state in H1 or first paragraph of homepage
[ ] LocalBusiness schema includes geo coordinates
[ ] Service area cities named in content (Twin Falls + surrounding Magic Valley cities)
[ ] Location page per major city served (if multiple locations)
```

## Monitoring

After any significant content or technical change:

1. Run Google PageSpeed Insights on the changed pages
2. Check Google Search Console for crawl errors (48h after deploy)
3. Verify schema markup in Rich Results Test
4. Check Core Web Vitals report in Search Console after 28 days of traffic

## Red Flags That Cause Ranking Drops

- Removing pages without 301 redirects
- Changing canonical URLs without redirects
- Adding noindex accidentally to important pages
- Changing URL structure (slugs) without redirects
- Blocking Googlebot in robots.txt
- Site speed regression >50% on LCP
