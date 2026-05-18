# Rate Limiting

## Why Rate Limiting Matters

Without rate limits, a single client can exhaust server resources, hit external API quotas, run up usage bills, or brute-force authentication endpoints. Rate limiting is a boundary defense — it belongs at the system boundary, not inside business logic.

## Upstash Redis Rate Limiter (Recommended for Vercel)

```typescript
// lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const redis = Redis.fromEnv()

// Sliding window: 10 requests per 10 seconds per IP
export const rateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '10 s'),
  analytics: true,
})

// Stricter limit for auth endpoints
export const authRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.fixedWindow(5, '60 s'),
})
```

```typescript
// app/api/chat/route.ts — applying rate limit
import { rateLimiter } from '@/lib/rate-limit'
import { headers } from 'next/headers'

export async function POST(req: NextRequest) {
  const headersList = await headers()
  const ip = headersList.get('x-forwarded-for') ?? '127.0.0.1'
  
  const { success, limit, remaining, reset } = await rateLimiter.limit(ip)
  
  if (!success) {
    return NextResponse.json(
      { error: 'Too many requests' },
      {
        status: 429,
        headers: {
          'X-RateLimit-Limit': limit.toString(),
          'X-RateLimit-Remaining': remaining.toString(),
          'X-RateLimit-Reset': reset.toString(),
          'Retry-After': Math.ceil((reset - Date.now()) / 1000).toString(),
        },
      }
    )
  }
  
  // ... handle request
}
```

## In-Memory Rate Limiter (Dev or Simple Cases)

For development or simple single-instance scenarios without Redis:

```typescript
// lib/rate-limit-simple.ts
const requestCounts = new Map<string, { count: number; resetAt: number }>()

export function checkRateLimit(key: string, limit: number, windowMs: number): boolean {
  const now = Date.now()
  const record = requestCounts.get(key)
  
  if (!record || now > record.resetAt) {
    requestCounts.set(key, { count: 1, resetAt: now + windowMs })
    return true
  }
  
  if (record.count >= limit) return false
  
  record.count++
  return true
}
```

Note: In-memory rate limiters don't work correctly across multiple server instances. Use Redis for production on Vercel (multiple functions run in parallel).

## Cloudflare Workers Rate Limiting

Cloudflare has a native rate limiting API:

```typescript
// Cloudflare Workers — check rate limit binding
export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const { success } = await env.RATE_LIMITER.limit({ key: req.headers.get('CF-Connecting-IP') ?? 'unknown' })
    
    if (!success) {
      return new Response('Too Many Requests', { status: 429 })
    }
    
    return handleRequest(req, env)
  }
}
```

```toml
# wrangler.toml
[[rate_limiting]]
binding = "RATE_LIMITER"
namespace_id = "your-namespace-id"
simple = { limit = 100, period = 60 }
```

## Rate Limit by User vs IP

| Strategy | Use case | Key |
|----------|----------|-----|
| By IP | Unauthenticated routes, login forms | `x-forwarded-for` header |
| By user ID | Authenticated API routes | `session.user.id` |
| By API key | External API consumers | `x-api-key` header value |
| Global | AI/expensive operations | Fixed key or route path |

```typescript
// Rate limit authenticated users by ID
export async function POST(req: NextRequest) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  const { success } = await rateLimiter.limit(`user:${user.id}`)
  if (!success) return NextResponse.json({ error: 'Rate limit exceeded' }, { status: 429 })
  
  // ...
}
```

## AI/LLM Rate Limiting

AI endpoints are expensive — add both request count and token budget limits:

```typescript
// Separate limiters for AI routes
export const aiRateLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.fixedWindow(20, '1 h'),  // 20 AI requests per hour per user
})

// Check before calling Anthropic/OpenAI
const { success } = await aiRateLimiter.limit(`ai:${user.id}`)
if (!success) {
  return NextResponse.json(
    { error: 'AI usage limit reached. Try again in an hour.' },
    { status: 429 }
  )
}
```

## Middleware-Level Rate Limiting

Apply rate limits globally via middleware for auth routes:

```typescript
// middleware.ts
import { rateLimiter } from '@/lib/rate-limit'

export async function middleware(req: NextRequest) {
  // Rate limit all /api/auth/* routes
  if (req.nextUrl.pathname.startsWith('/api/auth')) {
    const ip = req.headers.get('x-forwarded-for') ?? '127.0.0.1'
    const { success } = await authRateLimiter.limit(ip)
    
    if (!success) {
      return NextResponse.json({ error: 'Too many requests' }, { status: 429 })
    }
  }
  
  return NextResponse.next()
}
```

## Rate Limit Headers

Always return standard headers so clients know the limits:
- `X-RateLimit-Limit` — maximum requests allowed
- `X-RateLimit-Remaining` — requests remaining in current window
- `X-RateLimit-Reset` — Unix timestamp when window resets
- `Retry-After` — seconds until retry is allowed (on 429)
