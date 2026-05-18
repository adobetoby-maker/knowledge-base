# SEO: robots.txt and Sitemap

## Overview

`robots.txt` tells crawlers which URLs to skip. `sitemap.xml` tells crawlers which URLs to prioritize and when they were last updated. Neither is strictly required, but both are expected by search engines and take 30 minutes to implement correctly.

## robots.txt

```
# /public/robots.txt
User-agent: *
Disallow: /api/          # API routes — not for indexing
Disallow: /admin/        # Admin dashboard
Disallow: /dashboard/    # User-specific authenticated pages
Disallow: /_next/        # Next.js internals
Disallow: /preview/      # CMS preview URLs

# Don't block static files
Allow: /_next/static/

Sitemap: https://example.com/sitemap.xml
```

## What to Disallow

| Path | Reason |
|---|---|
| `/api/` | API endpoints, not content pages |
| `/admin/` | Not for public indexing |
| `/dashboard/` | Authenticated, user-specific |
| `/?preview=` | CMS preview mode |
| `/search?q=*` | Faceted search creates infinite URL space |

**Never disallow** CSS, JS, or image files — Googlebot needs to render the page.

## Next.js robots.ts

```ts
// app/robots.ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

  return {
    rules: [
      {
        userAgent: '*',
        disallow: ['/api/', '/admin/', '/dashboard/', '/_next/'],
        allow: '/',
      },
      {
        userAgent: 'Googlebot',
        allow: '/',
        disallow: ['/api/', '/admin/'],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  }
}
```

## Sitemap (Static)

```ts
// app/sitemap.ts
import { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://example.com'

  const posts = await getAllPosts()
  const products = await getAllProducts()

  return [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1.0,
    },
    {
      url: `${baseUrl}/about`,
      lastModified: new Date('2024-01-01'),
      changeFrequency: 'yearly',
      priority: 0.8,
    },
    ...posts.map(post => ({
      url: `${baseUrl}/blog/${post.slug}`,
      lastModified: post.updatedAt,
      changeFrequency: 'weekly' as const,
      priority: 0.7,
    })),
    ...products.map(product => ({
      url: `${baseUrl}/products/${product.slug}`,
      lastModified: product.updatedAt,
      changeFrequency: 'daily' as const,
      priority: 0.9,
    })),
  ]
}
```

## Sitemap Index (for Large Sites)

When sitemap has >50,000 URLs or >50MB, split into multiple sitemaps:

```ts
// app/sitemap.ts — returns sitemap index
export default async function sitemap() {
  return [
    { url: 'https://example.com/sitemap-pages.xml', lastModified: new Date() },
    { url: 'https://example.com/sitemap-products.xml', lastModified: new Date() },
    { url: 'https://example.com/sitemap-blog.xml', lastModified: new Date() },
  ]
}

// app/sitemap-blog.ts — individual sitemap
export default async function blogSitemap() {
  const posts = await getAllPosts()
  return posts.map(post => ({
    url: `https://example.com/blog/${post.slug}`,
    lastModified: post.updatedAt,
  }))
}
```

## Priority Field Reality

`priority` in sitemaps is largely ignored by Google. The value is relative within your own site, not across the web. Don't spend time tuning it — Google determines priority itself.

`changeFrequency` is a hint, not a directive. Google crawls pages when it decides to, not when you say.

`lastModified` is the most useful field — accurate dates help Google understand what's actually been updated.

## Submitting to Search Console

After publishing your sitemap:
1. Google Search Console → Sitemaps → Add sitemap URL
2. Submit `https://example.com/sitemap.xml`
3. Monitor for errors

Resubmit manually after major content updates or URL changes.

## Key Rules

- `robots.txt` disallows must match the URL exactly (case-sensitive on Linux servers).
- Never `Disallow: /` in production — this blocks all crawling.
- Sitemap should only include indexable URLs — no 404s, 301s, or canonical duplicates.
- `lastModified` should be accurate, not set to today for all URLs — stale dates confuse crawlers.
- Image sitemaps and video sitemaps are separate — add them if images/videos need indexing.
