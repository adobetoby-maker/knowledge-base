# Upstash (Redis + Rate Limiting)

## What Upstash Provides

Upstash is a serverless Redis that works on Edge runtimes (Vercel Edge, Cloudflare Workers). It's the go-to solution for rate limiting, session storage, and caching in serverless Next.js.

## Setup

```bash
npm install @upstash/redis @upstash/ratelimit
```

Create a Redis database at console.upstash.com. Get the REST URL and token.

```typescript
// lib/redis.ts
import { Redis } from '@upstash/redis'

export const redis = Redis.fromEnv()
// Reads UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN from env
```

Env vars:
```
UPSTASH_REDIS_REST_URL=https://your-db.upstash.io
UPSTASH_REDIS_REST_TOKEN=your-token
```

## Rate Limiting

```typescript
// lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit'
import { redis } from './redis'

// Different limiters for different endpoints
export const apiRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(60, '1 m'),  // 60 req/minute
  analytics: true,
  prefix: 'rl:api',
})

export const authRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.fixedWindow(5, '60 s'),    // 5 attempts/minute
  prefix: 'rl:auth',
})

export const aiRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.fixedWindow(20, '1 h'),    // 20 AI requests/hour per user
  prefix: 'rl:ai',
})
```

```typescript
// Applying in a Route Handler
import { apiRateLimit } from '@/lib/rate-limit'
import { headers } from 'next/headers'

export async function POST(req: NextRequest) {
  const headersList = await headers()
  const ip = headersList.get('x-forwarded-for') ?? '127.0.0.1'
  
  const { success, limit, remaining, reset } = await apiRateLimit.limit(ip)
  
  if (!success) {
    return NextResponse.json({ error: 'Rate limit exceeded' }, {
      status: 429,
      headers: {
        'X-RateLimit-Limit': limit.toString(),
        'X-RateLimit-Remaining': remaining.toString(),
        'X-RateLimit-Reset': new Date(reset).toISOString(),
      },
    })
  }
}
```

## Caching

```typescript
// lib/cache.ts
import { redis } from './redis'

export async function getCached<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttlSeconds: number
): Promise<T> {
  const cached = await redis.get<T>(key)
  if (cached !== null) return cached
  
  const fresh = await fetcher()
  await redis.setex(key, ttlSeconds, fresh)
  return fresh
}

// Usage — caches for 5 minutes
const stats = await getCached(
  `shop:stats:${shopId}`,
  () => fetchShopStats(shopId),
  300
)
```

## Session Storage (Redis-backed)

```typescript
import { redis } from './redis'

interface Session {
  userId: string
  email: string
  createdAt: number
}

const SESSION_TTL = 60 * 60 * 24 * 7  // 7 days

export async function createSession(userId: string, email: string): Promise<string> {
  const sessionId = crypto.randomUUID()
  const session: Session = { userId, email, createdAt: Date.now() }
  await redis.setex(`session:${sessionId}`, SESSION_TTL, session)
  return sessionId
}

export async function getSession(sessionId: string): Promise<Session | null> {
  return redis.get<Session>(`session:${sessionId}`)
}

export async function deleteSession(sessionId: string): Promise<void> {
  await redis.del(`session:${sessionId}`)
}
```

## Queue / Pub-Sub (Simple)

```typescript
// Push to queue
await redis.lpush('email:queue', JSON.stringify({ to, subject, body }))

// Pop from queue (in a background worker)
const raw = await redis.rpop('email:queue')
if (raw) {
  const job = JSON.parse(raw as string)
  await sendEmail(job)
}
```

## Atomic Counters

```typescript
// Increment a counter (atomic)
const count = await redis.incr(`views:${articleSlug}`)

// Increment with expiry (for time-windowed counters)
const pipe = redis.pipeline()
pipe.incr(`daily:views:${date}`)
pipe.expire(`daily:views:${date}`, 86400)
const [views] = await pipe.exec()
```

## When Not to Use Upstash

- Persistent business data (use Supabase/database instead)
- Large blobs or files (use Supabase Storage or R2)
- Complex relational queries (use Supabase)

Upstash Redis is for ephemeral, fast-access data: rate limiting, caching, sessions, queues.
