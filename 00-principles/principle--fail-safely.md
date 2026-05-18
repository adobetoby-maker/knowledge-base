# Principle: Fail Safely

## Overview
When a system encounters an error or uncertainty, the safe default is to do nothing rather than to guess, approximate, or proceed. "Fail safe" means the system defaults to the state that prevents harm — rejecting an order when the payment processor is unreachable is safer than charging the customer later; denying access when the auth service is down is safer than allowing unauthenticated entry. The principle sounds obvious but is violated constantly in practice, usually in the name of "better user experience" or "availability."

## Implementation

### Fail-Safe vs Fail-Open Decision Matrix
```
System             Fail-Safe (reject)          Fail-Open (allow)
Payment            ✓ Always                    ✗ Never
Auth/session       ✓ Deny access               ✗ Only if availability > security (internal tools)
Rate limiting      ✓ Block requests            ✓ Allow on limiter failure (tradeoff)
Feature flags      ✓ Show default/off          ✗ Only if "off" is worse UX than stale flag
Email sending      ✗ Queue and retry           N/A
Search             ✗ Show empty results        N/A — no safety concern
```

### Payment Processor Down
```ts
async function processPayment(amount: number, paymentMethod: string) {
  try {
    const result = await paymentProcessor.charge(amount, paymentMethod);
    return result;
  } catch (err) {
    if (isNetworkError(err) || isTimeout(err)) {
      // SAFE: reject. Do not proceed, do not guess.
      throw new Error('Payment service unavailable. Please try again in a few minutes.');
    }
    if (isDecline(err)) {
      throw new Error('Payment declined.');
    }
    throw err;
  }
}

// WRONG: "Let's allow the order and try to charge later"
// This creates unfunded orders, chargebacks, and customer service nightmares.
```

### Auth Service Down
```ts
async function authenticate(token: string): Promise<User> {
  try {
    return await authService.verify(token);
  } catch (err) {
    if (isServiceUnavailable(err)) {
      // SAFE: deny access
      throw new AuthError('Authentication service unavailable. Please try again.', 503);
      // WRONG: return cached session without verification
    }
    throw err;
  }
}
```

### Circuit Breaker for Downstream Dependencies
The circuit breaker pattern implements fail-safe at the integration layer: after N consecutive failures, stop trying and return an immediate error instead of waiting for timeouts.

```ts
class CircuitBreaker {
  private failures = 0;
  private lastFailure = 0;
  private state: 'closed' | 'open' | 'half-open' = 'closed';

  constructor(
    private threshold = 5,
    private timeout = 60_000
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'open') {
      if (Date.now() - this.lastFailure > this.timeout) {
        this.state = 'half-open';
      } else {
        throw new Error('Circuit breaker open — service unavailable');
      }
    }

    try {
      const result = await fn();
      this.failures = 0;
      this.state = 'closed';
      return result;
    } catch (err) {
      this.failures++;
      this.lastFailure = Date.now();
      if (this.failures >= this.threshold) {
        this.state = 'open';
      }
      throw err;
    }
  }
}
```

### Feature Flag Defaults
Feature flags should default to the conservative/safe behavior when the flag service is unavailable:
```ts
async function isFeatureEnabled(flag: string, userId: string): Promise<boolean> {
  try {
    return await featureService.check(flag, userId);
  } catch {
    // Default to OFF when the feature flag service is down
    // New features are risky; it's safer to show the old behavior
    return false;
  }
}
```

### Documenting Fail-Safe Decisions
```ts
// FAIL-SAFE: We return false (deny action) when the permission service is unreachable.
// RATIONALE: The cost of a brief access denial is lower than the cost of unauthorized action.
// FAIL-OPEN ALTERNATIVE CONSIDERED: Rejected because this controls delete operations.
async function canDeleteResource(userId: string, resourceId: string): Promise<boolean> {
  try {
    return await permissionService.check(userId, 'delete', resourceId);
  } catch {
    return false; // deny
  }
}
```

## Key Rules
- Default to "no" when uncertain — the burden of proof is on allowing the action, not blocking it.
- Payment and auth systems must always fail safe — the cost of a false denial is lower than a false allow.
- Rate limiters may fail open when availability is the primary concern — this is a documented exception, not a default.
- Document every fail-safe decision: what is the safe state, what alternative was considered, why this choice was made.
- Never retry a payment without verifying the original transaction status first — duplicate charges are worse than a rejected order.
- Circuit breakers make fail-safe automatic: after repeated failures, they stop calling the failing service and return the safe state immediately.
- Fail-safe is not the same as fail-silent — the user must know that the operation failed and what to do next.
