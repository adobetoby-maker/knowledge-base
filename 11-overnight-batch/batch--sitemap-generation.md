# Batch: Sitemap Generation Jobs

## What This Covers

Automated sitemap generation and submission to search engines. Run on schedule after content changes or weekly for freshness.

## Static Sitemap in Next.js App Router

For smaller sites (<1000 URLs), generate at build time:

```ts
// app/sitemap.ts
import { MetadataRoute } from 'next'
import { articles } from '@/lib/articles'

export default function sitemap(): MetadataRoute.Sitemap {
  const BASE = 'https://jrsautorepair.com'

  const staticPages = [
    { url: BASE, lastModified: new Date(), changeFrequency: 'weekly' as const, priority: 1 },
    { url: `${BASE}/services`, lastModified: new Date(), changeFrequency: 'monthly' as const, priority: 0.9 },
    { url: `${BASE}/about`, lastModified: new Date(), changeFrequency: 'yearly' as const, priority: 0.7 },
    { url: `${BASE}/contact`, lastModified: new Date(), changeFrequency: 'yearly' as const, priority: 0.8 },
    { url: `${BASE}/blog`, lastModified: new Date(), changeFrequency: 'weekly' as const, priority: 0.8 },
  ]

  const articlePages = articles.map((article) => ({
    url: `${BASE}/blog/${article.slug}`,
    lastModified: new Date(article.date),
    changeFrequency: 'monthly' as const,
    priority: 0.6,
  }))

  return [...staticPages, ...articlePages]
}
```

## Dynamic Sitemap (Route Handler, For Large Sites)

```ts
// app/sitemap-blog.xml/route.ts
export async function GET() {
  const BASE = 'https://yoursite.com'

  const { data: articles } = await supabase
    .from('articles')
    .select('slug, updated_at')
    .eq('published', true)
    .order('updated_at', { ascending: false })

  const urls = articles?.map((a) => `
    <url>
      <loc>${BASE}/blog/${a.slug}</loc>
      <lastmod>${new Date(a.updated_at).toISOString().split('T')[0]}</lastmod>
      <changefreq>monthly</changefreq>
      <priority>0.6</priority>
    </url>
  `).join('') ?? ''

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`

  return new Response(xml, {
    headers: {
      'Content-Type': 'application/xml',
      'Cache-Control': 'public, max-age=3600',  // Cache 1 hour
    },
  })
}
```

## Sitemap Index (Multiple Sitemaps)

For sites with 50,000+ URLs, use a sitemap index:

```ts
// app/sitemap.xml/route.ts
const sitemapIndex = `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://yoursite.com/sitemap-static.xml</loc>
    <lastmod>${new Date().toISOString()}</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://yoursite.com/sitemap-blog.xml</loc>
    <lastmod>${new Date().toISOString()}</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://yoursite.com/sitemap-locations.xml</loc>
    <lastmod>${new Date().toISOString()}</lastmod>
  </sitemap>
</sitemapindex>`
```

## Overnight Job: Submit Sitemap to Search Engines

After content is generated overnight, ping search engines:

```ts
// scripts/submit-sitemap.ts
const SITEMAP_URL = 'https://yoursite.com/sitemap.xml'

async function submitSitemap() {
  const endpoints = [
    // Google (via IndexNow or Sitemap ping)
    `https://www.google.com/ping?sitemap=${encodeURIComponent(SITEMAP_URL)}`,
    // Bing/IndexNow
    `https://www.bing.com/ping?sitemap=${encodeURIComponent(SITEMAP_URL)}`,
  ]

  for (const endpoint of endpoints) {
    const res = await fetch(endpoint)
    console.log(`Ping ${endpoint}: ${res.status}`)
  }
}
```

Google's ping endpoint is deprecated but still works. Prefer **IndexNow** for faster indexing:

```ts
async function submitIndexNow(urls: string[]) {
  const response = await fetch('https://api.indexnow.org/indexnow', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
    body: JSON.stringify({
      host: 'yoursite.com',
      key: process.env.INDEXNOW_API_KEY!,  // Key file at /yoursite.com/<key>.txt
      keyLocation: `https://yoursite.com/${process.env.INDEXNOW_API_KEY}.txt`,
      urlList: urls.slice(0, 10000),  // Max 10k per request
    }),
  })

  return response.ok
}
```

IndexNow notifies Bing, Yandex, and Yahoo simultaneously with one request.

## Robots.txt

```ts
// app/robots.ts
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/admin/', '/api/', '/portal/'],
    },
    sitemap: 'https://yoursite.com/sitemap.xml',
  }
}
```

## Overnight Batch: Generate + Submit

```ts
// scripts/overnight-seo.ts
async function run() {
  // 1. Check for new/updated articles
  const newArticles = await getArticlesUpdatedSince(yesterday())

  if (newArticles.length === 0) {
    console.log('No new content — skipping sitemap submission')
    return
  }

  console.log(`${newArticles.length} new/updated articles`)

  // 2. Invalidate cached sitemap
  await fetch('https://yoursite.com/api/revalidate', {
    method: 'POST',
    headers: { 'x-api-key': process.env.REVALIDATE_SECRET! },
    body: JSON.stringify({ path: '/sitemap.xml' }),
  })

  // 3. Submit new URLs to IndexNow
  const urls = newArticles.map((a) => `https://yoursite.com/blog/${a.slug}`)
  await submitIndexNow(urls)

  console.log(`Submitted ${urls.length} URLs to IndexNow`)
}
```
