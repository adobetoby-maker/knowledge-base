# Agent Pattern: Rate Limiting Agent API Calls

## Relationship to Rate-Limit Handling

`agents--rate-limit-handling.md` covers detecting 429 responses and using the retry-after header. This file covers proactive rate limiting: building concurrency controls and request scheduling so 429s are rare in the first place, plus priority queuing so critical requests get through when capacity is constrained.

## Token Bucket for Request Rate

A token bucket refills at a fixed rate and is consumed by each request. Requests that would overdraw wait until enough tokens are available. This smooths bursty request patterns into a steady rate:

```typescript
class TokenBucket {
  private tokens: number
  private lastRefill: number

  constructor(
    private capacity: number,        // max burst size
    private refillRate: number,      // tokens per second
  ) {
    this.tokens = capacity
    this.lastRefill = Date.now()
  }

  async acquire(cost: number = 1): Promise<void> {
    this.refill()
    if (this.tokens >= cost) {
      this.tokens -= cost
      return
    }
    const waitMs = ((cost - this.tokens) / this.refillRate) * 1000
    await sleep(waitMs)
    this.tokens = 0
    return
  }

  private refill(): void {
    const now = Date.now()
    const elapsed = (now - this.lastRefill) / 1000
    this.tokens = Math.min(this.capacity, this.tokens + elapsed * this.refillRate)
    this.lastRefill = now
  }
}
```

Set `capacity` to the burst your API tier allows (e.g., 50 requests) and `refillRate` to the sustained rate (e.g., 1000 RPM → 16.7/s). Token cost should reflect the actual weight of the request — a call that uses 10K tokens costs more against the token-per-minute limit than one that uses 1K.

## Concurrent Request Semaphore

The token bucket controls rate over time. A semaphore controls how many requests are in-flight simultaneously. Both are needed: rate without concurrency control allows bursts that overwhelm downstream; concurrency without rate control limits throughput unnecessarily.

```typescript
class Semaphore {
  private count: number
  private queue: Array<() => void> = []

  constructor(private limit: number) {
    this.count = limit
  }

  async acquire(): Promise<void> {
    if (this.count > 0) {
      this.count--
      return
    }
    return new Promise(resolve => this.queue.push(resolve))
  }

  release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift()!
      next()
    } else {
      this.count++
    }
  }

  async run<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire()
    try {
      return await fn()
    } finally {
      this.release()
    }
  }
}
```

Right-sizing the semaphore: start at concurrency = (RPM limit / 60) × average_latency_seconds. For 1000 RPM and 2s average latency, that is ~33 concurrent requests at the limit. Use 60-70% of that headroom as your default: ~20.

## Exponential Backoff on 429

Even with a token bucket and semaphore, 429s happen — API limits reset at server time, not client time; other processes share the quota; limits are per-key not per-process. When a 429 arrives:

```typescript
async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 4,
  baseDelayMs: number = 1000,
): Promise<T> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (err) {
      if (!is429(err) || attempt === maxAttempts - 1) throw err
      const retryAfter = getRetryAfterMs(err) ?? baseDelayMs * 2 ** attempt
      await sleep(retryAfter + jitter(500))
    }
  }
  throw new Error('unreachable')
}
```

Always use the `retry-after` header when present — it is the authoritative wait time. Fall back to exponential backoff with jitter when the header is absent. Jitter prevents synchronized retry storms when many requests hit the limit simultaneously.

## Priority Queuing

When capacity is constrained, critical requests (user-facing, blocking workflows) should preempt background work (batch jobs, analytics, non-urgent enrichment):

```typescript
const HIGH = 0
const MEDIUM = 1
const LOW = 2

class PriorityRequestQueue {
  private queues: Array<Array<() => void>> = [[], [], []]

  enqueue(fn: () => void, priority: number = MEDIUM): void {
    this.queues[priority].push(fn)
  }

  dequeue(): (() => void) | undefined {
    for (const queue of this.queues) {
      if (queue.length > 0) return queue.shift()
    }
  }
}
```

Assign priority at the call site based on context: user-initiated requests → HIGH; background batch workers → LOW; scheduled enrichment → MEDIUM. LOW-priority work may be delayed during peak periods; that is intentional.

## Key Rules

- Token bucket for rate control; semaphore for concurrency control — both are needed together
- Size semaphore at 60-70% of theoretical max to leave headroom for latency variance
- Use `retry-after` header when available — it is more accurate than computed backoff
- Add jitter to backoff — synchronized retries from a fleet amplify 429 storms
- Priority queuing ensures user-facing requests are never blocked by background batch work
- Token cost should reflect actual API weight — a large prompt costs more than a small one
- Log the rate at which 429s are received; sustained 429s mean the bucket parameters are wrong
