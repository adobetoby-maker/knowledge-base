# Agent Pattern: Rate Limit Handling

## Overview

LLM APIs (Anthropic, OpenAI) and external services have rate limits. Agents in automated pipelines will hit them — especially in parallel or overnight batch scenarios. This guide covers detecting, waiting, and working within limits.

## Anthropic API Rate Limits

Limits vary by tier. Typical production limits:
- **RPM (Requests per Minute)**: 50-4000 depending on tier
- **TPM (Tokens per Minute)**: 500K-50M
- **TPD (Tokens per Day)**: 5M-unlimited

Headers on every response:
```
x-ratelimit-limit-requests: 1000
x-ratelimit-remaining-requests: 987
x-ratelimit-reset-requests: 2026-05-18T02:00:00Z
x-ratelimit-limit-tokens: 80000
x-ratelimit-remaining-tokens: 60234
x-ratelimit-reset-tokens: 2026-05-18T02:00:00Z
```

## Detecting Rate Limit Errors

```ts
function isRateLimitError(err: unknown): boolean {
  if (err && typeof err === 'object') {
    // HTTP 429 status
    if ('status' in err && err.status === 429) return true
    // Anthropic SDK error
    if ('error' in err && typeof err.error === 'object' && err.error !== null) {
      const error = err.error as { type?: string }
      if (error.type === 'rate_limit_error') return true
    }
    // Message contains rate limit info
    if ('message' in err && typeof err.message === 'string') {
      if (err.message.includes('rate limit') || err.message.includes('429')) return true
    }
  }
  return false
}
```

## Retry with Exponential Backoff

```ts
async function callLLMWithRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 5,
): Promise<T> {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (err) {
      if (!isRateLimitError(err)) throw err  // Not rate limit — don't retry
      if (attempt === maxAttempts) throw err

      // Extract Retry-After header if available
      const retryAfter = extractRetryAfter(err)
      const backoff = retryAfter
        ? retryAfter * 1000
        : Math.min(1000 * Math.pow(2, attempt), 60_000) + Math.random() * 1000

      console.log(`Rate limited. Waiting ${Math.round(backoff / 1000)}s (attempt ${attempt}/${maxAttempts})`)
      await new Promise(r => setTimeout(r, backoff))
    }
  }
  throw new Error('Unreachable')
}

function extractRetryAfter(err: unknown): number | null {
  if (err && typeof err === 'object' && 'headers' in err) {
    const headers = (err as { headers?: Record<string, string> }).headers
    const retryAfter = headers?.['retry-after']
    if (retryAfter) return parseInt(retryAfter)
  }
  return null
}
```

## Token Budget Management

Estimate tokens before calling to avoid hitting TPM limits:

```ts
function estimateTokens(text: string): number {
  // Conservative estimate: 1 token per 3 characters (English text)
  return Math.ceil(text.length / 3)
}

class TokenBudgetManager {
  private usedThisMinute = 0
  private minuteStart = Date.now()
  private readonly limitPerMinute: number

  constructor(limitPerMinute: number) {
    this.limitPerMinute = limitPerMinute
  }

  async waitForBudget(estimatedTokens: number): Promise<void> {
    const elapsed = Date.now() - this.minuteStart

    if (elapsed >= 60_000) {
      // Reset window
      this.usedThisMinute = 0
      this.minuteStart = Date.now()
    }

    if (this.usedThisMinute + estimatedTokens > this.limitPerMinute) {
      const waitMs = 60_000 - elapsed + 1000  // Wait until next minute
      console.log(`Token budget: waiting ${Math.round(waitMs / 1000)}s for next window`)
      await new Promise(r => setTimeout(r, waitMs))
      this.usedThisMinute = 0
      this.minuteStart = Date.now()
    }

    this.usedThisMinute += estimatedTokens
  }
}
```

## Concurrency Limiting

For batch agents, limit concurrent LLM calls:

```ts
class ConcurrencyLimiter {
  private running = 0
  private queue: Array<() => void> = []

  constructor(private readonly max: number) {}

  async run<T>(fn: () => Promise<T>): Promise<T> {
    if (this.running >= this.max) {
      await new Promise<void>(resolve => this.queue.push(resolve))
    }

    this.running++
    try {
      return await fn()
    } finally {
      this.running--
      this.queue.shift()?.()
    }
  }
}

// Limit to 5 concurrent LLM calls
const limiter = new ConcurrencyLimiter(5)

const results = await Promise.all(
  items.map(item => limiter.run(() => processItem(item)))
)
```

## Tier-Specific Settings

Adjust defaults to your API tier:

| Tier | Max concurrent | Delay between batches |
|------|---------------|----------------------|
| Tier 1 (new) | 2-3 | 2s |
| Tier 2 | 5 | 500ms |
| Tier 3 | 10 | 100ms |
| Tier 4 | 20+ | 0ms |

Check your tier at console.anthropic.com → Usage limits.

## Graceful Degradation

When rate limits are hit in user-facing flows (not batch):

```ts
async function analyzeWithFallback(text: string): Promise<string> {
  try {
    return await callLLMWithRetry(() => analyze(text), 2)  // Quick retry only
  } catch (err) {
    if (isRateLimitError(err)) {
      // Queue for async processing instead of failing
      await jobQueue.add('analyze', { text, createdAt: new Date() })
      return 'Your request is queued and will complete shortly.'
    }
    throw err
  }
}
```

Don't make users wait indefinitely for rate-limit retries in synchronous flows. Queue and process asynchronously.
