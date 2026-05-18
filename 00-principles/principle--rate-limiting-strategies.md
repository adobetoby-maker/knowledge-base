# Rate Limiting Strategies

## Why the Algorithm Choice Matters

"Add rate limiting" sounds simple until you discover that a naive counter allows a burst of 200 requests in the last second of one window and 200 in the first second of the next — 400 requests in two seconds against a limit of 200/minute. Algorithm choice determines whether limits are actually enforced.

## Token Bucket

A bucket holds up to `capacity` tokens. Tokens replenish at a fixed rate (e.g., 10/second). Each request consumes 1 token. If the bucket is empty, reject.

**Behavior:** Allows bursts up to `capacity`, smooths sustained load. A user can burst 60 requests instantly (if they have accumulated tokens), then is throttled to 10/second.

**Best for:** APIs that should allow occasional spikes but enforce a sustained rate. Most REST APIs.

## Leaky Bucket

Requests queue. The queue drains at a fixed rate. If the queue overflows, reject.

**Behavior:** Enforces a strictly constant output rate. No bursts — even a small burst fills the queue and starts dropping.

**Best for:** Outbound rate limiting (calls to a third-party API with strict per-second limits). Rarely the right choice for inbound API rate limiting — users experience unpredictable latency as requests queue.

## Sliding Window

Track a count of requests in a rolling time window (e.g., "last 60 seconds"). No hard window boundaries, so the burst-at-boundary problem is eliminated.

**Redis implementation:**

```typescript
async function slidingWindowCheck(key: string, limit: number, windowSec: number): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - windowSec * 1000;
  const uniqueId = String(now) + String(Math.random());

  const pipe = redis.multi();
  pipe.zremrangebyscore(key, 0, windowStart);    // remove old entries
  pipe.zadd(key, now, uniqueId);                  // add this request
  pipe.zcard(key);                                // count in window
  pipe.expire(key, windowSec);                    // TTL cleanup

  const results = await pipe.exec();
  const count = results[2][1] as number;
  return count <= limit;
}
```

**Best for:** Per-user rate limiting where fairness matters. The algorithm most users expect.

## Simple Fixed Window with INCR + EXPIRE

Fast and Redis-native. Subject to boundary burst, but acceptable for most uses:

```typescript
async function fixedWindowCheck(key: string, limit: number, windowSec: number): Promise<boolean> {
  const windowKey = `${key}:${Math.floor(Date.now() / (windowSec * 1000))}`;
  const count = await redis.incr(windowKey);
  if (count === 1) await redis.expire(windowKey, windowSec);
  return count <= limit;
}
```

Use this when simplicity matters more than precise enforcement of edge cases.

## Limit Granularity: Per-User vs Per-IP vs Per-Endpoint

Apply limits at multiple granularities:

- **Per-user** (authenticated): primary limit, usually highest. Represents intended quota.
- **Per-IP** (unauthenticated): tighter limit, prevents credential stuffing and scraping. 10-20 req/min is reasonable for login endpoints.
- **Per-endpoint**: specific expensive endpoints (AI inference, bulk export, report generation) get their own lower limits regardless of user quota.

Stack them: a request passes only if it clears all applicable limits.

## Burst vs Sustained Limits

Two limits on one endpoint:

- **Burst**: 20 requests per 10 seconds — short-term spike budget
- **Sustained**: 100 requests per minute — longer-term throughput limit

This allows a user to make 20 requests quickly for interactive workflows, without allowing 360/minute sustained hammering. Token bucket naturally models this; you can also enforce it with two separate counters.

## Informative 429 Responses

A 429 that returns `{"error": "rate limit exceeded"}` tells the client nothing useful. Return:

```
HTTP/1.1 429 Too Many Requests
Retry-After: 23
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1747600980

{ "error": "rate_limit_exceeded", "message": "You have exceeded 100 requests per minute. Retry after 23 seconds.", "retry_after_seconds": 23 }
```

`Retry-After` is the most important header — clients that respect it will back off automatically. Return it as seconds (integer), not a date string.

## Key Rules

- Use sliding window for user-facing APIs; use fixed window only when simplicity outweighs precision
- Apply limits at multiple granularities: per-user, per-IP, per-endpoint — a request must pass all
- Separate burst limits (short window, higher rate) from sustained limits (long window, lower rate)
- Always return `Retry-After` on 429 — clients need it to back off correctly
- Store rate limit counters in Redis, not in-process memory — processes share no state
- Test the boundary burst case: verify that requests at the window boundary are correctly counted
