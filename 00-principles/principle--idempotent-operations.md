# Principle: Idempotent Operations

## Overview
An operation is idempotent if performing it multiple times produces the same result as performing it once. Idempotency is not an optimization — it is what makes distributed systems reliable. Networks fail, timeouts occur, and clients retry. Without idempotency, retries cause duplicate charges, duplicate emails, double-insertions, and corrupted state. With idempotency, retries are safe, which enables automatic retry logic, which enables reliable systems.

## Implementation

### Three Paths to Idempotency

**1. Natural idempotency: PUT with full state**
```http
PUT /api/users/123
{ "name": "Alice", "email": "alice@example.com" }
```
Sending this request twice sets the same values twice — identical result. This is the easiest form.

**2. Idempotency key: client-generated UUID**
```ts
// Client generates a UUID per logical operation
const idempotencyKey = crypto.randomUUID();

const response = await fetch('/api/payments', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Idempotency-Key': idempotencyKey,
  },
  body: JSON.stringify({ amount: 5000, currency: 'usd' }),
});

// If this fails (network error, timeout), retry with the SAME key
```

**Server-side deduplication:**
```ts
// POST /api/payments
async function POST(req: Request) {
  const idempotencyKey = req.headers.get('Idempotency-Key');

  if (idempotencyKey) {
    // Check if we've seen this key before
    const existing = await db.idempotencyKeys.findOne({ where: { key: idempotencyKey } });
    if (existing) {
      // Return the same response as the original request
      return Response.json(existing.responseBody, { status: existing.responseStatus });
    }
  }

  // Process the request
  const result = await processPayment(req);

  // Store the result with the idempotency key
  if (idempotencyKey) {
    await db.idempotencyKeys.create({
      key: idempotencyKey,
      responseBody: result,
      responseStatus: 201,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24h TTL
    });
  }

  return Response.json(result, { status: 201 });
}
```

**3. Check-then-set with unique constraint**
```sql
-- The unique constraint prevents duplicate inserts at the DB level
INSERT INTO payments (id, user_id, amount, idempotency_key)
VALUES ($1, $2, $3, $4)
ON CONFLICT (idempotency_key) DO NOTHING
RETURNING *;
```

```ts
async function createPaymentIdempotent(data: PaymentInput) {
  const result = await db.query(`
    INSERT INTO payments (id, user_id, amount_cents, idempotency_key, created_at)
    VALUES ($1, $2, $3, $4, now())
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING *
  `, [uuid(), data.userId, data.amountCents, data.idempotencyKey]);

  if (result.rows.length === 0) {
    // Already existed — return the existing record
    return db.payments.findOne({ where: { idempotencyKey: data.idempotencyKey } });
  }

  return result.rows[0];
}
```

### HTTP Method Idempotency Table
```
Method    Idempotent?   Safe?    Notes
GET       ✓ Yes         ✓ Yes    No side effects
PUT       ✓ Yes         ✗ No     Replace entire resource
DELETE    ✓ Yes         ✗ No     Second DELETE returns 404, not error — same final state
POST      ✗ No*         ✗ No     Requires idempotency key for safe retry
PATCH     ✗ No*         ✗ No     "increment by 1" is not idempotent; "set to 5" is
```

### Stripe API Idempotency
```ts
const paymentIntent = await stripe.paymentIntents.create(
  { amount: 5000, currency: 'usd' },
  { idempotencyKey: `pi-${orderId}` }
);
// Retry with same idempotencyKey → returns same PaymentIntent, no new charge
```

### Idempotency for Background Jobs
```ts
// Use natural key as deduplication signal
async function sendWelcomeEmail(userId: string) {
  // Check if already sent
  const alreadySent = await db.emailLog.findOne({
    where: { userId, type: 'welcome' }
  });
  if (alreadySent) return; // idempotent: skip duplicate

  await emailService.send(userId, 'welcome');
  await db.emailLog.create({ userId, type: 'welcome', sentAt: new Date() });
}
```

## Key Rules
- Every mutation that might be retried must be idempotent — timeouts always produce retries.
- PUT is naturally idempotent; POST is not — design APIs to use PUT where idempotency matters.
- DELETE should return 200/204 on second call if the resource is already gone — returning 404 on retry breaks idempotency guarantees for clients.
- Idempotency keys expire — 24 hours is standard (long enough to cover any reasonable retry window).
- Using `orderId` as the idempotency key is better than `crypto.randomUUID()` — it's deterministic across retry attempts and doesn't require the client to store a separate key.
- The server must return the SAME response body on duplicate requests — clients may use the response to navigate, and a different response body breaks this.
- Database unique constraints are the most reliable idempotency guarantee — they're enforced even if your application code has bugs.
