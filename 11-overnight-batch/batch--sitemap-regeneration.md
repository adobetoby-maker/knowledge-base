# Nightly Sitemap Rebuild for Large Sites

## Why Nightly Rebuild Instead of On-Demand

On-demand sitemap generation requires a DB query every time Googlebot or any other crawler hits `/sitemap.xml`. For large sites (10k+ URLs), this is an expensive query that runs frequently. A pre-generated static file served from CDN or local disk is orders of magnitude faster and doesn't put DB load under crawler spikes.

Nightly rebuild is sufficient for most content — Google crawls frequently-updated content regardless of sitemap timestamps. The sitemap is a hint, not a command.

## XML Sitemap Structure

Each URL entry:
```xml
<url>
  <loc>https://example.com/blog/some-post</loc>
  <lastmod>2026-05-17</lastmod>
  <changefreq>weekly</changefreq>
  <priority>0.7</priority>
</url>
```

`lastmod` is the most useful field — use the record's `updated_at` from your DB, formatted as `YYYY-MM-DD`. Google uses this to prioritize recrawling.

`changefreq` is largely ignored by Google but useful as documentation. Use: `daily` for homepage/category pages, `weekly` for blog posts, `monthly` for static pages.

`priority` is also largely ignored by Google for cross-site comparisons (it's relative within a site). Use: 1.0 for homepage, 0.8 for top-level category pages, 0.6–0.7 for standard pages, 0.4 for paginated/filtered pages.

Omit `changefreq` and `priority` if you can't set them meaningfully — meaningless values don't help.

## 50k URL Limit and Sitemap Index

A single sitemap file supports a maximum of 50,000 URLs and must not exceed 50MB uncompressed. Above this, use a sitemap index file.

Sitemap index (`/sitemap.xml`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <sitemap>
    <loc>https://example.com/sitemap-blog.xml</loc>
    <lastmod>2026-05-18</lastmod>
  </sitemap>
  <sitemap>
    <loc>https://example.com/sitemap-products.xml</loc>
    <lastmod>2026-05-18</lastmod>
  </sitemap>
</sitemapindex>
```

Partition child sitemaps by content type (`sitemap-blog.xml`, `sitemap-products.xml`, `sitemap-pages.xml`) rather than by number (sitemap-1.xml, sitemap-2.xml). Type-based partitioning makes it easier to regenerate only changed content types and to inspect individual sitemaps in Search Console.

## Generation Process

```js
async function generateBlogSitemap() {
  const posts = await db.query(`
    SELECT slug, updated_at FROM blog_posts
    WHERE published = true
    ORDER BY updated_at DESC
  `);
  
  const urls = posts.rows.map(post => ({
    loc: `https://example.com/blog/${post.slug}`,
    lastmod: post.updated_at.toISOString().split('T')[0],
    changefreq: 'weekly',
    priority: 0.7,
  }));
  
  const xml = buildSitemapXml(urls); // use a library: 'sitemap' npm package
  await fs.writeFile('./public/sitemap-blog.xml', xml);
  await uploadToCDN('./public/sitemap-blog.xml', 'sitemap-blog.xml');
}
```

Use the `sitemap` npm package for XML generation — it handles escaping, encoding, and validation correctly. Don't hand-roll XML.

## Pinging Google After Update

After regenerating, notify Google via the Indexing API or the legacy ping endpoint:

```js
// Legacy ping (still works, less reliable than Search Console)
await fetch(
  `https://www.google.com/ping?sitemap=https://example.com/sitemap.xml`
);
```

The Indexing API (for sites with job posting or live stream schemas) provides confirmation. For standard sites, the ping is sufficient. Run it once after the sitemap index is updated, not after each child sitemap.

Also verify the sitemap URL in Google Search Console — this gives you crawl stats and error reporting.

## Excluding Non-Canonical URLs

Never include in sitemaps:
- Pages with `noindex` robots meta tag
- Paginated pages beyond page 2 (unless they have unique canonical content)
- URL parameter variants (`?sort=price`, `?ref=email`)
- Duplicate content with canonical pointing elsewhere
- 404, redirect (301/302), or draft pages

Including these wastes crawl budget and dilutes sitemap authority. Query only `published = true` and `canonical IS NULL OR canonical = own_url` records.

## Key Rules

- Pre-generate sitemaps as static files; never generate on-demand for large sites.
- Split into child sitemaps by content type when URL count exceeds 50k.
- Use `updated_at` from DB as `lastmod`; don't hardcode or fake timestamps — Google detects and ignores them.
- Never include noindex, redirect, paginated, or parameter URLs in sitemaps.
- Ping Google once after the sitemap index update; verify via Search Console for crawl error visibility.
- Use the `sitemap` npm package for XML generation; hand-rolled XML breaks on special characters in URLs/titles.
