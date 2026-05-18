# Cache Invalidation

## Why Cache Invalidation Is Hard

Phil Karlton famously called it one of the two hard problems in computer science. The difficulty: a cache is a second source of truth. Every write to the primary store creates a window where the cache holds stale data. The art is choosing how long that window is acceptable, and closing it deliberately when it's not.

The failure modes are asymmetric: too-aggressive invalidation means cache thrashing (you're just adding latency to every DB read). Too-conservative invalidation means users see wrong data. Know which failure mode is worse for your use case before choosing a strategy.

## Time-Based Expiry (TTL)

The simplest strategy. Every cache entry has a maximum age. Stale data is bounded by the TTL.

```ts
await redis.set(key, JSON.stringify(value), 'EX', 60); // expire in 60 seconds
```

Use TTL for:
- Data that changes slowly (exchange rates, feature flag defaults, static config)
- Data where slight staleness is acceptable (page view counts, aggregate stats)
- External API responses (cache them to avoid hammering quotas)

Pitfall: a single TTL value for all records in a collection creates a thundering herd — all entries expire simultaneously. Jitter the TTL:

```ts
const jitter = Math.floor(Math.random() * 15); // 0–15 seconds
await redis.set(key, value, 'EX', 60 + jitter);
```

## Event-Based Invalidation (Purge on Write)

When data changes, immediately invalidate the affected cache entry. The next read rebuilds from the DB.

```ts
async function updateUser(userId: string, data: Partial<User>) {
  await db.update(users).set(data).where(eq(users.id, userId));
  await redis.del(`user:${userId}`);  // purge immediately
}
```

Use for: data where stale display is unacceptable (user profile, pricing, permissions).

Pitfall: if the cache delete fails after the DB write succeeds, the cache serves stale data until TTL. Mitigate with a short background TTL (e.g., 5 min) as a safety net even when doing event-based invalidation. Also: invalidating on write requires the write path to know what cache keys exist — this creates coupling. Tag-based invalidation solves this.

## Tag-Based Invalidation

Instead of knowing exact cache keys, attach tags to cached entries. On write, purge all entries with a given tag.

```ts
// On cache write:
await cache.set(`invoice:${invoiceId}`, invoice, { tags: [`user:${userId}`, `invoice:${invoiceId}`] });

// On user update — purge everything tagged for that user:
await cache.purgeTag(`user:${userId}`);

// On invoice update — purge only the specific invoice:
await cache.purgeTag(`invoice:${invoiceId}`);
```

Cloudflare Cache API, Vercel Data Cache, and custom Redis implementations support tag-based invalidation. Tag-based invalidation is essential for collections — when a user's record changes, purge all cached views that included that user's data, without needing to enumerate every key.

For Redis: maintain a `SET` per tag with all associated keys, then delete each key and the set:

```ts
async function purgeTag(tag: string) {
  const keys = await redis.smembers(`tag:${tag}`);
  if (keys.length) {
    await redis.del(...keys);
    await redis.del(`tag:${tag}`);
  }
}
```

## Write-Through vs Write-Behind

**Write-through**: update cache and DB together on every write. Cache is always warm. Writes are slightly slower (two operations, but in parallel). Cache never serves stale data. Best for read-heavy data where freshness is critical.

**Write-behind (write-back)**: write to cache immediately, write to DB asynchronously. Fastest writes, but data loss risk if cache fails before DB flush. Use only for high-write-rate, low-criticality data (view counters, recently-seen timestamps).

For most web applications, write-through is the correct default. Write-behind is an optimization for specific hot paths.

## Stampede Prevention

When a popular cache entry expires, many concurrent requests all miss, all hit the DB simultaneously, all compute the same expensive result. This is a cache stampede (dogpile effect).

**Probabilistic early expiry** (also called "PER" or "XFetch"): recompute slightly before expiry with increasing probability as the TTL approaches zero:

```ts
async function getWithPER<T>(key: string, ttl: number, compute: () => Promise<T>): Promise<T> {
  const entry = await redis.get(key);
  if (entry) {
    const { value, expiresAt } = JSON.parse(entry);
    const remainingMs = expiresAt - Date.now();
    const beta = 1; // tuning parameter
    const shouldRecompute = remainingMs < beta * ttl * 1000 * Math.random();
    if (!shouldRecompute) return value;
  }
  const value = await compute();
  await redis.set(key, JSON.stringify({ value, expiresAt: Date.now() + ttl * 1000 }), 'EX', ttl);
  return value;
}
```

**Mutex lock**: only one request recomputes; others wait. More complex but prevents all duplicate DB calls.

## Cache Key Design

```
{namespace}:{entity_type}:{id}:{variant}
user:profile:abc123
invoice:list:user-abc123:page-2:status-draft
```

Include every parameter that affects the result. Forgetting a variant (e.g., locale, currency) causes one user to see another's localized data — a correctness bug, not just a performance bug.

## Key Rules

- Always set a **background TTL** even with event-based invalidation — handles missed invalidations.
- **Jitter TTLs** in collections to prevent thundering herd on synchronized expiry.
- Use **tag-based invalidation** when a single entity appears in multiple cached views.
- **Write-through** is the safe default; write-behind only for high-write-rate low-criticality data.
- Use **probabilistic early expiry or mutex locking** for popular entries to prevent stampedes.
- Cache keys must include **every parameter** that changes the result — missing a variant is a correctness bug.
- Measure **cache hit rate** — if it's below 80%, re-examine key design or TTL strategy.
