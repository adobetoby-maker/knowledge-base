# Hitting Third-Party API Rate Limits

Rate limits exist on almost every third-party API. Being surprised by a 429 in production is a planning failure. Design for rate limits before you hit them.

## Detecting a 429

A 429 response is the HTTP standard for rate limiting. Always check the status code explicitly and treat it differently from other 4xx errors — it is not a permanent failure, it's a temporary signal to back off. Many APIs also return rate limit information in headers:

- `X-RateLimit-Limit` — requests allowed per window
- `X-RateLimit-Remaining` — requests left in current window
- `X-RateLimit-Reset` — Unix timestamp when the window resets
- `Retry-After` — seconds to wait before retrying (may be present on 429)

Read these headers proactively. If `Remaining` is approaching zero, slow down before hitting the limit rather than waiting to receive a 429.

## Exponential Backoff with Jitter

Never retry immediately after a 429 — you'll just get another 429. Use exponential backoff:

```
wait = base_delay * (2 ^ attempt) + random_jitter
```

The `random_jitter` term (e.g., `Math.random() * base_delay`) is critical. Without jitter, all clients that were rate-limited at the same moment retry at the same moment, creating a thundering herd that hammers the API again simultaneously. Jitter spreads retries across time.

Typical parameters: `base_delay = 1s`, max 4-5 attempts, cap the maximum wait at something reasonable (30–60s). After max retries, fail the operation and surface it to the caller.

## Request Queue with Concurrency Limit

For bulk operations (importing 10,000 records, sending 5,000 emails), a naive `Promise.all()` fires all requests simultaneously and guarantees rate limit violations.

Use a queue with controlled concurrency:

```ts
// p-limit or equivalent
const limit = pLimit(5); // max 5 in-flight requests
const results = await Promise.all(items.map(item => limit(() => callApi(item))));
```

Set the concurrency limit conservatively — below what the API allows — to leave headroom for other parts of the system also calling the API.

## Burst vs Sustained Rate Limits

Many APIs have two independent limits:
- **Burst limit**: maximum requests per second (e.g., 10 req/s)
- **Sustained limit**: maximum requests per minute or hour (e.g., 1,000 req/min)

You can stay under the sustained limit while violating the burst limit. A loop that fires 100 requests in 200ms at 500 req/s will be rate-limited even if 1,000 per minute is allowed. Add a small delay between requests in tight loops, not just a concurrency cap.

## Per-Account vs Per-IP Limits

Third-party APIs may rate-limit by:
- **API key / account**: limits shared across all your servers calling with that key
- **IP address**: limits per outbound IP, which changes in serverless/edge environments

If you're running on serverless (Vercel, Lambda), multiple function instances may share a rate limit pool keyed to your API credentials. Scale-out doesn't help you — you're all drawing from the same bucket. The solution is a centralized rate-limit-aware queue (e.g., a dedicated worker with the queue, or Upstash QStash with rate limiting).

Per-IP limits are rare for authenticated APIs but common for public APIs or web scraping. In serverless, each invocation may appear to come from a different IP, which can accidentally help (distributing IP-limited requests) or hurt (some APIs flag rapid per-IP usage as abuse).

## Key Rules

- Read `X-RateLimit-*` and `Retry-After` headers; back off proactively before hitting zero
- Retry 429s with exponential backoff plus random jitter — never retry immediately
- Use a concurrency-limited queue for bulk operations; never fire all requests at once
- Understand both burst (per-second) and sustained (per-minute) limits — you can violate burst while staying under sustained
- In serverless, API key limits are shared across all concurrent function instances; centralize the queue
- Cap total retry attempts and surface failure to the caller after exhausting retries
