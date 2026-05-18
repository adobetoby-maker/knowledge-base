# Principle: Idempotency

## The Problem

Networks are unreliable. A client sends a request, the server processes it, but the response never arrives. The client retries. Without idempotency, the server processes the action twice — double-charging a customer, creating two records, sending two emails.

Idempotency means: calling the same operation multiple times produces the same result as calling it once.

## Read Operations Are Already Idempotent

`GET /invoices/123` returns the same invoice every time. No design effort needed.

The problem is write operations (POST, PUT, DELETE, actions that trigger side effects).

## Idempotency Key Pattern

The standard approach: the client generates a unique key per operation attempt. The server checks if it's seen this key. If yes, return the cached result. If no, execute and store.

```ts
// Client generates the key before sending
const idempotencyKey = crypto.randomUUID()

// Store locally so retries use the same key
localStorage.setItem(`pending-invoice-creation`, idempotencyKey)

await fetch('/api/invoices', {
  method: 'POST',
  headers: { 'Idempotency-Key': idempotencyKey },
  body: JSON.stringify(invoiceData),
})

// Clean up after success
localStorage.removeItem(`pending-invoice-creation`)
```

Server-side check:
```ts
export async function POST(request: NextRequest) {
  const idempotencyKey = request.headers.get('Idempotency-Key')

  if (idempotencyKey) {
    // Check if we've already processed this request
    const existing = await supabaseAdmin
      .from('idempotency_keys')
      .select('response')
      .eq('key', idempotencyKey)
      .single()

    if (existing.data) {
      return NextResponse.json(existing.data.response, { status: 200 })
    }
  }

  // Process the request
  const result = await createInvoice(...)

  // Store the result
  if (idempotencyKey) {
    await supabaseAdmin.from('idempotency_keys').insert({
      key: idempotencyKey,
      response: result,
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    })
  }

  return NextResponse.json(result, { status: 201 })
}
```

Idempotency key storage:
```sql
CREATE TABLE idempotency_keys (
  key text PRIMARY KEY,
  response jsonb NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);
-- Clean up expired keys with a cron
CREATE INDEX idempotency_keys_expires ON idempotency_keys(expires_at);
```

## PUT Is Idempotent, POST Usually Isn't

Design APIs to use PUT for operations that should be idempotent:

```
POST /invoices          → creates a new invoice (not idempotent)
PUT  /invoices/{id}     → replaces the invoice with this ID (idempotent)
PUT  /invoice-status/{id} → sets the status (idempotent)
```

For Supabase: use `upsert` for write operations that should be idempotent:
```ts
// NOT idempotent: insert creates a duplicate on retry
await supabase.from('settings').insert({ user_id, key, value })

// IDEMPOTENT: upsert replaces on conflict
await supabase.from('settings').upsert({ user_id, key, value }, { onConflict: 'user_id,key' })
```

## Webhook Processing

Webhook providers retry on failure (Stripe retries for 72 hours). Process webhooks idempotently:

```ts
// Check event ID before processing
const eventId = request.headers.get('Stripe-Signature') ?? body.id

const { data: existing } = await supabaseAdmin
  .from('processed_events')
  .select('id')
  .eq('event_id', eventId)
  .single()

if (existing) {
  return NextResponse.json({ status: 'already_processed' })
}

// Process...
await processStripeEvent(event)

// Mark as processed (use upsert to handle race conditions)
await supabaseAdmin.from('processed_events').upsert({ event_id: eventId })
```

## Email and SMS Idempotency

Emails and SMS can't be "un-sent." Use an event log to prevent duplicates:

```ts
async function sendInvoiceEmail(invoiceId: string) {
  // Check if email was already sent for this invoice
  const { data: existing } = await supabaseAdmin
    .from('email_log')
    .select('id')
    .eq('entity_id', invoiceId)
    .eq('event', 'invoice_sent')
    .single()

  if (existing) return  // Already sent, skip

  await sendEmail(...)

  await supabaseAdmin.from('email_log').insert({
    entity_id: invoiceId,
    event: 'invoice_sent',
    sent_at: new Date().toISOString(),
  })
}
```

## Financial Operations

Money movement must be idempotent. Stripe's payment intents are idempotent by design — the same `idempotency_key` returns the same result. Always pass a stable key:

```ts
const paymentIntent = await stripe.paymentIntents.create(
  { amount, currency: 'usd', ... },
  { idempotencyKey: `invoice-${invoiceId}-${customerId}` }
)
```

The key must uniquely identify the intended operation, not just be random.
