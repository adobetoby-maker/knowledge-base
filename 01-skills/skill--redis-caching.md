# Skill: Redis Caching Patterns

## Overview
Redis caching reduces database load and latency for expensive or frequently read data. The three failure modes that cost teams weeks: cache stampede (thundering herd), cache poisoning with stale data on write, and missing TTLs that fill memory until Redis evicts everything. Each pattern below prevents one of these.

## Implementation

### 1. Key naming convention
```ts
// Pattern: namespace:entity:id[:variant]
const keys = {
  user:      (id: string) => `user:profile:${id}`,
  userPosts: (id: string) => `user:posts:${id}`,
  feed:      (userId: string, page: number) => `feed:${userId}:p${page}`,
  config:    () => 'app:config:global',
};
// Consistent naming enables flush-by-pattern and avoids collisions
```

### 2. Cache-aside (read-through) — most common pattern
```ts
async function getUser(id: string): Promise<User> {
  const key = keys.user(id);
  
  // 1. Check cache
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);
  
  // 2. Cache miss — fetch from DB
  const user = await db.users.findUnique({ where: { id } });
  if (!user) throw new NotFoundError();
  
  // 3. Populate cache with TTL
  await redis.set(key, JSON.stringify(user), 'EX', 3600);  // 1h TTL
  
  return user;
}

// On update — invalidate cache immediately (write-through = also set cache here)
async function updateUser(id: string, data: Partial<User>) {
  const user = await db.users.update({ where: { id }, data });
  await redis.del(keys.user(id));  // invalidate; next read repopulates
  return user;
}
```

### 3. Cache stampede prevention with distributed lock
```ts
// When cache expires, many concurrent requests all miss and hit DB simultaneously.
// Use NX (only set if not exists) as a distributed lock.
async function getWithLock<T>(
  key: string,
  fetch: () => Promise<T>,
  ttlSec = 3600
): Promise<T> {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  const lockKey = `lock:${key}`;
  const lockAcquired = await redis.set(lockKey, '1', 'EX', 10, 'NX');

  if (!lockAcquired) {
    // Another process is fetching — wait and retry
    await new Promise(r => setTimeout(r, 100));
    return getWithLock(key, fetch, ttlSec);
  }

  try {
    const value = await fetch();
    await redis.set(key, JSON.stringify(value), 'EX', ttlSec);
    return value;
  } finally {
    await redis.del(lockKey);
  }
}
```

### 4. Write-through (keep cache and DB in sync on writes)
```ts
async function setConfig(config: AppConfig) {
  const key = keys.config();
  await db.config.upsert({ ... });
  // Write to cache simultaneously — cache never goes stale
  await redis.set(key, JSON.stringify(config), 'EX', 86400);
}
```

### 5. Flush by pattern (bulk invalidation)
```ts
// Invalidate all cache keys for a user (posts, profile, feed pages)
async function invalidateUser(userId: string) {
  // KEYS is O(n) — acceptable for small keyspaces; use SCAN for large ones
  const pattern = `*:${userId}:*`;
  let cursor = '0';
  do {
    const [next, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
    cursor = next;
    if (keys.length) await redis.del(...keys);
  } while (cursor !== '0');
}
```

### 6. Counters (atomic, no read-modify-write)
```ts
// INCR is atomic — no race condition possible
await redis.incr(`pageviews:${slug}`);
await redis.expire(`pageviews:${slug}`, 86400);  // reset daily
```

## Key Rules
- **Always set TTL** — never use `SET` without `EX`/`PX` in application code. Unbounded keys fill memory.
- Cache-aside is safer than write-through for most cases — simpler invalidation logic.
- Never cache `null`/not-found results for long — they prevent seeing newly created records.
- Use SCAN not KEYS in production — KEYS blocks Redis for the scan duration on large keyspaces.
- Serialize with `JSON.stringify` — avoid storing JS objects directly (they serialize to `[object Object]`).
- Keep cache TTLs shorter than your data's freshness requirement, not longer.
- Cache by logical entity, not by query string — easier to invalidate on update.
