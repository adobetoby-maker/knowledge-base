# Disambiguation: Which Cache Layer to Use

## Decision Tree

```
Is the data user-specific (different per logged-in user)?
  YES → Never use CDN. Use Redis (server) or browser memory (client)
  NO  → Can use CDN

Is the data computed from DB and shared across users?
  YES, changes rarely (hours/days) → Redis + CDN with revalidation
  YES, changes frequently (minutes) → Redis only
  YES, must be exact/real-time → No caching

Is this a pure computation (same inputs = same output)?
  YES → In-process memoization
  NO  → Don't memoize

Is the data static at build time?
  YES → Static generation + CDN (max-age=31536000)
  NO  → Dynamic, choose above
```

## Quick Reference

| Data type | Cache where | TTL |
|-----------|-------------|-----|
| HTML pages (public) | CDN + ISR | 1 hour |
| HTML pages (auth required) | None (force-dynamic) | — |
| API: public lists (products, articles) | CDN + Redis | 5-60 min |
| API: user-specific data | Redis only | 5 min |
| API: real-time data | No cache | — |
| Images, fonts, CSS, JS | CDN (immutable) | 1 year |
| Session tokens | Redis only | 24 hours |
| Database queries (hot paths) | Redis | 1-5 min |
| In-memory singletons | Process memory | Until restart |

## Next.js Specific

```ts
// Public page — CDN cached, revalidated hourly
export const revalidate = 3600

// User-specific page — never CDN cached
export const dynamic = 'force-dynamic'

// Static page — cached forever, rebuild to update
export const dynamic = 'force-static'

// Route Handler — explicit cache header
headers: { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=60' }
```

## Common Mistakes

### Caching User-Specific Data in CDN

```ts
// WRONG: User A's data gets served to User B
export const revalidate = 60  // CDN caches the page

async function UserDashboard() {
  const user = await getCurrentUser()  // Different per user!
  return <div>Hello {user.name}</div>
}

// RIGHT: Force dynamic for user-specific pages
export const dynamic = 'force-dynamic'

async function UserDashboard() {
  const user = await getCurrentUser()
  return <div>Hello {user.name}</div>
}
```

### Caching Mutating Operations

```ts
// WRONG: GET route that performs DB writes — might be cached
export async function GET() {
  await db.insert(auditLog).values({ action: 'page_view' })
  return Response.json(data)
}

// RIGHT: Only GET routes that are truly read-only should be cached
// Write operations use POST/PUT/DELETE (not cacheable by default)
```

### Missing Cache Invalidation

```ts
// WRONG: Update DB but forget to clear cache
async function updateUserPlan(userId: string, plan: string) {
  await db.update(users).set({ plan }).where(eq(users.id, userId))
  // Cache still has old plan!
}

// RIGHT: Update and invalidate atomically
async function updateUserPlan(userId: string, plan: string) {
  await db.update(users).set({ plan }).where(eq(users.id, userId))
  await redis.del(`user:${userId}`)  // Bust cache
  await redis.del(`billing:${userId}`)  // Bust any derived caches
}
```

## Cloudflare KV vs Redis vs In-Memory

| | CF KV | Redis | In-memory |
|--|-------|-------|-----------|
| Works in CF Workers | Yes | No (use Upstash) | Yes |
| Works in Node.js | No | Yes | Yes |
| Shared across instances | Yes | Yes | No |
| Latency | ~1ms (edge hit) | ~1ms (co-located) | <0.01ms |
| Cost | Pay per read/write | Fixed + ops | Free |
| Persistence | Yes | Yes (optional) | No |
| Best for | Edge cache, session | General purpose | Singleton, memo |
