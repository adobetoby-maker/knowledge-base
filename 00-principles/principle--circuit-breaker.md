# Principle: Circuit Breaker

## Overview

A circuit breaker prevents a failing external dependency from cascading failures into your application. When a downstream service is unhealthy, calls to it are short-circuited immediately rather than waiting for timeouts, preserving resources and allowing the system to degrade gracefully.

## The Three States

```
CLOSED (normal operation):
  All calls pass through
  Track failure count
  → If failures exceed threshold → OPEN

OPEN (failing):
  All calls fail immediately (no actual request)
  → After timeout period → HALF-OPEN

HALF-OPEN (testing recovery):
  Allow one test request through
  → If succeeds → CLOSED
  → If fails → OPEN (reset timeout)
```

## Why It Matters

Without circuit breaker:
```
User request → Your API → Calls Stripe → Timeout 30s
                                         (Stripe is down)
Your server holds the connection for 30 seconds
100 concurrent users = 100 threads blocked for 30s
Your server runs out of threads → YOUR service goes down
```

With circuit breaker:
```
User request → Your API → Calls Stripe → Circuit open → Fail fast <10ms
User gets graceful error immediately
Your server stays healthy
```

## Implementation

```ts
type CircuitState = 'closed' | 'open' | 'half-open'

interface CircuitBreakerConfig {
  failureThreshold: number    // Open after N failures
  recoveryTimeout: number     // ms to wait before trying half-open
  timeout: number             // ms to wait before counting as failure
}

class CircuitBreaker {
  private state: CircuitState = 'closed'
  private failureCount = 0
  private lastFailureTime = 0

  constructor(
    private readonly name: string,
    private readonly config: CircuitBreakerConfig,
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      const timeSinceFailure = Date.now() - this.lastFailureTime
      if (timeSinceFailure < this.config.recoveryTimeout) {
        throw new Error(`Circuit ${this.name} is OPEN — service unavailable`)
      }
      this.state = 'half-open'
    }

    try {
      const result = await Promise.race([
        fn(),
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error('Timeout')), this.config.timeout)
        ),
      ])

      this.onSuccess()
      return result
    } catch (err) {
      this.onFailure()
      throw err
    }
  }

  private onSuccess() {
    this.failureCount = 0
    this.state = 'closed'
  }

  private onFailure() {
    this.failureCount++
    this.lastFailureTime = Date.now()

    if (this.state === 'half-open' || this.failureCount >= this.config.failureThreshold) {
      this.state = 'open'
      console.error(`Circuit ${this.name} opened after ${this.failureCount} failures`)
    }
  }

  getState(): CircuitState {
    return this.state
  }
}
```

## Registry Pattern

```ts
// lib/circuit-breakers.ts
const breakers = new Map<string, CircuitBreaker>()

export function getCircuitBreaker(name: string): CircuitBreaker {
  if (!breakers.has(name)) {
    breakers.set(name, new CircuitBreaker(name, {
      failureThreshold: 5,
      recoveryTimeout: 60_000,  // 1 minute
      timeout: 10_000,          // 10 seconds
    }))
  }
  return breakers.get(name)!
}

// Usage
const stripeBreaker = getCircuitBreaker('stripe')

async function chargeCard(amount: number) {
  return await stripeBreaker.call(() => stripe.charges.create({ amount }))
}
```

## Fallback Behavior

A circuit breaker should be paired with a fallback:

```ts
async function getProductPrice(productId: string): Promise<number> {
  const breaker = getCircuitBreaker('pricing-service')

  try {
    return await breaker.call(() => pricingService.getPrice(productId))
  } catch {
    // Circuit open or call failed — use cached/default price
    const cached = await redis.get(`price:${productId}`)
    if (cached) return JSON.parse(cached)

    // Last resort: return default price with visible degradation
    console.warn(`Using default price for ${productId} — pricing service unavailable`)
    return DEFAULT_PRICES[productId] ?? 0
  }
}
```

## Thresholds by Service Type

| Service | Failure threshold | Recovery timeout | Call timeout |
|---------|------------------|-----------------|--------------|
| Internal API | 10 failures | 30s | 5s |
| Payment provider | 3 failures | 60s | 15s |
| Email service | 5 failures | 30s | 10s |
| Search service | 5 failures | 15s | 3s |

Payment providers warrant higher timeout (inherently slower) but lower failure threshold (important to detect degradation quickly).

## Monitoring

Log every state change:
```ts
private onFailure() {
  const prevState = this.state
  // ... failure logic ...
  if (this.state === 'open' && prevState !== 'open') {
    logger.error({ circuit: this.name, failures: this.failureCount }, 'Circuit breaker opened')
    metrics.increment('circuit_breaker.opened', { circuit: this.name })
  }
}
```

Alert on circuit breakers opening — it means a dependency is unhealthy.
