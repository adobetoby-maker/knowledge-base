# Skill: Service-to-Service Communication Patterns

## Overview
When services call each other, every call is a potential failure point. Networks partition, services restart, dependencies slow down. Without circuit breakers and timeouts, one slow downstream service cascades into full system failure. These patterns make your service call as safe as a local function call — it either returns, fails fast, or degrades gracefully.

## Implementation

### 1. Health check endpoints (required for orchestrators)
```ts
// Every service must expose /health — two types serve different purposes
app.get('/health/live', (req, res) => {
  // Liveness: "Should this process be killed and restarted?"
  // Only fail if the process is truly broken (deadlock, OOM)
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/health/ready', async (req, res) => {
  // Readiness: "Should this instance receive traffic?"
  // Fail if dependencies aren't ready (DB connection, cache, etc.)
  try {
    await db.execute(sql`SELECT 1`);
    res.json({ status: 'ok' });
  } catch {
    res.status(503).json({ status: 'not ready', reason: 'db unreachable' });
  }
});
```

### 2. Circuit breaker at the call site
```ts
import CircuitBreaker from 'opossum';

// Wrap any external call in a circuit breaker
const options = {
  timeout: 3000,         // fail if call takes > 3s
  errorThresholdPercentage: 50,  // open circuit if 50% of calls fail
  resetTimeout: 30_000,  // try again after 30s
  volumeThreshold: 5,    // min calls before circuit can open
};

const breaker = new CircuitBreaker(fetchFromInventoryService, options);

breaker.on('open', () => console.warn('Circuit OPEN: inventory-service failing'));
breaker.on('halfOpen', () => console.log('Circuit HALF-OPEN: testing recovery'));
breaker.on('close', () => console.log('Circuit CLOSED: inventory-service recovered'));

// Provide fallback for degraded operation
breaker.fallback(() => ({ inStock: null, message: 'Inventory unavailable' }));

// Usage — identical to direct call
const inventory = await breaker.fire(productId);
```

### 3. Request ID propagation (distributed tracing prerequisite)
```ts
import { AsyncLocalStorage } from 'async_hooks';
import { randomUUID } from 'crypto';

const requestContext = new AsyncLocalStorage<{ requestId: string; userId?: string }>();

// Middleware: establish or propagate request ID
app.use((req, res, next) => {
  const requestId = req.headers['x-request-id'] as string || randomUUID();
  res.setHeader('x-request-id', requestId);
  requestContext.run({ requestId }, next);
});

// When calling another service — propagate the same ID
async function callOrderService(orderId: string) {
  const ctx = requestContext.getStore();
  
  const response = await fetch(`${ORDER_SERVICE_URL}/orders/${orderId}`, {
    headers: {
      'x-request-id': ctx?.requestId ?? randomUUID(),  // critical for trace correlation
      'x-user-id': ctx?.userId ?? '',
    },
    signal: AbortSignal.timeout(5000),  // timeout every outbound call
  });
  
  if (!response.ok) throw new ServiceError(response.status, await response.text());
  return response.json();
}
```

### 4. Retry only idempotent operations
```ts
async function withRetry<T>(
  fn: () => Promise<T>,
  { maxAttempts = 3, delay = 200, isIdempotent = false }
): Promise<T> {
  let lastErr: Error;
  
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err as Error;
      
      // Never retry non-idempotent operations (POST creates, payments)
      if (!isIdempotent) throw err;
      
      // Don't retry client errors (400, 401, 403, 404) — they won't change
      if (err instanceof ServiceError && err.status < 500) throw err;
      
      if (attempt < maxAttempts) {
        await new Promise(r => setTimeout(r, delay * 2 ** (attempt - 1)));  // exponential backoff
      }
    }
  }
  
  throw lastErr!;
}

// Safe to retry: GET, PUT (update same resource), DELETE (idempotent)
const order = await withRetry(() => callOrderService(id), { isIdempotent: true });

// Never retry: POST /payments, POST /emails
const payment = await callPaymentService(data);  // no retry wrapper
```

### 5. Timeout budget prevents cascading failure
```ts
// Each hop in a call chain must reduce the deadline
// If total budget is 10s, don't give 10s to a downstream call — leave room for your own work
async function handleRequest(totalBudgetMs = 10_000) {
  const start = Date.now();
  const remaining = () => totalBudgetMs - (Date.now() - start);

  // Each downstream call gets a slice of remaining budget
  const inventory = await Promise.race([
    callInventory(),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('timeout')), Math.min(3000, remaining()))
    ),
  ]);
}
```

## Key Rules
- **Liveness ≠ readiness** — liveness failing restarts the process; readiness failing removes it from the load balancer. Never check DB in liveness.
- **Every outbound call needs a timeout** — no timeout means a slow dependency hangs your server's thread pool.
- **Retry only idempotent operations** — retrying a payment charge or email send causes duplicate side effects.
- Circuit breakers prevent retry storms — when a dependency is down, stop hammering it immediately.
- Propagate `x-request-id` on every downstream call — without it, distributed traces are disconnected and debugging production incidents is nearly impossible.
- The retry budget across the entire call chain must be less than the client's timeout — otherwise downstream retries cause the client to always time out.
- Log circuit state changes as warnings — `OPEN` is a signal that requires investigation.
