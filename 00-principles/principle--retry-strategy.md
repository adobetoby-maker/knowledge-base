# Principle: Retry Strategy

## Overview

Retrying failed operations recovers from transient failures (network blips, rate limits, service restarts). Done wrong, retries amplify failures (thundering herd) or waste time on errors that will never succeed. Done right, retries make systems self-healing.

## Only Retry Transient Errors

```ts
function isRetryable(error: unknown): boolean {
  if (error instanceof Error) {
    // Network errors — transient
    if (error.message.includes('ECONNRESET')) return true
    if (error.message.includes('ETIMEDOUT')) return true
    if (error.message.includes('ENOTFOUND')) return true
  }

  if (error && typeof error === 'object' && 'status' in error) {
    const status = (error as { status: number }).status
    // Rate limited — retry after delay
    if (status === 429) return true
    // Server errors — may be transient
    if (status === 503) return true
    if (status === 502) return true
    // Client errors — NOT retryable (bad request, auth failure)
    if (status === 400) return false
    if (status === 401) return false
    if (status === 403) return false
    if (status === 404) return false
    if (status === 422) return false
  }

  return false
}
```

Never retry: 400, 401, 403, 404, 422 — these indicate a problem with your request, not the server. Retrying won't help and wastes quota.

## Exponential Backoff with Jitter

```ts
interface RetryConfig {
  maxAttempts: number
  baseDelayMs: number
  maxDelayMs: number
  jitter: boolean
}

function calculateDelay(attempt: number, config: RetryConfig): number {
  // Exponential: 1s, 2s, 4s, 8s...
  const exponential = config.baseDelayMs * Math.pow(2, attempt - 1)
  const capped = Math.min(exponential, config.maxDelayMs)

  if (!config.jitter) return capped

  // Full jitter: random between 0 and the calculated delay
  // Prevents thundering herd (all clients retrying at same time)
  return Math.random() * capped
}

async function withRetry<T>(
  fn: () => Promise<T>,
  config: RetryConfig = {
    maxAttempts: 3,
    baseDelayMs: 1000,
    maxDelayMs: 30_000,
    jitter: true,
  },
): Promise<T> {
  let lastError: unknown

  for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (err) {
      lastError = err

      if (!isRetryable(err)) {
        throw err  // Don't retry non-transient errors
      }

      if (attempt === config.maxAttempts) {
        break  // Last attempt — fall through to throw
      }

      const delay = calculateDelay(attempt, config)
      console.warn(`Attempt ${attempt} failed, retrying in ${Math.round(delay)}ms`)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  throw lastError
}
```

## Retry-After Header

Rate-limited APIs (Stripe, GitHub, Anthropic) return a `Retry-After` header. Respect it:

```ts
async function callWithRespectForRateLimit<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn()
  } catch (err) {
    if (err && typeof err === 'object' && 'headers' in err) {
      const headers = (err as { headers?: Record<string, string> }).headers
      const retryAfter = headers?.['retry-after']

      if (retryAfter) {
        const delayMs = parseInt(retryAfter) * 1000
        console.log(`Rate limited. Waiting ${retryAfter}s`)
        await new Promise(resolve => setTimeout(resolve, delayMs))
        return await fn()  // Single retry after waiting
      }
    }
    throw err
  }
}
```

## Idempotency Requirement

Only retry idempotent operations — ones that produce the same result if called multiple times:

```
Safe to retry:                    Do NOT retry blindly:
  GET requests                      POST (creates resource)
  Database reads                    Payment charges
  Cache lookups                     Email sends
  Idempotent writes (upsert)        File creation
```

For non-idempotent operations, use an idempotency key to make them safe to retry:

```ts
// Stripe idempotency key — same key = same result even if called twice
await stripe.charges.create(
  { amount: 5000, currency: 'usd', source: tokenId },
  { idempotencyKey: `charge-${orderId}` }  // Stable key for this charge
)
```

## Retry in Background Jobs vs Request Path

Different contexts have different tolerances:

**Request path (user waiting)**:
- Max 2-3 retries total
- Short delays (100ms-2s)
- Fail fast if not resolving

**Background jobs (overnight batch)**:
- Up to 10 retries
- Longer delays (1min-30min)
- Log failures and continue other items
- Alert after N consecutive failures

## Dead Letter Queue

When retries are exhausted, don't silently discard:

```ts
async function processWithFallback(item: JobItem) {
  try {
    await withRetry(() => processItem(item), { maxAttempts: 5, ... })
  } catch (err) {
    // Retries exhausted — send to dead letter queue for manual review
    await deadLetterQueue.add(item, {
      error: (err as Error).message,
      failedAt: new Date(),
      attempts: 5,
    })
    logger.error({ itemId: item.id, err }, 'Item sent to DLQ after exhausted retries')
  }
}
```
