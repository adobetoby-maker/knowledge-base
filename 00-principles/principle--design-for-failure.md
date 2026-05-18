# Principle: Design for Failure

## Overview

Distributed systems fail. Networks partition, third-party APIs go down, databases timeout, and servers crash. The question isn't whether a component will fail — it's whether the system degrades gracefully when it does. Design every integration point as if it will fail regularly.

## Failure Modes to Anticipate

| Integration | Common failures |
|---|---|
| Database | Connection timeout, pool exhaustion, slow query, deadlock |
| External API | 429 rate limit, 503 down, slow response, changed schema |
| Object storage | Upload timeout, permission error, propagation delay |
| Email provider | Bounce, rate limit, authentication failure |
| Payment processor | Network error, invalid card, 3DS challenge |
| Background jobs | Worker crash mid-job, duplicate execution, infinite loop |

## Circuit Breaker Pattern

Stop hammering a failing dependency — fail fast and recover:

```ts
class CircuitBreaker {
  private failures = 0
  private lastFailure = 0
  private state: 'closed' | 'open' | 'half-open' = 'closed'

  constructor(
    private readonly threshold = 5,
    private readonly timeout = 60_000  // 60s recovery window
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailure > this.timeout) {
        this.state = 'half-open'
      } else {
        throw new Error('Circuit open — service unavailable')
      }
    }

    try {
      const result = await fn()
      this.onSuccess()
      return result
    } catch (err) {
      this.onFailure()
      throw err
    }
  }

  private onSuccess() {
    this.failures = 0
    this.state = 'closed'
  }

  private onFailure() {
    this.failures++
    this.lastFailure = Date.now()
    if (this.failures >= this.threshold) {
      this.state = 'open'
      logger.warn({ failures: this.failures }, 'Circuit opened')
    }
  }
}

const emailCircuit = new CircuitBreaker(5, 30_000)

async function sendEmail(to: string, subject: string, body: string) {
  await emailCircuit.call(() => resend.emails.send({ from, to, subject, html: body }))
}
```

## Timeout Everything

Unconstrained external calls will hang indefinitely:

```ts
// Native fetch with AbortController
async function fetchWithTimeout<T>(url: string, timeout = 5000): Promise<T> {
  const controller = new AbortController()
  const id = setTimeout(() => controller.abort(), timeout)
  try {
    const res = await fetch(url, { signal: controller.signal })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return res.json()
  } finally {
    clearTimeout(id)
  }
}

// Axios
const api = axios.create({ timeout: 5000 })

// DB query timeout (Drizzle/pg)
await db.execute(sql`SET statement_timeout = '5s'`)
```

## Retry with Exponential Backoff

```ts
async function withRetry<T>(
  fn: () => Promise<T>,
  maxAttempts = 3,
  baseDelay = 1000
): Promise<T> {
  let attempt = 0

  while (attempt < maxAttempts) {
    try {
      return await fn()
    } catch (err) {
      attempt++
      if (attempt >= maxAttempts) throw err

      // Don't retry client errors (4xx) — only server errors (5xx) and network errors
      if (err instanceof Response && err.status < 500) throw err

      const delay = baseDelay * Math.pow(2, attempt - 1) + Math.random() * 200  // Jitter
      logger.warn({ attempt, delay }, 'Retrying after failure')
      await new Promise(r => setTimeout(r, delay))
    }
  }

  throw new Error('Max retries exceeded')
}
```

## Graceful Degradation

When a non-critical service fails, degrade rather than fail entirely:

```ts
async function getProductRecommendations(userId: string): Promise<Product[]> {
  try {
    return await recommendationEngine.get(userId)
  } catch {
    logger.warn({ userId }, 'Recommendation engine unavailable — using fallback')
    return getBestsellersFallback()  // Static popular products
  }
}

async function getUserAvatar(userId: string): Promise<string> {
  try {
    return await avatarService.get(userId)
  } catch {
    return '/default-avatar.png'  // Always available
  }
}
```

## Idempotency for Safe Retries

Make operations safe to retry:

```ts
// Use idempotency keys for payment/critical operations
async function chargeCustomer(amount: number, customerId: string, idempotencyKey: string) {
  return stripe.paymentIntents.create({
    amount,
    currency: 'usd',
    customer: customerId,
  }, {
    idempotencyKey,  // Same key = same result, not double charge
  })
}

// Generate a stable key from the operation context
const key = `order-${orderId}-charge`
await chargeCustomer(amount, customerId, key)
```

## Dead Letter Queue

For background jobs that fail repeatedly:

```ts
export const processWebhook = inngest.createFunction(
  {
    id: 'process-webhook',
    retries: 5,
    onFailure: async ({ event, error }) => {
      // After all retries exhausted, write to DLQ
      await db.insert(deadLetterQueue).values({
        eventName: event.name,
        eventData: event.data,
        error: error.message,
        failedAt: new Date(),
      })
      await alertOncall('Webhook processing failed after retries', error)
    },
  },
  { event: 'webhook/received' },
  async ({ event }) => { /* ... */ }
)
```

## Key Rules

- Every external call needs a timeout — default network timeout is "forever".
- Retry only idempotent operations — retrying a non-idempotent operation can cause double-charges.
- Log failures with context (what failed, how many times, what was retried) before giving up.
- Separate critical paths from degradable features — checkout must work; recommendations can fail.
- Test failure modes in staging: kill the email service, disconnect the DB, inject slow responses.
