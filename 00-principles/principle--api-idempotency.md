# Principle: API Idempotency

## Overview
Network requests fail. Clients retry. Without idempotency, a retry of a "create order" request creates two orders; a retry of a "charge card" request charges the customer twice. Idempotency is the guarantee that performing the same operation multiple times produces the same result as performing it once. It is not optional for any endpoint that mutates state — it is a correctness requirement.

## The Idempotency Key Pattern

The client generates a unique key per logical operation and sends it with every attempt:

```
POST /api/payments
Idempotency-Key: 7f8d9e2a-4b3c-41d8-a5f6-1234567890ab
Content-Type: application/json

{ "amount": 4999, "currency": "usd", "customerId": "cust_123" }
```

The server:
1. Looks up the key in a store (Redis, DB table)
2. If found: return the cached response immediately — no re-execution
3. If not found: execute the operation, store `key → result`, return result

```typescript
async function handlePayment(req: Request) {
  const key = req.headers.get("Idempotency-Key");
  if (!key) return error(400, "Idempotency-Key header required");

  // Check cache first
  const cached = await redis.get(`idem:${key}`);
  if (cached) {
    return Response.json(JSON.parse(cached), { status: 200 });
  }

  // Execute operation
  const result = await chargeCard(req.body);

  // Store result with TTL (24h is typical)
  await redis.set(`idem:${key}`, JSON.stringify(result), "EX", 86400);

  return Response.json(result, { status: 201 });
}
```

## Which Endpoints Need Idempotency Keys

Any endpoint that:
- Creates a record (`POST /orders`, `POST /payments`)
- Sends a communication (`POST /emails`, `POST /sms`)
- Transfers money or credits
- Triggers an irreversible side effect

`GET` and `DELETE` are already idempotent by HTTP semantics (GET has no side effects; deleting a deleted thing is still "deleted"). `PUT` with a full resource is idempotent by design. Only `POST` and `PATCH` typically need explicit idempotency keys.

## The Race Condition Problem

Two concurrent requests with the same key can both miss the cache and both execute:

```typescript
// Wrong: race condition between check and set
const cached = await redis.get(key);
if (cached) return JSON.parse(cached);
const result = await doWork();       // ← two requests can both reach here
await redis.set(key, result);
```

Fix with atomic locking:
```typescript
// Right: atomic set-if-not-exists
const lock = await redis.set(`lock:${key}`, "1", "NX", "EX", 30);
if (!lock) {
  // Another request is processing — wait and return its result
  await sleep(100);
  const cached = await redis.get(`idem:${key}`);
  return cached ? JSON.parse(cached) : error(409, "Concurrent request");
}
try {
  const result = await doWork();
  await redis.set(`idem:${key}`, JSON.stringify(result), "EX", 86400);
  return result;
} finally {
  await redis.del(`lock:${key}`);
}
```

## Client Responsibilities
- Generate UUIDs client-side (not server-generated) — the client is the authority on "this is the same logical operation"
- Retry with the **same** key on network error, timeout, or 5xx
- Do not retry on 4xx (client error) — the server correctly rejected the request
- Keep keys unique per logical operation — same order = same key, different order = different key

## Stripe's Implementation as Reference
Stripe requires `Idempotency-Key` on all POST requests to their API. They store keys for 24 hours and return the exact same response for duplicate requests, including the same `id` for the resource created on the first attempt. This is the gold standard pattern.

## Key Rules
- Required on: POST endpoints that create resources, send messages, charge money
- Client generates UUIDs, not the server
- Store key → response (not key → boolean) so duplicate requests get the full original response
- TTL of 24 hours minimum; Stripe uses 24h
- Atomic check-and-set to prevent race conditions
- Log when a cached result is returned (helps debug "why did my order not create?")
