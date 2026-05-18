# Sitemap Generation

## Next.js Built-In Sitemap

Next.js 15 can generate sitemaps automatically via a `sitemap.ts` file in the `app/` directory:

```typescript
// app/sitemap.ts
import type { MetadataRoute } from 'next'
import { articles } from '@/lib/articles'

const BASE_URL = 'https://jrsautorepair.com'

export default function sitemap(): MetadataRoute.Sitemap {
  // Static pages
  const staticPages: MetadataRoute.Sitemap = [
    {
      url: BASE_URL,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1.0,
    },
    {
      url: `${BASE_URL}/services`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.9,
    },
    {
      url: `${BASE_URL}/contact`,
      lastModified: new Date(),
      changeFrequency: 'yearly',
      priority: 0.7,
    },
    {
      url: `${BASE_URL}/blog`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.8,
    },
  ]
  
  // Dynamic pages from static data
  const articlePages: MetadataRoute.Sitemap = articles.map(article => ({
    url: `${BASE_URL}/blog/${article.slug}`,
    lastModified: new Date(article.date),
    changeFrequency: 'monthly',
    priority: 0.6,
  }))
  
  return [...staticPages, ...articlePages]
}
```

## Dynamic Sitemap from Database

For pages that live in Supabase:

```typescript
// app/sitemap.ts
import { createClient } from '@/lib/supabase/server'

export const revalidate = 3600  // regenerate hourly

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const supabase = await createClient()
  
  const { data: services } = await supabase
    .from('services')
    .select('slug, updated_at')
    .eq('published', true)
  
  const servicePages = (services ?? []).map(s => ({
    url: `${BASE_URL}/services/${s.slug}`,
    lastModified: new Date(s.updated_at),
    changeFrequency: 'monthly' as const,
    priority: 0.8,
  }))
  
  return [...staticPages, ...servicePages]
}
```

## robots.txt

Always include `robots.txt` pointing to the sitemap:

```typescript
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/admin/', '/portal/', '/api/'],
      },
    ],
    sitemap: 'https://jrsautorepair.com/sitemap.xml',
  }
}
```

## Sitemap Split (> 50,000 URLs)

Google limits sitemaps to 50,000 URLs. For large sites, use a sitemap index:

```typescript
// app/sitemap.ts — returns array of sitemaps
import type { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  // Next.js 15 handles splitting automatically when you return more than 50k entries
  // Just return all URLs — the framework handles the split
  return [...allUrls]
}
```

For very large dynamic sites, generate per-category sitemaps:

```
/sitemap.xml          → sitemap index
/sitemap/pages.xml    → static pages
/sitemap/articles.xml → article pages
/sitemap/services.xml → service pages
```

```typescript
// Generate separate sitemap files via route handlers
// app/sitemap/articles.xml/route.ts
export async function GET() {
  const articles = await fetchAllArticles()
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${articles.map(a => `
  <url>
    <loc>${BASE_URL}/blog/${a.slug}</loc>
    <lastmod>${a.date}</lastmod>
    <priority>0.6</priority>
  </url>`).join('')}
</urlset>`
  
  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml' }
  })
}
```

## Priority Guidelines

| Page Type | Priority | Change Frequency |
|---|---|---|
| Homepage | 1.0 | weekly |
| Service pages | 0.9 | monthly |
| Blog index | 0.8 | weekly |
| Blog posts | 0.6 | monthly |
| Contact, About | 0.7 | yearly |
| Admin, Portal | — | disallowed in robots.txt |

## Submit to Google

After deploying, submit via Google Search Console:
1. Verify ownership (HTML tag meta or DNS TXT record)
2. Sitemaps → Add sitemap URL
3. Inspect individual URLs to request indexing for priority pages

Don't submit sitemaps with `noindex` pages — Google ignores them but it wastes crawl budget.
