# Failure: Stripe Webhook Issues

## Problem: Duplicate Event Processing

**Symptom**: Payment processed twice; customer charged once but your DB records show two payments.

**Root cause**: Stripe retries webhook events if it doesn't receive a 2xx response within 30 seconds. If your handler takes too long, or crashes after processing but before returning 200, Stripe retries and the handler runs twice.

**Fix**: Always check for duplicate events before processing:

```ts
export async function POST(request: NextRequest) {
  const body = await request.text()
  const sig = request.headers.get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  // Idempotency check — return 200 if already processed
  const { data: existing } = await supabaseAdmin
    .from('stripe_events')
    .select('id')
    .eq('stripe_event_id', event.id)
    .single()

  if (existing) {
    return NextResponse.json({ status: 'already_processed' })
  }

  // Process the event
  await handleStripeEvent(event)

  // Mark as processed
  await supabaseAdmin.from('stripe_events').insert({
    stripe_event_id: event.id,
    type: event.type,
    processed_at: new Date().toISOString(),
  })

  return NextResponse.json({ received: true })
}
```

## Problem: Webhook Signature Verification Failing

**Symptom**: `No signatures found matching the expected signature for payload`.

**Root cause 1**: Reading the body as JSON before signature verification. Stripe requires the raw body bytes.

```ts
// BAD: parses JSON, changes the raw bytes
const body = await request.json()  // ← breaks signature

// GOOD: read as raw text
const body = await request.text()
event = stripe.webhooks.constructEvent(body, sig, secret)
```

**Root cause 2**: Using the wrong webhook secret. Stripe gives a different secret per endpoint. The test mode webhook secret ≠ live mode secret. The CLI test secret (`whsec_test_*`) ≠ dashboard endpoint secret.

**Fix**: Set `STRIPE_WEBHOOK_SECRET` from the correct endpoint's signing secret. Use `stripe listen --forward-to localhost:3000/api/webhooks/stripe` for local development — it uses the CLI secret automatically.

**Root cause 3**: Middleware or body parser consuming the stream before the route handler.

**Fix**: In Next.js App Router, don't use any global middleware that reads request bodies. If you have middleware that does this, exempt `/api/webhooks/*` paths.

## Problem: Webhook Handler Times Out

**Symptom**: Stripe marks your webhook as failing; handler is doing too much synchronous work.

**Root cause**: Handlers should acknowledge receipt quickly and process asynchronously. Stripe's timeout is 30 seconds but you should target < 5 seconds.

**Fix**: Return 200 immediately, then process:

```ts
export async function POST(request: NextRequest) {
  const body = await request.text()
  // Verify signature and parse event
  const event = stripe.webhooks.constructEvent(body, sig, secret)

  // Acknowledge immediately
  const response = NextResponse.json({ received: true })

  // Process asynchronously — does NOT block the response
  // In Vercel: use waitUntil via unstable_noStore + async processing
  // In Edge Runtime: ctx.waitUntil is not available — offload to a queue

  processEventInBackground(event).catch(err => {
    console.error('Webhook processing failed:', err)
  })

  return response
}
```

## Problem: Test Events Not Reaching Local Handler

**Symptom**: `stripe trigger payment_intent.succeeded` runs but handler doesn't receive it.

**Root cause**: The Stripe CLI forwards events to `localhost` but your handler isn't running, or the path is wrong.

**Fix**:
```bash
# Start the CLI listener pointing to your local handler
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# In another terminal, trigger a test event
stripe trigger payment_intent.succeeded

# Verify the event appears in the listener output
# If it says "Received event but failed to forward" — check that your server is running
```

## Problem: Payment Intent Status Not Updated

**Symptom**: `payment_intent.succeeded` webhook fires, but your order stays in "pending" state.

**Root cause**: Webhook handler processes the wrong event type, or the metadata used to link the payment intent to the order is missing.

**Fix**: Always store order/invoice ID in `payment_intent.metadata` at creation time:

```ts
const paymentIntent = await stripe.paymentIntents.create({
  amount: totalCents,
  currency: 'usd',
  metadata: {
    invoice_id: invoice.id,  // Always link back to your data
    user_id: userId,
  },
})

// In webhook handler:
case 'payment_intent.succeeded':
  const invoiceId = event.data.object.metadata.invoice_id
  await markInvoicePaid(invoiceId)
  break
```

## Webhook Secret Storage

Never hardcode webhook secrets. Store in env vars:
```
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_SECRET_KEY=sk_live_...  // or sk_test_...
```

Test mode secrets start with `sk_test_` / `whsec_test_`. Live secrets start with `sk_live_`.
Never mix test and live keys in production.
