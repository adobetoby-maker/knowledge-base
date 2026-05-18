# Plugin: stripe@claude-plugins-official

**What it provides:** Stripe payment integration guidance, debugging, and API patterns.
**When to reach for it:** Adding payments to a project, debugging Stripe errors, setting up subscriptions or one-time payments.

## Key Skills
- `stripe:stripe-best-practices` — security, idempotency, webhook handling
- `stripe:stripe-projects` — full Stripe integration patterns
- `stripe:explain-error` — explain a Stripe error code
- `stripe:test-cards` — test card numbers for various scenarios
- `stripe:upgrade-stripe` — upgrade Stripe SDK to latest

## MCP Tools
```javascript
ToolSearch("stripe")  // list available tools
mcp__plugin_stripe_stripe__authenticate({})  // authenticate first
```

## Test Cards (Quick Reference)
```
4242 4242 4242 4242  — succeeds always
4000 0000 0000 9995  — always declines
4000 0027 6000 3184  — requires 3D Secure
4000 0000 0000 0002  — card declined
Use any future expiry, any CVC, any billing address
```

## Webhook Setup Pattern
```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'
import { NextRequest, NextResponse } from 'next/server'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  const body = await req.text()  // must be raw text for signature
  const sig = req.headers.get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch (err) {
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed':
      const session = event.data.object as Stripe.Checkout.Session
      // fulfill the order
      break
    case 'customer.subscription.deleted':
      // handle cancellation
      break
  }

  return NextResponse.json({ received: true })
}
```

## Checkout Session Pattern
```typescript
// Server action or API route
const session = await stripe.checkout.sessions.create({
  payment_method_types: ['card'],
  line_items: [{
    price_data: {
      currency: 'usd',
      product_data: { name: 'Product Name' },
      unit_amount: 2000,  // $20.00 in cents
    },
    quantity: 1,
  }],
  mode: 'payment',  // or 'subscription'
  success_url: `${process.env.NEXT_PUBLIC_BASE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${process.env.NEXT_PUBLIC_BASE_URL}/cancel`,
})
return NextResponse.redirect(session.url!)
```

## Env Vars
```
STRIPE_SECRET_KEY              # server-only, starts with sk_
NEXT_PUBLIC_STRIPE_PUBLIC_KEY  # browser-safe, starts with pk_
STRIPE_WEBHOOK_SECRET          # from Stripe dashboard webhook settings
```

## Common Errors
- `No signatures found` → webhook body was parsed before raw text extraction
- `Invalid signature` → webhook secret is wrong, or body was modified
- `No such customer` → using test key with live customer ID or vice versa
