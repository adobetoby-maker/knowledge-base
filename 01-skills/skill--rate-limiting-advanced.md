# Skill: Advanced Rate Limiting

## Overview
Basic rate limiting (fixed window counter per IP) is easy to implement but easy to game — a burst of requests at the window boundary can double the allowed rate. Production systems need sliding window algorithms, per-user and per-IP limits applied together, and cost-based consumption for expensive operations.

## Implementation

### Token Bucket (conceptual)
A bucket holds N tokens. Each request consumes tokens. Tokens refill at a steady rate. Burst requests drain the bucket; sustained high rates keep it empty. Advantage: allows short bursts while controlling average rate.

### Sliding Window with Redis Sorted Sets
The sorted set stores a timestamp-scored entry per request within the window. On each request:
1. Remove all entries older than `now - windowMs` (`ZREMRANGEBYSCORE`)
2. Count remaining entries — if over limit, reject
3. Add new entry with `ZADD`, set TTL

All three steps run in a single atomic Lua script to prevent race conditions. The key looks like `rl:user:123:api` or `rl:ip:1.2.3.4:api`.

```typescript
// Pseudocode for the Redis Lua script logic:
// ZREMRANGEBYSCORE key -inf windowStart
// count = ZCARD key
// if count + cost > limit → return {rejected, remaining}
// ZADD key now uniqueId
// EXPIRE key windowSeconds
// return {allowed, remaining}
```

### Middleware Pattern (Next.js)
```typescript
// middleware.ts
export async function middleware(request: NextRequest) {
  const ip = request.ip ?? "unknown";
  const userId = getUserId(request);

  // Apply both IP and user limits — attacker can't bypass by switching IPs
  const [ipLimit, userLimit] = await Promise.all([
    checkRateLimit(`rl:ip:${ip}:api`, 100, 60_000),
    userId ? checkRateLimit(`rl:user:${userId}:api`, 50, 60_000) : null,
  ]);

  const blocked = !ipLimit.allowed || (userLimit && !userLimit.allowed);
  if (blocked) {
    return new Response("Too Many Requests", {
      status: 429,
      headers: {
        "Retry-After": "60",
        "X-RateLimit-Limit": "50",
        "X-RateLimit-Remaining": "0",
      },
    });
  }

  const response = NextResponse.next();
  response.headers.set("X-RateLimit-Limit", "50");
  response.headers.set("X-RateLimit-Remaining", String(userLimit?.remaining ?? ipLimit.remaining));
  response.headers.set("X-RateLimit-Reset", String(Math.ceil(ipLimit.resetAt / 1000)));
  return response;
}
```

### Cost-Per-Request for Expensive Operations
```typescript
// AI endpoint — costs 10 tokens instead of 1
await checkRateLimit(`rl:user:${userId}:api`, 100, 60_000, /* cost= */ 10);

// File upload — costs 5 tokens
await checkRateLimit(`rl:user:${userId}:api`, 100, 60_000, /* cost= */ 5);
```

## Key Rules
- Sliding window is more accurate than fixed window — fixed window allows 2x the rate at window boundaries
- Apply rate limits by both IP and authenticated user ID — IP-only is bypassed by rotating IPs; user-only misses unauthenticated abuse
- Use Redis Lua scripts for atomic operations — separate ZADD + EXPIRE commands without atomicity create race conditions under load
- Always return `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers — clients need this to implement retry logic
- Implement cost-based consumption for expensive ops (LLM calls, image processing) — flat rate limits don't protect against one user monopolizing resources
- Apply rate limiting before auth checks and business logic — failed auth requests still count against the limit
- Include `Retry-After` header on 429 responses so clients know when to retry
