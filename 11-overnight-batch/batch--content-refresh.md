# Batch: Overnight Content Refresh Pipeline

## Overview
Content that depends on external data sources (weather, prices, inventory, sports scores, exchange rates)
goes stale between user visits. Refreshing it in a scheduled batch rather than on every request prevents
external API rate limits, reduces latency for users, and provides a consistent snapshot of data across
the site without racing external API failures.

## Implementation

### Fetch Updated Data from External APIs
```ts
// batch/refresh-content.ts
import { db } from '../lib/db';
import { CDN } from '../lib/cdn';

const SOURCES = [
  { name: 'product-pricing', fetch: fetchProductPricing, table: 'product_prices' },
  { name: 'exchange-rates', fetch: fetchExchangeRates, table: 'exchange_rates' },
  { name: 'blog-feed', fetch: fetchPartnerBlogFeed, table: 'blog_posts' },
];

async function runContentRefresh() {
  const results: RefreshResult[] = [];

  for (const source of SOURCES) {
    try {
      const fresh = await source.fetch();
      const existing = await db.from(source.table).select('id, checksum');
      const changed = diffContent(existing, fresh);

      if (changed.updated.length + changed.created.length > 0) {
        await updateDatabase(source.table, changed);
        await CDN.purge(pathsForChanges(source.name, changed));
        results.push({ source: source.name, updated: changed.updated.length, created: changed.created.length });
      }
    } catch (error) {
      // Log but continue — one failing source shouldn't abort the entire refresh
      console.error(`Content refresh failed for ${source.name}:`, error);
      await db.insert('refresh_errors', { source: source.name, error: String(error), ts: new Date() });
    }
  }

  return results;
}
```

### Diff Against Stored Content (Only Update What Changed)
```ts
function diffContent(existing: StoredRecord[], fresh: FreshRecord[]): ContentDiff {
  const existingMap = new Map(existing.map(r => [r.id, r.checksum]));

  const created: FreshRecord[] = [];
  const updated: FreshRecord[] = [];
  const deleted: string[] = [];

  for (const record of fresh) {
    const checksum = computeChecksum(record);
    if (!existingMap.has(record.id)) {
      created.push({ ...record, checksum });
    } else if (existingMap.get(record.id) !== checksum) {
      updated.push({ ...record, checksum });
    }
    existingMap.delete(record.id);
  }

  // Remaining keys in existingMap were not in fresh data — deleted upstream
  for (const [id] of existingMap) {
    deleted.push(id);
  }

  return { created, updated, deleted };
}

function computeChecksum(record: object): string {
  const json = JSON.stringify(record, Object.keys(record).sort());
  return createHash('sha256').update(json).digest('hex').slice(0, 16);
}
```

### CDN Cache Invalidation for Changed Pages
```ts
// Invalidate only the pages that show changed content
async function invalidateCDN(changes: ContentDiff, contentType: string) {
  const paths: string[] = [];

  // Page that lists all records of this type
  paths.push(`/${contentType}`);

  // Individual pages for changed/new records
  for (const record of [...changes.created, ...changes.updated]) {
    paths.push(`/${contentType}/${record.slug}`);
  }

  // Sitemap (if records were added or removed)
  if (changes.created.length + changes.deleted.length > 0) {
    paths.push('/sitemap.xml');
  }

  // Cloudflare: purge by URL list
  await fetch('https://api.cloudflare.com/client/v4/zones/ZONE_ID/purge_cache', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${process.env.CF_API_TOKEN}` },
    body: JSON.stringify({ files: paths.map(p => `https://example.com${p}`) }),
  });
}
```

### RSS Update Generation
```ts
async function generateRSSUpdate(newItems: ContentRecord[]) {
  if (newItems.length === 0) return;

  const existingFeed = await parseFeed('https://example.com/rss.xml');
  const updatedFeed = prependItems(existingFeed, newItems.map(toFeedItem));
  const trimmed = trimFeedTo200Items(updatedFeed);

  await uploadToStorage('public/rss.xml', serializeFeed(trimmed));
  await CDN.purge(['/rss.xml']);
}
```

### Changelog Digest Email
```ts
async function sendChangelogDigest(changes: RefreshResult[]) {
  const totalChanges = changes.reduce((sum, r) => sum + r.updated + r.created, 0);
  if (totalChanges === 0) return;  // no email if nothing changed

  const subscribers = await db.from('digest_subscribers').select('email');
  await emailService.sendBatch(subscribers, {
    subject: `Content update: ${totalChanges} items refreshed`,
    template: 'changelog-digest',
    data: { changes },
  });
}
```

## Key Rules
- Compute checksums before diffing — never update a row just because the refresh ran; only update if content changed
- Failures in one source must not block refresh of other sources — catch errors per source and continue
- CDN invalidation should target specific paths, not blanket cache purges — blanket purges spike origin load
- Always record the refresh result (rows updated, errors) in a log table for debugging
- Rate limit external API calls — add delays between requests if the source doesn't support bulk fetch
- Store the `last_refreshed_at` timestamp per content type for stale-data alerting
- Never purge CDN before the database write succeeds — purge after commit to prevent serving stale data from origin
