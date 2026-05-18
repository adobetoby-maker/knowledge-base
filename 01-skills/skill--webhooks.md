# Webhook Handling

## What Webhooks Are

Webhooks are HTTP POST requests sent by external services to notify your app of events. The external service calls YOUR endpoint — you don't poll theirs. Your endpoint must respond with 2xx within ~5 seconds or the sender retries.

## Core Handler Pattern

```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(req: NextRequest) {
  const body = await req.text()  // MUST be raw text — not req.json()
  const signature = req.headers.get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    )
  } catch (err) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed':
      await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session)
      break
    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event.data.object as Stripe.Subscription)
      break
    default:
      // Unknown event — still return 200 so Stripe doesn't retry
  }

  return NextResponse.json({ received: true })
}
```

## Signature Verification

Every webhook provider has a signature mechanism. Always verify it. Never skip.

| Provider | Header | Secret env var |
|----------|--------|----------------|
| Stripe | `stripe-signature` | `STRIPE_WEBHOOK_SECRET` |
| GitHub | `x-hub-signature-256` | `GITHUB_WEBHOOK_SECRET` |
| Clerk | `svix-id`, `svix-timestamp`, `svix-signature` | `CLERK_WEBHOOK_SECRET` |
| Supabase | custom | varies |

```typescript
// GitHub signature verification
import { createHmac, timingSafeEqual } from 'crypto'

function verifyGitHubSignature(payload: string, signature: string, secret: string): boolean {
  const expectedSig = 'sha256=' + createHmac('sha256', secret).update(payload).digest('hex')
  const buf1 = Buffer.from(signature)
  const buf2 = Buffer.from(expectedSig)
  if (buf1.length !== buf2.length) return false
  return timingSafeEqual(buf1, buf2)  // constant-time comparison prevents timing attacks
}
```

## Idempotency

Webhook providers retry on failure or timeout. Your handler may receive the same event multiple times. Store processed event IDs.

```typescript
// Supabase — track processed webhook events
async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const supabase = createClient()
  
  // Check if already processed
  const { data: existing } = await supabase
    .from('processed_webhooks')
    .select('id')
    .eq('event_id', session.id)
    .single()
  
  if (existing) return  // already handled
  
  // Process the event
  await supabase.from('subscriptions').upsert({ ... })
  
  // Mark as processed
  await supabase.from('processed_webhooks').insert({ event_id: session.id })
}
```

## Fast Response Pattern

Stripe requires a response within 5 seconds. For slow operations, respond immediately and process async.

```typescript
export async function POST(req: NextRequest) {
  const body = await req.text()
  // ... verify signature ...
  
  // Respond immediately
  const response = NextResponse.json({ received: true })
  
  // Process in background (works in Node.js runtime, not Edge)
  // waitUntil equivalent: use a queue or background job
  setImmediate(async () => {
    await processWebhookEvent(event)
  })
  
  return response
}
```

For Cloudflare Workers, use `waitUntil`:
```typescript
export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext) {
    // ... verify signature ...
    ctx.waitUntil(processWebhookEvent(event, env))
    return new Response(JSON.stringify({ received: true }), { status: 200 })
  }
}
```

## Local Development

Use the Stripe CLI or ngrok to forward webhooks to localhost:
```bash
# Stripe CLI
stripe listen --forward-to localhost:3000/api/webhooks/stripe
# Outputs: whsec_test_... (use as STRIPE_WEBHOOK_SECRET in .env.local)

# ngrok
ngrok http 3000
# Configure the ngrok URL as webhook endpoint in provider dashboard
```

## Common Mistakes

- **Using `req.json()`** instead of `req.text()` — JSON parsing changes the body string, breaking signature verification
- **Not returning 200** for unknown event types — provider retries indefinitely
- **No idempotency** — duplicate processing on retries
- **Ignoring retries** — if you return 500, the provider retries. Logging 500 for expected events creates noise
- **Trusting event data** without re-fetching — Stripe event data can be stale; re-fetch the resource from the API for critical operations
