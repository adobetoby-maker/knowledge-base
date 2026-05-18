# Batch Job: Index Rebuilding

## Overview

Search indexes, cached aggregates, denormalized counts, and materialized views drift over time due to missed events, bugs, or migrations. Overnight rebuilds correct drift without impacting daytime query performance. Rebuild into a staging table, then swap atomically — never rebuild in place on a live index.

## Search Index Rebuild (Postgres Full-Text)

```ts
async function rebuildSearchIndex(): Promise<void> {
  logger.info('Starting search index rebuild')

  // Update tsvector column from source fields
  await db.execute(sql`
    UPDATE products
    SET search_vector = to_tsvector('english',
      coalesce(name, '') || ' ' ||
      coalesce(description, '') || ' ' ||
      coalesce(category, '') || ' ' ||
      coalesce(brand, '')
    )
    WHERE search_vector IS NULL
       OR updated_at > last_indexed_at
  `)

  logger.info('Search index rebuild complete')
}
```

## Materialized View Refresh

```sql
-- Create materialized view
CREATE MATERIALIZED VIEW product_stats AS
SELECT
  p.id,
  p.name,
  COUNT(r.id) AS review_count,
  AVG(r.rating)::NUMERIC(3,2) AS avg_rating,
  COUNT(DISTINCT o.user_id) AS buyer_count,
  SUM(oi.quantity) AS total_sold
FROM products p
LEFT JOIN reviews r ON r.product_id = p.id
LEFT JOIN order_items oi ON oi.product_id = p.id
LEFT JOIN orders o ON o.id = oi.order_id AND o.status = 'completed'
GROUP BY p.id, p.name;

CREATE UNIQUE INDEX ON product_stats(id);
```

```ts
// Refresh in batch job (CONCURRENTLY to avoid locking reads)
async function refreshProductStats(): Promise<void> {
  await db.execute(sql`REFRESH MATERIALIZED VIEW CONCURRENTLY product_stats`)
  logger.info('product_stats refresh complete')
}
```

## Denormalized Count Correction

Counts drift when increment/decrement fail (crashes, transaction rollbacks):

```ts
async function recalculateDenormalizedCounts(): Promise<{ corrected: number }> {
  // Find products where stored count doesn't match actual count
  const drifted = await db.execute(sql`
    SELECT
      p.id,
      p.review_count AS stored_count,
      COUNT(r.id) AS actual_count
    FROM products p
    LEFT JOIN reviews r ON r.product_id = p.id
    GROUP BY p.id, p.review_count
    HAVING p.review_count != COUNT(r.id)
  `)

  if (drifted.length > 0) {
    logger.warn({ count: drifted.length }, 'Correcting drifted review counts')

    for (const row of drifted) {
      await db.update(products)
        .set({ reviewCount: Number(row.actual_count) })
        .where(eq(products.id, row.id as string))
    }
  }

  return { corrected: drifted.length }
}
```

## Algolia/Meilisearch Index Sync

Sync DB records to external search index, handling any events that were missed:

```ts
async function syncSearchIndex(): Promise<void> {
  // Get the last successful sync timestamp
  const lastSync = await redis.get('search-index-last-sync')
    .then(ts => ts ? new Date(ts) : subDays(new Date(), 7))

  const changed = await db.query.products.findMany({
    where: or(
      gte(products.updatedAt, lastSync),
      gte(products.createdAt, lastSync),
    ),
    columns: { id: true, name: true, description: true, price: true, category: true, updatedAt: true },
  })

  const deleted = await db.query.products.findMany({
    where: and(
      gte(products.deletedAt, lastSync),
      isNotNull(products.deletedAt),
    ),
    columns: { id: true },
  })

  if (changed.length > 0) {
    // Batch upsert to Algolia/Meilisearch
    await searchIndex.saveObjects(changed.map(p => ({ objectID: p.id, ...p })))
    logger.info({ count: changed.length }, 'Synced to search index')
  }

  if (deleted.length > 0) {
    await searchIndex.deleteObjects(deleted.map(p => p.id))
    logger.info({ count: deleted.length }, 'Removed from search index')
  }

  await redis.set('search-index-last-sync', new Date().toISOString())
}
```

## Blue/Green Index Swap

For full rebuilds that take minutes (no incremental option):

```ts
async function rebuildSearchIndexBlueGreen(): Promise<void> {
  const timestamp = Date.now()
  const stagingIndex = `products_${timestamp}`

  // Build into staging index
  const allProducts = await db.query.products.findMany({ where: isNull(products.deletedAt) })
  await algolia.initIndex(stagingIndex).saveObjects(
    allProducts.map(p => ({ objectID: p.id, ...p }))
  )

  // Atomically swap aliases
  await algolia.operationIndex(stagingIndex, 'move', 'products')
  // Old index is gone; 'products' now points to fresh data

  logger.info({ index: stagingIndex, count: allProducts.length }, 'Index rebuild complete')
}
```

## Key Rules

- `CONCURRENTLY` on materialized view refresh avoids table locks — without it, reads block during refresh.
- Log the number of corrected records — zero corrections over time means your counters are reliable; sudden spikes indicate a bug.
- Use incremental sync (since last run) for large datasets — full rebuilds nightly are only feasible for small indexes.
- Always write to a staging index then swap — never rebuild live index in place (downtime or partial results during rebuild).
- Track `last_indexed_at` on records for incremental reindexing — `updated_at > last_indexed_at` is the reliable change detection pattern.
