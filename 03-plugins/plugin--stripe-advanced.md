# Stripe Advanced Patterns

## Subscription Billing

For recurring billing (SaaS plans), Stripe Subscriptions handle the complexity:

```typescript
// Create a Subscription for a customer:
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{ price: priceId }],  // price = product × billing interval
  payment_settings: {
    payment_method_types: ['card'],
    save_default_payment_method: 'on_subscription',
  },
  expand: ['latest_invoice.payment_intent'],
})

// The subscription creates invoices automatically
// Stripe handles retries for failed payments
// Webhook event: 'customer.subscription.updated', 'invoice.payment_failed'
```

## Stripe Prices vs Products

Products and prices are separate:
```typescript
// Product: "Pro Plan" — stable, what you're selling
// Price: "Pro Plan $49/month" — the billing terms

const price = await stripe.prices.create({
  product: productId,
  currency: 'usd',
  unit_amount: 4900,  // in cents — always
  recurring: {
    interval: 'month',
    interval_count: 1,
  },
})
```

Never hardcode price IDs in code — store them in environment variables:
```
STRIPE_PRICE_PRO_MONTHLY=price_xxx
STRIPE_PRICE_PRO_ANNUAL=price_yyy
```

## Webhook Handling (The Right Way)

Never trust the client's claim that payment succeeded. Always wait for the webhook:

```typescript
// app/api/webhooks/stripe/route.ts
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

export async function POST(req: Request) {
  const body = await req.text()  // raw bytes for HMAC — must be text(), not json()
  const signature = req.headers.get('stripe-signature')!
  
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
  } catch (error) {
    return new Response(`Webhook signature error: ${error}`, { status: 400 })
  }
  
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      await handleCheckoutComplete(session)
      break
    }
    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await handlePaymentFailed(invoice)
      break
    }
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await handleSubscriptionCanceled(sub)
      break
    }
  }
  
  return new Response('OK', { status: 200 })
}

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  const customerId = session.customer as string
  const subscriptionId = session.subscription as string
  
  // Update DB — this is the source of truth:
  await supabase
    .from('subscriptions')
    .upsert({
      stripe_customer_id: customerId,
      stripe_subscription_id: subscriptionId,
      status: 'active',
      updated_at: new Date().toISOString(),
    })
}
```

## Idempotency in Webhooks

Stripe can deliver the same webhook event multiple times. Make handlers idempotent:

```typescript
async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  // upsert is idempotent — running twice produces same result:
  await supabase
    .from('subscriptions')
    .upsert({ stripe_session_id: session.id, status: 'active' })
  
  // Or check if already processed:
  const { data: existing } = await supabase
    .from('webhook_events')
    .select('id')
    .eq('stripe_event_id', session.id)
    .single()
  
  if (existing) return  // already processed
  
  // Process + record:
  await processCheckout(session)
  await supabase.from('webhook_events').insert({ stripe_event_id: session.id })
}
```

## Customer Portal (Self-Serve Billing)

Stripe's hosted billing portal lets customers manage their own subscriptions:

```typescript
// Create a portal session and redirect:
export async function POST(req: Request) {
  const user = await getUser()
  if (!user) return new Response('Unauthorized', { status: 401 })
  
  const { data: sub } = await supabase
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', user.id)
    .single()
  
  const session = await stripe.billingPortal.sessions.create({
    customer: sub.stripe_customer_id,
    return_url: `${process.env.NEXT_PUBLIC_APP_URL}/settings/billing`,
  })
  
  return Response.redirect(session.url, 303)
}
```

The portal handles: plan upgrades/downgrades, cancellations, payment method updates, invoice history.

## Test vs Live Keys

```
sk_test_... / pk_test_... — test mode (no real charges)
sk_live_... / pk_live_... — production

STRIPE_SECRET_KEY=sk_test_... (dev/staging)
STRIPE_PUBLISHABLE_KEY=pk_test_...

STRIPE_SECRET_KEY=sk_live_... (production)
STRIPE_PUBLISHABLE_KEY=pk_live_...
```

Test card numbers: `4242 4242 4242 4242` (success), `4000 0000 0000 9995` (decline)
