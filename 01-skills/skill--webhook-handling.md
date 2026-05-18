# Webhook Handling

## Route Handler Only (Not Server Actions)

Webhooks are HTTP POST requests from external services. They use raw JSON with custom headers — not the Next.js Server Action protocol. Always use Route Handlers:

```typescript
// app/api/webhooks/stripe/route.ts — CORRECT
export async function POST(req: Request) { ... }

// WRONG for webhooks:
'use server'
export async function handleStripeWebhook(formData: FormData) { ... }
// Stripe sends JSON, not FormData — this will fail
```

## HMAC Signature Verification

Every webhook must verify the signature before processing. Never process webhooks that don't pass verification:

```typescript
// Stripe:
const body = await req.text()  // raw bytes — must come before any json() call
const signature = req.headers.get('stripe-signature')!

let event: Stripe.Event
try {
  event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!)
} catch (error) {
  console.error('Webhook signature verification failed:', error)
  return new Response('Invalid signature', { status: 400 })
}
```

```typescript
// Generic HMAC verification (GitHub, Twilio, etc.):
import crypto from 'crypto'

function verifyWebhookSignature(
  payload: string,
  signature: string,
  secret: string
): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex')
  
  // Timing-safe comparison:
  return crypto.timingSafeEqual(
    Buffer.from(`sha256=${expectedSignature}`),
    Buffer.from(signature)
  )
}
```

`crypto.timingSafeEqual` prevents timing attacks. Don't use `===` for signature comparison.

## Return 200 Quickly

Webhook endpoints must return 200 quickly (within 5-30 seconds, varies by service). Long-running processing should be async:

```typescript
export async function POST(req: Request) {
  const body = await req.text()
  // ... verify signature ...
  
  // Queue the work — don't do it synchronously:
  await enqueueWebhookProcessing({ eventType: event.type, data: event.data })
  
  // Return 200 immediately:
  return new Response('OK', { status: 200 })
}
```

For Cloudflare Workers, use `ctx.waitUntil()`:
```typescript
ctx.waitUntil(processWebhook(event))
return new Response('OK', { status: 200 })
```

## Idempotency

Webhook services retry on failure or timeout. Your handler runs at least once but possibly multiple times:

```typescript
async function processStripeEvent(event: Stripe.Event) {
  // Check if already processed:
  const { data: existing } = await supabase
    .from('processed_webhook_events')
    .select('id')
    .eq('stripe_event_id', event.id)
    .single()
  
  if (existing) {
    console.log(`Event ${event.id} already processed — skipping`)
    return
  }
  
  // Process the event:
  await handleEvent(event)
  
  // Record as processed:
  await supabase.from('processed_webhook_events').insert({
    stripe_event_id: event.id,
    processed_at: new Date().toISOString(),
  })
}
```

## Event Type Handling

```typescript
switch (event.type) {
  case 'checkout.session.completed':
    await handleCheckoutComplete(event.data.object as Stripe.Checkout.Session)
    break
  
  case 'invoice.payment_failed':
    await handlePaymentFailed(event.data.object as Stripe.Invoice)
    break
  
  case 'customer.subscription.deleted':
    await handleSubscriptionCanceled(event.data.object as Stripe.Subscription)
    break
  
  default:
    // Log unhandled events but still return 200:
    console.log(`Unhandled webhook event type: ${event.type}`)
}

return new Response('OK', { status: 200 })
```

Always return 200 for unhandled event types — returning 4xx causes retries which fill logs.

## Local Development Testing

```bash
# Use Stripe CLI to forward webhooks to localhost:
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger a test event:
stripe trigger checkout.session.completed
```

For other services, use ngrok to expose localhost:
```bash
ngrok http 3000
# Use the HTTPS URL as the webhook endpoint in the service dashboard
```

## Webhook Endpoint Security

- Never expose webhook endpoints in the robots.txt `Allow` list
- Rate limit by IP at the edge (Cloudflare WAF) to prevent abuse
- Log all webhook calls with status (success, verification failed, error)
- Alert when error rate exceeds threshold
