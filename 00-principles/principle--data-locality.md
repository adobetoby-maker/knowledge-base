# Principle: Data Locality

## Overview

Data locality means keeping data and the code that processes it close together: geographically (edge vs origin), architecturally (DB and server in same region), and in code (related operations in one query instead of many). Violating data locality is the most common cause of performance problems: excess network round trips, N+1 queries, and cross-region latency.

## Geographic Data Locality

```ts
// BAD — Vercel edge function in Singapore calls Supabase in us-east-1
// Every request: 250ms+ latency just for the DB round-trip

// GOOD — App and DB in same region
// Vercel: set region in vercel.json
// {
//   "regions": ["iad1"]  // us-east-1
// }

// Supabase: choose region at project creation — match Vercel region

// For global traffic, use read replicas or edge caching:
// Vercel Edge Config for static config
// Upstash Redis for session/rate-limiting data (edge-native)
```

## Query Data Locality (Avoiding N+1)

```ts
// BAD — N+1: fetches author separately for each post
const posts = await db.select().from(posts)
for (const post of posts) {
  post.author = await db.query.users.findFirst({ where: eq(users.id, post.authorId) })
}

// GOOD — join brings related data in one query
const posts = await db.select({
  id: posts.id,
  title: posts.title,
  authorName: users.name,
  authorAvatar: users.avatarUrl,
}).from(posts)
  .leftJoin(users, eq(posts.authorId, users.id))
```

```ts
// For ORM-style: use with() to eager load
const posts = await db.query.posts.findMany({
  with: { author: true, tags: true },
})
```

## Batch Over Round-Trip

```ts
// BAD — sequential round trips
const user = await db.query.users.findFirst(...)
const posts = await db.query.posts.findMany(...)
const comments = await db.query.comments.findMany(...)
// 3 network round trips

// GOOD — parallel round trips (same latency as 1)
const [user, posts, comments] = await Promise.all([
  db.query.users.findFirst(...),
  db.query.posts.findMany(...),
  db.query.comments.findMany(...),
])

// BETTER — single query if data is related
const userData = await db.select({ ... })
  .from(users)
  .leftJoin(posts, eq(posts.userId, users.id))
  .leftJoin(comments, eq(comments.userId, users.id))
  .where(eq(users.id, userId))
```

## Code Colocation

Keeping related logic close in code reduces cognitive distance (not performance, but maintainability):

```ts
// BAD — split across files: schema in one place, queries in another, types in another
// types/user.ts, queries/user.ts, schemas/user.ts, validations/user.ts

// GOOD — all user-related code in one module
// lib/users/
//   index.ts  — public API
//   schema.ts — Drizzle schema
//   queries.ts — DB queries
//   types.ts  — TypeScript interfaces
//   validation.ts — Zod schemas
```

## Cache Locality

```ts
// Cache data close to where it's used
// Edge (Cloudflare KV, Vercel Edge Config): static config, feature flags
// Application cache (Redis): user sessions, frequently-queried data
// In-memory (Map): hot data within a single process

// Access pattern determines where to cache:
// Per-user data → Redis (keyed by userId)
// Global reference data → Edge KV (shared, near user)
// Per-request → in-memory LRU (no network hop)

const cache = new Map<string, { data: unknown; expires: number }>()

function memCache<T>(key: string, fn: () => T, ttlMs: number): T {
  const entry = cache.get(key)
  if (entry && entry.expires > Date.now()) return entry.data as T
  const data = fn()
  cache.set(key, { data, expires: Date.now() + ttlMs })
  return data
}
```

## Region-Specific Data

```ts
// For multi-region apps, store user data in the region closest to them
// Route to the right DB based on user's preferred region

async function getUserDb(userId: string): Promise<Database> {
  const user = await getUser(userId)
  const region = user.preferredRegion ?? 'us-east-1'

  return DATABASE_CONNECTIONS[region]
}
```

## Key Rules

- App server and database must be in the same region — cross-region DB calls add 50–200ms per query; at 5 queries per request that's 1 second of pure network latency.
- Use joins and `with()` to avoid N+1 patterns — each separate DB query adds a network round-trip.
- `Promise.all` for independent queries — parallel queries have the latency of the slowest, not the sum.
- Edge functions must only call edge-native services (Upstash, D1, KV) — calling a regional DB from an edge function is slower than calling it from a regional server.
- Cache at the level closest to the consumer: edge > CDN > application > database.
