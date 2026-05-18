# Bundle: Stripe Integration Complete

## Overview

Complete Stripe integration reference covering: one-time payments, subscriptions, webhooks, customer portal, and test mode. The most common source of bugs is webhook handling and subscription status synchronization.

## Setup

```bash
npm install stripe @stripe/stripe-js
```

```ts
// lib/stripe.ts — Server-side client
import Stripe from 'stripe'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-12-18.acacia',
})
```

```ts
// lib/stripe-client.ts — Client-side (for Elements)
import { loadStripe } from '@stripe/stripe-js'

export const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)
```

Never use the secret key on the client. Never use `NEXT_PUBLIC_STRIPE_SECRET_KEY`.

## One-Time Payment (Checkout Session)

```ts
// app/api/checkout/route.ts
import { stripe } from '@/lib/stripe'

export async function POST(req: Request) {
  const { priceId, userId, successUrl, cancelUrl } = await req.json()

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: cancelUrl,
    metadata: { userId },  // Attach user ID for webhook
    customer_email: user.email,  // Pre-fill email
  })

  return Response.json({ url: session.url })
}
```

## Subscription

```ts
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',  // Different from 'payment'
  line_items: [{ price: priceId, quantity: 1 }],
  success_url: `${process.env.APP_URL}/dashboard?upgraded=true`,
  cancel_url: `${process.env.APP_URL}/pricing`,
  metadata: { userId },
  allow_promotion_codes: true,
})
```

## Webhooks — The Critical Part

Webhooks must be verified with the Stripe signature. Without verification, anyone can POST to your webhook endpoint:

```ts
// app/api/webhooks/stripe/route.ts
import { stripe } from '@/lib/stripe'
import { headers } from 'next/headers'

export async function POST(req: Request) {
  const body = await req.text()  // Must be raw text, not parsed JSON
  const sig = (await headers()).get('stripe-signature')!
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(body, sig, webhookSecret)
  } catch (err) {
    return Response.json({ error: 'Invalid signature' }, { status: 400 })
  }

  // Handle events
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object
      await handleCheckoutComplete(session)
      break
    }
    case 'customer.subscription.updated': {
      const subscription = event.data.object
      await handleSubscriptionUpdated(subscription)
      break
    }
    case 'customer.subscription.deleted': {
      const subscription = event.data.object
      await handleSubscriptionCancelled(subscription)
      break
    }
    case 'invoice.payment_failed': {
      const invoice = event.data.object
      await handlePaymentFailed(invoice)
      break
    }
  }

  return Response.json({ received: true })
}
```

## Subscription Status Sync

The webhook handler must keep your DB in sync with Stripe:

```ts
async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  const userId = subscription.metadata.userId

  await db.update(users)
    .set({
      stripeSubscriptionId: subscription.id,
      plan: subscription.status === 'active' ? 'pro' : 'free',
      planStatus: subscription.status,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
    })
    .where(eq(users.stripeCustomerId, subscription.customer as string))
}
```

Always update based on Stripe data, not assumptions. `subscription.status` can be: `active`, `past_due`, `canceled`, `trialing`, `incomplete`, `incomplete_expired`, `unpaid`.

## Customer Portal (Self-Serve)

Stripe's hosted portal lets users manage billing without you building it:

```ts
export async function POST(req: Request) {
  const user = await requireAuth()

  const session = await stripe.billingPortal.sessions.create({
    customer: user.stripeCustomerId,
    return_url: `${process.env.APP_URL}/dashboard/billing`,
  })

  return Response.json({ url: session.url })
}
```

Users can: view invoices, update payment method, cancel subscription.

## Local Webhook Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local dev server
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# In another terminal, trigger test events
stripe trigger checkout.session.completed
stripe trigger customer.subscription.updated
```

The CLI prints the webhook secret to use in your `.env.local`.

## Idempotency

Webhooks can be delivered more than once. Always make handlers idempotent:

```ts
async function handleCheckoutComplete(session: Stripe.CheckoutSession) {
  // Check if already processed
  const existing = await db.query.orders.findFirst({
    where: eq(orders.stripeSessionId, session.id),
  })
  if (existing) return  // Already processed — skip

  // Create order
  await db.insert(orders).values({
    stripeSessionId: session.id,
    userId: session.metadata?.userId,
    amountCents: session.amount_total,
    status: 'paid',
  })
}
```

## Test Cards

| Card | Result |
|------|--------|
| 4242 4242 4242 4242 | Success |
| 4000 0000 0000 0002 | Declined |
| 4000 0025 0000 3155 | Requires 3DS |
| 4000 0000 0000 9995 | Insufficient funds |

Use any future expiry date, any CVC, any postal code for test cards.
