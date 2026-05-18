# Resilience Engineering Patterns

## The Core Mindset Shift

Systems fail. Networks partition. Dependencies go down. The question isn't "how do we prevent failures" — it's "how does our system behave when failures happen, and does it recover on its own?"

Resilience is the property of returning to normal after disruption. It's designed in, not bolted on after an outage.

## Retry (Idempotent Operations Only)

Retry a failed request after a delay. Simple, effective — when used correctly.

The constraint: **only retry idempotent operations**. An idempotent operation produces the same result whether applied once or a hundred times. GET is always safe. POST is safe only if you control the semantics (payment charge is not idempotent — double-retry = double charge).

Retry patterns:
- **Immediate retry**: once, immediately. Useful only for transient network hiccups.
- **Fixed delay**: retry every N seconds. Simple but wastes time on longer outages.
- **Exponential backoff with jitter**: `delay = base * 2^attempt + random(0, base)`. Prevents thundering herd when 1000 clients all retry simultaneously after a service restart. Jitter is not optional.

Always set a max retry count. Infinite retry loops mask bugs and keep connections open that should fail fast.

## Circuit Breaker

Retrying a service that's down amplifies the problem: the failing service gets hammered while it's trying to recover, callers pile up threads waiting for timeouts, and everything degrades together.

The circuit breaker has three states:

- **Closed** (normal): requests flow through; failures are counted
- **Open** (tripped): requests fail immediately without calling the dependency; checked after `recovery_timeout`
- **Half-Open** (testing): one probe request let through; if it succeeds, close the circuit; if it fails, return to open

```typescript
class CircuitBreaker {
  private failures = 0;
  private lastFailure: number | null = null;
  private state: "closed" | "open" | "half-open" = "closed";

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === "open") {
      if (Date.now() - this.lastFailure! > this.recoveryTimeout) {
        this.state = "half-open";
      } else {
        throw new CircuitOpenError();
      }
    }
    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (err) {
      this.onFailure();
      throw err;
    }
  }
}
```

Circuit breakers require monitoring: expose `circuit_state` as a metric. An open circuit that nobody notices is a hidden outage.

## Bulkhead (Isolate Failure Domains)

Named after the compartmentalized hull sections of a ship. A bulkhead limits how much of the system a failure can infect.

In practice: give different downstream dependencies their own isolated resource pools (thread pools, connection pools, rate limits). If the payment service is slow and starts consuming all 100 connections, the inventory service shouldn't be starved.

```typescript
// Each dependency gets its own pool
const paymentPool = new ConnectionPool({ max: 20 });
const inventoryPool = new ConnectionPool({ max: 20 });
const notificationPool = new ConnectionPool({ max: 10 });
```

Without bulkheads, one slow dependency can cause cascading failure across the entire application. With bulkheads, the blast radius is bounded.

## Timeout + Fallback

Every external call must have a timeout. "Wait forever" is not an availability strategy — it's a thread leak waiting to happen.

Set timeouts at the lowest sensible level for each dependency. A database query should complete in under 1 second; set a 2-second timeout. A third-party API might need 5 seconds.

Fallbacks define what happens when a call times out or fails:

- Return cached data (stale is often better than nothing)
- Return a safe default (empty list, null, "unavailable" state)
- Redirect to a degraded mode (show checkout but disable coupon validation)
- Queue for async retry (non-blocking, process when healthy)

Not every failure has a meaningful fallback. For payments, the fallback is "tell the user to try again" — don't silently succeed and charge later.

## Chaos Engineering: Inject Failures to Find Weak Points

You can't prove your resilience patterns work until they've been tested under real failure conditions. Chaos engineering deliberately injects failures in a controlled way:

- Kill a pod/instance and verify auto-restart and traffic rerouting work
- Introduce artificial latency (300ms) on a dependency and verify circuit breaker trips
- Block a database connection and verify bulkhead prevents full system degradation
- Inject packet loss on a network path and verify retry+backoff handles it

Start in staging. Graduate to production during low-traffic windows. The goal is to discover weak points before incidents do.

Tools: Netflix Chaos Monkey, Gremlin, `tc` (Linux traffic control for network chaos), AWS Fault Injection Service.

## Key Rules

- Retry only idempotent operations; use exponential backoff with jitter; set a max retry count
- Circuit breaker prevents retry storms; expose its state as a metric and alert on open circuits
- Bulkhead gives each dependency its own resource pool; prevents one slow dependency from taking down everything
- Every external call needs a timeout; every timeout path needs a defined fallback behavior
- Chaos engineering is not optional for production systems — test your resilience patterns under real failure before your users do
- Design for graceful degradation: reduced functionality beats total failure
