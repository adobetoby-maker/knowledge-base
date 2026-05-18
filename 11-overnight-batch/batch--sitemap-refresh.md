# Batch: Sitemap Regeneration

## Overview
A sitemap is only useful if it accurately reflects the current state of the site. Manually maintained sitemaps go stale — new pages are missed, deleted pages remain, `lastmod` dates are wrong. Nightly regeneration from the database ensures accuracy, and the `lastmod` field — derived from actual `updated_at` timestamps — gives search engines accurate freshness signals. Stale `lastmod` dates cause unnecessary recrawl or missed recrawl, both of which hurt SEO.

## Implementation

### Sitemap Spec Constraints
- Maximum 50,000 URLs per sitemap file
- Maximum 50 MB per file
- Multiple sitemap files require a sitemap index file
- `lastmod` should be ISO 8601 format (`YYYY-MM-DD` or full datetime)

### Query: Generate URL Set from DB
```sql
-- Products sitemap: all active, non-deleted products
SELECT
  'https://yoursite.com/products/' || slug AS url,
  updated_at AS lastmod,
  0.9 AS priority,
  'weekly' AS changefreq
FROM products
WHERE deleted_at IS NULL AND status = 'active'
ORDER BY updated_at DESC;

-- Blog posts
SELECT
  'https://yoursite.com/blog/' || slug AS url,
  published_at AS lastmod,
  0.7 AS priority,
  'monthly' AS changefreq
FROM posts
WHERE published_at IS NOT NULL AND deleted_at IS NULL
ORDER BY published_at DESC;

-- Static pages (hardcoded)
-- homepage: priority 1.0, weekly
-- /about, /pricing: priority 0.8, monthly
```

### Sitemap XML Generation
```ts
import { createGzip } from 'zlib';
import { Readable } from 'stream';

interface SitemapEntry {
  url: string;
  lastmod: Date;
  changefreq: 'always' | 'hourly' | 'daily' | 'weekly' | 'monthly' | 'yearly' | 'never';
  priority: number;
}

function generateSitemapXML(entries: SitemapEntry[]): string {
  const urls = entries.map(e => `
  <url>
    <loc>${escapeXML(e.url)}</loc>
    <lastmod>${e.lastmod.toISOString().split('T')[0]}</lastmod>
    <changefreq>${e.changefreq}</changefreq>
    <priority>${e.priority.toFixed(1)}</priority>
  </url>`).join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls}
</urlset>`;
}

function escapeXML(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}
```

### Sitemap Index (for Multiple Files)
```ts
function generateSitemapIndex(sitemaps: { url: string; lastmod: Date }[]): string {
  const items = sitemaps.map(s => `
  <sitemap>
    <loc>${s.url}</loc>
    <lastmod>${s.lastmod.toISOString().split('T')[0]}</lastmod>
  </sitemap>`).join('');

  return `<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${items}
</sitemapindex>`;
}
```

### Upload to S3/R2 for CDN Serving
```ts
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const s3 = new S3Client({ region: 'us-east-1' });

async function uploadSitemap(content: string, key: string) {
  // Gzip for faster serving
  const compressed = await gzip(Buffer.from(content, 'utf8'));

  await s3.send(new PutObjectCommand({
    Bucket: process.env.S3_SITEMAP_BUCKET,
    Key: key,
    Body: compressed,
    ContentType: 'application/xml',
    ContentEncoding: 'gzip',
    CacheControl: 'public, max-age=86400', // CDN caches for 1 day
  }));
}

function gzip(input: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const { gzip } = require('zlib');
    gzip(input, (err: Error, result: Buffer) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}
```

### Ping Google Search Console
```ts
async function pingSearchConsole(sitemapUrl: string) {
  const pingUrl = `https://www.google.com/ping?sitemap=${encodeURIComponent(sitemapUrl)}`;
  const res = await fetch(pingUrl, { signal: AbortSignal.timeout(10_000) });

  if (res.ok) {
    console.log(`Pinged Google: ${sitemapUrl}`);
  }
}
```

### Full Job Orchestrator
```ts
export async function regenerateSitemaps() {
  const now = new Date();

  // Fetch all URL sets from DB
  const [products, posts, staticPages] = await Promise.all([
    getProductURLs(),
    getBlogURLs(),
    getStaticPageURLs(),
  ]);

  // Split large sets into chunks of 50k
  const allURLs = [...staticPages, ...posts, ...products];
  const chunks = chunkArray(allURLs, 49_000); // leave buffer below 50k

  const uploadedSitemaps: { url: string; lastmod: Date }[] = [];

  for (let i = 0; i < chunks.length; i++) {
    const xml = generateSitemapXML(chunks[i]);
    const key = chunks.length === 1 ? 'sitemap.xml' : `sitemap-${i + 1}.xml`;
    const publicUrl = `${BASE_URL}/${key}`;

    await uploadSitemap(xml, key);
    uploadedSitemaps.push({ url: publicUrl, lastmod: now });
  }

  // Generate sitemap index if multiple files
  if (uploadedSitemaps.length > 1) {
    const indexXml = generateSitemapIndex(uploadedSitemaps);
    await uploadSitemap(indexXml, 'sitemap_index.xml');
    await pingSearchConsole(`${BASE_URL}/sitemap_index.xml`);
  } else {
    await pingSearchConsole(`${BASE_URL}/sitemap.xml`);
  }

  console.log(`Regenerated ${chunks.length} sitemap(s) with ${allURLs.length} URLs`);
}
```

## Key Rules
- Exclude `noindex` pages from the sitemap — submitting pages you've told search engines to ignore wastes crawl budget.
- `lastmod` must come from the actual `updated_at` DB column — hardcoded or estimated dates are worse than omitting `lastmod` entirely.
- Gzip sitemaps before uploading — gzipped sitemaps are supported and reduce transfer size by ~80%.
- Split at 49,000 URLs (not 50,000) — leave buffer for rows added between query and upload.
- Ping Search Console after regeneration — it accelerates recrawl of changed URLs.
- Store sitemaps in S3/R2 + CDN, not on the application server — sitemap requests from crawlers can be high-volume.
- Include `changefreq` accurately — setting everything to `daily` trains search engines to ignore it.
