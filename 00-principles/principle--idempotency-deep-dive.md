# Principle: Idempotency Deep Dive

## What Idempotency Means in Practice

An idempotent operation produces the same result regardless of how many times it runs. Running it once or ten times leaves the system in the same state.

This matters because:
- Network requests fail and get retried
- Webhooks are delivered multiple times
- Cron jobs fire multiple times if the previous run was still running
- Users double-click buttons
- Deployments restart mid-job

Every one of these scenarios can cause double-processing without idempotency.

## Where Idempotency Fails

### Database Inserts

```ts
// NOT idempotent — creates a duplicate row if called twice
await supabase.from('orders').insert({ user_id, total_cents, status: 'pending' })

// Idempotent — upsert on a unique key
await supabase
  .from('orders')
  .upsert({ id: orderId, user_id, total_cents, status: 'pending' }, { onConflict: 'id' })
```

### Stripe Payments

```ts
// NOT idempotent — creates two charges if called twice
await stripe.charges.create({ amount, currency, source })

// Idempotent — Stripe deduplicates by idempotency key
await stripe.charges.create(
  { amount, currency, source },
  { idempotencyKey: `charge-${orderId}` },
)
```

Use a stable key derived from your business entity (order ID, invoice ID) not a random value. A random key per-call defeats the purpose.

### Email Sending

```ts
// NOT idempotent — sends duplicate emails
async function sendOrderConfirmation(orderId: string) {
  await sendEmail({ to: order.email, subject: 'Order confirmed' })
}

// Idempotent — track sent emails
async function sendOrderConfirmation(orderId: string) {
  const { data: alreadySent } = await supabase
    .from('sent_emails')
    .select('id')
    .eq('order_id', orderId)
    .eq('type', 'order_confirmation')
    .single()

  if (alreadySent) return  // Already sent, skip

  await sendEmail({ to: order.email, subject: 'Order confirmed' })
  await supabase.from('sent_emails').insert({ order_id: orderId, type: 'order_confirmation' })
}
```

## Webhook Processing Pattern

Webhooks from Stripe, GitHub, and other services can deliver the same event multiple times. Use a deduplication table:

```sql
CREATE TABLE processed_webhook_events (
  event_id    TEXT NOT NULL,
  source      TEXT NOT NULL,
  processed_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (event_id, source)
);
```

```ts
async function handleWebhook(event: WebhookEvent) {
  // Attempt to claim this event
  const { error } = await supabase
    .from('processed_webhook_events')
    .insert({ event_id: event.id, source: event.source })

  if (error?.code === '23505') {
    // Unique violation — already processed
    console.log(`Duplicate webhook: ${event.id}`)
    return { status: 200, duplicate: true }
  }

  // Process the event
  await processEvent(event)
  return { status: 200 }
}
```

The `INSERT` either succeeds (first time) or throws a unique constraint error (duplicate). This is atomic — no `SELECT` then `INSERT` race condition.

## Cron Job Idempotency

```ts
// NOT idempotent — processes a record multiple times if cron overlaps
async function processPendingOrders() {
  const { data: orders } = await supabase
    .from('orders')
    .select('*')
    .eq('status', 'pending')

  for (const order of orders) {
    await processOrder(order)
  }
}

// Idempotent — claim with atomic update
async function processPendingOrders() {
  // Claim a batch of orders, moving them to 'processing'
  const { data: orders } = await supabase
    .rpc('claim_pending_orders', { batch_size: 10 })

  for (const order of orders) {
    await processOrder(order)
    await supabase.from('orders').update({ status: 'completed' }).eq('id', order.id)
  }
}
```

```sql
CREATE OR REPLACE FUNCTION claim_pending_orders(batch_size INT)
RETURNS SETOF orders LANGUAGE sql AS $$
  UPDATE orders
  SET status = 'processing', claimed_at = now()
  WHERE id IN (
    SELECT id FROM orders
    WHERE status = 'pending'
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING *;
$$;
```

`FOR UPDATE SKIP LOCKED` lets multiple workers run concurrently without processing the same order twice. Each worker gets a different set of locked rows.

## Idempotency Keys for API Design

If you're building an API, expose an `Idempotency-Key` header:

```ts
export async function POST(req: Request) {
  const idempotencyKey = req.headers.get('Idempotency-Key')

  if (idempotencyKey) {
    // Check if we've seen this key
    const { data: existing } = await supabase
      .from('idempotency_keys')
      .select('response_body, response_status')
      .eq('key', idempotencyKey)
      .single()

    if (existing) {
      return new Response(existing.response_body, { status: existing.response_status })
    }
  }

  const result = await processRequest(req)
  const responseBody = JSON.stringify(result)

  if (idempotencyKey) {
    await supabase.from('idempotency_keys').insert({
      key: idempotencyKey,
      response_body: responseBody,
      response_status: 200,
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    })
  }

  return Response.json(result)
}
```

Store idempotency keys with a TTL (24h is standard). Clean up expired keys with a nightly batch job.

## Database Cleanup

```sql
-- Nightly cleanup of expired idempotency keys
DELETE FROM idempotency_keys WHERE expires_at < now();
DELETE FROM processed_webhook_events WHERE processed_at < now() - interval '7 days';
```
