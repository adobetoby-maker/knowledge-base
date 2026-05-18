# Principle: Caching Strategy

## Overview

Caching trades freshness for speed. The wrong cache layer (or wrong TTL) causes stale data, wasted memory, and hard-to-reproduce bugs. This guide covers which layer to cache at and how to invalidate correctly.

## Caching Layers (Innermost to Outermost)

```
1. In-memory (process memory)    — Fastest, lost on restart, not shared
2. Redis / KV Store               — Fast, survives restarts, shared across instances
3. CDN / Edge Cache               — Global, cached near user, HTTP-controlled
4. Browser cache                  — No server cost, user-controlled
```

Each layer has different tradeoffs. Use the innermost layer that satisfies your requirements.

## Layer 1: In-Memory (Memoization)

```ts
// Function-level memoization for expensive pure computation
import { memoize } from 'lodash-es'

const parseComplexConfig = memoize((rawConfig: string) => {
  return expensiveParse(rawConfig)
})

// Module-level singleton for expensive initialization
let _client: DbClient | null = null
function getDbClient() {
  return _client ?? (_client = new DbClient())
}
```

Use for: pure functions, database connection pooling, computed values from static data.
Don't use for: user-specific data, mutable data, cross-request state in serverless.

## Layer 2: Redis / KV Store

```ts
async function getCachedUser(userId: string): Promise<User | null> {
  const cached = await redis.get(`user:${userId}`)
  if (cached) return JSON.parse(cached)

  const user = await db.query.users.findFirst({ where: eq(users.id, userId) })
  if (user) {
    await redis.set(`user:${userId}`, JSON.stringify(user), 'EX', 300)
  }
  return user
}
```

TTL guidelines:
- User profile: 5 minutes (changes infrequently, high-read)
- Product catalog: 1 hour (changes rarely)
- Session data: 24 hours (or until logout)
- Leaderboard: 30 seconds (frequent reads, acceptable lag)
- Financial calculations: 0 (never cache — must be exact)

## Layer 3: CDN / Edge Cache

Controlled via HTTP headers. Next.js sets these via `Cache-Control` or route config:

```ts
// Next.js static generation — cached by CDN indefinitely
export const revalidate = 3600  // Revalidate every hour (ISR)
export const dynamic = 'force-static'  // Never revalidate (full static)

// Force no caching (per-user dynamic data)
export const dynamic = 'force-dynamic'

// Route Handler with explicit cache header
export async function GET() {
  const data = await getPublicData()
  return Response.json(data, {
    headers: {
      'Cache-Control': 'public, max-age=300, stale-while-revalidate=60',
    },
  })
}
```

## Layer 4: Browser Cache

```ts
// Images, fonts, static assets — very long TTL (content-addressed)
'Cache-Control': 'public, max-age=31536000, immutable'

// API responses for logged-in users — no caching
'Cache-Control': 'private, no-cache'

// Public API responses
'Cache-Control': 'public, max-age=60, stale-while-revalidate=30'
```

## Cache Invalidation

Cache invalidation is the hard part. Three patterns:

**TTL-based (simple)**: Data is stale but correct within TTL window. Acceptable for: product listings, blog posts, leaderboards.

**Event-based (precise)**: Invalidate on write:
```ts
async function updateUser(userId: string, data: Partial<User>) {
  await db.update(users).set(data).where(eq(users.id, userId))
  await redis.del(`user:${userId}`)  // Invalidate immediately
  await redis.del(`user-posts:${userId}`)  // Invalidate derived caches
}
```

**Cache versioning (zero-downtime)**: Prefix cache keys with version:
```ts
const CACHE_VERSION = 'v3'
const key = `${CACHE_VERSION}:user:${userId}`
// Change CACHE_VERSION to bust ALL caches on deploy
```

## Cache Stampede Prevention

When a cache key expires and many requests hit the origin simultaneously:

```ts
async function getCachedWithLock<T>(
  key: string,
  ttl: number,
  fetch: () => Promise<T>,
): Promise<T> {
  const cached = await redis.get(key)
  if (cached) return JSON.parse(cached)

  // Acquire lock to prevent stampede
  const lockKey = `lock:${key}`
  const acquired = await redis.set(lockKey, '1', 'NX', 'EX', 10)

  if (!acquired) {
    // Another process is fetching — wait briefly and retry
    await new Promise(resolve => setTimeout(resolve, 100))
    return getCachedWithLock(key, ttl, fetch)
  }

  try {
    const fresh = await fetch()
    await redis.set(key, JSON.stringify(fresh), 'EX', ttl)
    return fresh
  } finally {
    await redis.del(lockKey)
  }
}
```

## What NOT to Cache

- Authentication tokens and session state (use Redis with expiry, not CDN)
- Financial calculations (amounts, balances)
- Inventory counts where exactness matters
- Personal data subject to GDPR deletion requests
- Search results for privacy-sensitive queries
