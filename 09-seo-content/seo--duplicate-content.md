# Duplicate Content — Causes and Resolution

## Why Duplicate Content Costs Rankings

Google doesn't penalize duplicate content — it *consolidates* it. When Google finds multiple URLs serving substantially similar content, it picks one to index and suppresses the others. The problem is that Google may not pick the URL you want. The suppressed URL loses all ranking ability and accrued link equity may be split across variants instead of concentrated on the canonical.

## Canonical Tags

The `<link rel="canonical" href="...">` tag tells Google your preferred URL. Self-referencing canonicals (a page pointing to itself) are best practice — they prevent any other variant of that URL (with trailing slash, UTM params, etc.) from being treated as a separate page.

```html
<!-- Every page should have a self-referencing canonical -->
<link rel="canonical" href="https://example.com/services/auto-repair" />
```

Rules for canonicals:
- Always use the absolute URL including protocol and domain
- The canonical URL must return 200 — canonicals pointing to 301s or 404s are ignored
- Use canonical for content syndication: if your blog post is republished elsewhere, the other site should canonical back to yours
- Don't use canonical as a substitute for a redirect — if you've changed a URL, both 301 and canonical are appropriate; if the old URL still serves content, add the canonical; if not, 301 only

## hreflang for Language Variants

Translated pages are not duplicate content if `hreflang` is implemented correctly. Without hreflang, Google may treat `/en/about` and `/fr/about` as duplicates (same topic, similar structure). See `seo--hreflang-implementation.md` for the full implementation.

## URL Parameter Handling

URL parameters create duplicate content when they don't change the substantive content (session IDs, tracking params, sort order, filter state). Solutions:

**Preferred: Canonical tag on parameterized URLs** pointing to the clean URL:
```html
<!-- On /products?sort=price&session=abc123 -->
<link rel="canonical" href="https://example.com/products" />
```

**Alternative: Block in robots.txt** for parameters that shouldn't be crawled at all:
```
User-agent: *
Disallow: /*?session=
```

Use Google Search Console's URL Parameters tool (now deprecated but still visible) to check if Google is crawling parameters unnecessarily. For Next.js, set `generateStaticParams` to only generate canonical URLs and redirect parameterized variants to canonical form.

## www vs non-www

Pick one. Redirect the other. This is the most common "duplicate homepage" issue.

```typescript
// next.config.ts — redirect www to non-www
redirects: async () => [{
  source: '/:path*',
  has: [{ type: 'host', value: 'www.example.com' }],
  destination: 'https://example.com/:path*',
  permanent: true,
}]
```

Both must redirect to the exact same canonical — including trailing slash consistency. A 301 chain (www → non-www → with-trailing-slash) splits the redirect credit.

## HTTP vs HTTPS

All HTTP URLs should 301 redirect to HTTPS. Modern hosting (Vercel, Cloudflare) handles this automatically. Verify it's active — a missed HTTP → HTTPS redirect means Google sees duplicate non-secure versions of every page.

## Pagination Duplicate Handling

Paginated content (`/blog`, `/blog?page=2`, `/blog/page/2`) creates near-duplicate listing pages. Google's recommended approach (after deprecating `rel="next/prev"`):
- Do not noindex paginated pages — they are distinct pages with distinct content
- Self-canonical each page to itself (not to page 1)
- Ensure each paginated page has a unique `<title>` (e.g., "Blog — Page 2 | Brand") and unique meta description
- Use `rel="next"` and `rel="prev"` in HTML head anyway — while Google officially deprecated them, Bing and others still use them

Do not canonical paginated pages to page 1 — this signals to Google that pages 2+ have no standalone value, which causes indexed content on those pages to be suppressed.

## Key Rules

- Self-referencing canonicals on every page are non-negotiable — they close off URL variation attacks (UTM params, casing differences)
- Canonical tags must point to 200-status URLs — canonicals to redirected URLs are often ignored by Google
- www/non-www redirect must be a single 301, not a chain — validate the redirect chain with `curl -L -I`
- Don't canonical paginated pages to page 1 — let each page be indexed independently with a unique title
- HTTP → HTTPS redirect is typically automatic on Vercel/Cloudflare but verify it; HTTP duplicates still appear in crawls if the redirect is misconfigured
