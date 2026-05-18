# Principle: Cache Invalidation Strategies

## Relationship to Caching Strategy

`principle--caching-strategy.md` covers which layer to cache at (in-memory, Redis, CDN, browser) and TTL selection. This file focuses on invalidation: how cached data gets removed or updated when the underlying source changes. Invalidation is the hard part — getting it wrong means users see stale data long after the source of truth has changed.

## Why Invalidation Is Hard

Phil Karlton's observation — "there are only two hard things in computer science: cache naming and cache invalidation" — remains accurate because invalidation requires coordination between the writer of data and all the caches that hold copies of it. Writers often do not know which caches exist. Caches often do not know when their source data changes. Any gap between write and invalidation is a window where readers see stale state.

The impossibility is formal: you cannot have strong consistency (every read sees the latest write), high availability (system responds even during partitions), and partition tolerance simultaneously. Caching is a tradeoff with this theorem at its core.

## Time-Based Invalidation (TTL)

The simplest strategy: every cached entry expires after a fixed duration.

```typescript
await redis.set(key, value, 'EX', 300)  // 5-minute TTL
```

**When to use it:** data that changes infrequently and where brief staleness is acceptable (product catalog, public config, reference data).

**Failure mode:** TTL-based caches are eventually consistent by definition. A product price cached for 5 minutes will show the old price for up to 5 minutes after a change. For high-frequency updates or price-sensitive data, this is unacceptable.

**Choosing TTL:** set it to the maximum staleness your application can tolerate, not the shortest interval that "feels safe." Short TTLs reduce staleness but increase load on the origin. A 30-second TTL on a value that changes weekly is waste without benefit.

## Event-Based Invalidation (Write-Through)

When data is written, immediately invalidate or update the cache entry:

```typescript
async function updateProduct(id: string, data: ProductUpdate): Promise<void> {
  await db.products.update(id, data)
  await cache.del(`product:${id}`)           // invalidate on write
  // or: await cache.set(`product:${id}`, newValue)  // update on write
}
```

**When to use it:** data that changes on discrete write events (user profiles, order status, inventory counts) where you want reads to be immediately fresh after a write.

**Failure mode:** the invalidation can fail even when the write succeeded. If `cache.del` throws after the database write commits, the cache holds stale data with no TTL to rescue it. Mitigate with a short fallback TTL even on event-invalidated entries. Also: if writes happen outside your application (direct database writes, batch jobs, migrations), the cache never gets the invalidation signal.

## Tag-Based Invalidation (Purge All Tagged)

Assign tags to cache entries and purge all entries sharing a tag:

```typescript
await cache.set(`product:${id}`, data, { tags: ['products', `product:${id}`] })
await cache.set(`category:electronics`, listing, { tags: ['products', 'categories'] })

// When product data changes broadly:
await cache.purgeTag('products')  // purges all entries with this tag
```

**When to use it:** nested or aggregate data where a single entity change invalidates many cache entries (a product change invalidates product detail, category listing, search results, featured products section).

**Failure mode:** tag purges can be expensive if many entries share a tag. A deployment that changes all products simultaneously could purge thousands of entries and cause a cache stampede. Combine with staggered re-warming or a short TTL as a safety valve.

## Write-Through vs. Write-Behind

**Write-through:** write to cache and database atomically. Every write is immediately durable and cached.

```
write request → update cache AND database synchronously → return success
```

Higher write latency; reads are always fast and fresh. The database and cache are kept in sync on every write.

**Write-behind (write-back):** write to cache immediately, asynchronously persist to database. Write is fast; persistence is eventual.

```
write request → update cache → return success (quickly) → async: flush to database
```

Lower write latency; risk of data loss if the cache is lost before the flush. Only appropriate when brief data loss is acceptable (view counts, user preferences, draft state).

## The Stale-While-Revalidate Pattern

Return the stale cached value immediately while triggering an async refresh:

```typescript
async function getWithSWR<T>(key: string, fetcher: () => Promise<T>, ttl: number): Promise<T> {
  const cached = await cache.getWithMeta(key)
  if (cached && !cached.isExpired) return cached.value
  if (cached && cached.isExpired) {
    refreshAsync(key, fetcher, ttl)   // fire and forget
    return cached.value               // return stale while refreshing
  }
  return cache.setAndReturn(key, await fetcher(), ttl)
}
```

This eliminates the latency spike from a cache miss at the cost of one request seeing stale data. For data where freshness is not critical but latency is, this is often the best tradeoff.

## Key Rules

- TTL is a safety net, not a primary invalidation strategy — always combine with event-based invalidation for write-driven data
- Write-through invalidation can fail silently; add a short fallback TTL to all event-invalidated entries
- Tag-based purges can cause stampedes — pair with re-warming or short TTLs
- Write-behind risks data loss; only use when brief loss is explicitly acceptable
- You cannot have strong consistency and high availability simultaneously — choose your tradeoff explicitly
- Caches outside your application's write path (direct DB writes, migrations) never receive invalidation signals — design for this
