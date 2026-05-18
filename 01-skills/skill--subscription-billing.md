# Skill: Subscription Billing (Stripe)

## What This Covers

Monthly/annual recurring subscriptions: create subscription, handle upgrades/downgrades, manage trials, pause/cancel, and access control by plan tier.

## Core Concepts

- **Product** — what you sell (e.g., "Pro Plan")
- **Price** — the billing terms for a product ($29/month, $290/year)
- **Subscription** — a customer's relationship with a price
- **Subscription Item** — a price + quantity within a subscription

## Setup: Products and Prices

Create in Stripe Dashboard, then reference by price ID:

```ts
// lib/stripe/prices.ts
export const PRICES = {
  starter_monthly: 'price_1234...',
  starter_annual: 'price_5678...',
  pro_monthly: 'price_9abc...',
  pro_annual: 'price_def0...',
} as const

export type PricingPlan = keyof typeof PRICES
```

## Create Checkout Session (Subscribe)

```ts
// app/api/billing/create-checkout/route.ts
import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!)

export async function POST(request: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { priceId } = await request.json()

  // Get or create Stripe customer
  const { data: profile } = await supabase
    .from('profiles')
    .select('stripe_customer_id')
    .eq('id', user.id)
    .single()

  let customerId = profile?.stripe_customer_id
  if (!customerId) {
    const customer = await stripe.customers.create({ email: user.email! })
    customerId = customer.id
    await supabase.from('profiles').update({ stripe_customer_id: customerId }).eq('id', user.id)
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_SITE_URL}/billing?success=true`,
    cancel_url: `${process.env.NEXT_PUBLIC_SITE_URL}/billing`,
    subscription_data: {
      trial_period_days: 14,  // Optional free trial
      metadata: { user_id: user.id },
    },
  })

  return NextResponse.json({ url: session.url })
}
```

## Webhook: Sync Subscription State

```ts
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers'

export async function POST(request: NextRequest) {
  const body = await request.text()
  const sig = (await headers()).get('stripe-signature')!

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch {
    return new NextResponse('Webhook signature failed', { status: 400 })
  }

  // Dedup: skip already-processed events
  const { data: processed } = await supabaseAdmin
    .from('processed_stripe_events')
    .select('id')
    .eq('event_id', event.id)
    .single()
  if (processed) return NextResponse.json({ ok: true })

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await syncSubscription(sub)
      break
    }
    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await handlePaymentFailed(invoice)
      break
    }
  }

  await supabaseAdmin.from('processed_stripe_events').insert({ event_id: event.id })
  return NextResponse.json({ ok: true })
}

async function syncSubscription(sub: Stripe.Subscription) {
  const customer = await stripe.customers.retrieve(sub.customer as string)
  const { data: profile } = await supabaseAdmin
    .from('profiles')
    .select('id')
    .eq('stripe_customer_id', sub.customer as string)
    .single()

  if (!profile) return

  const plan = getPlanFromPriceId(sub.items.data[0].price.id)

  await supabaseAdmin.from('subscriptions').upsert({
    user_id: profile.id,
    stripe_subscription_id: sub.id,
    stripe_customer_id: sub.customer as string,
    status: sub.status,  // 'active', 'trialing', 'past_due', 'canceled'
    plan,
    current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
    cancel_at_period_end: sub.cancel_at_period_end,
  })
}
```

## Access Control by Plan

```ts
// lib/billing.ts
export type Plan = 'free' | 'starter' | 'pro'

const PLAN_FEATURES: Record<Plan, { invoiceLimit: number; teamMembers: number }> = {
  free: { invoiceLimit: 5, teamMembers: 1 },
  starter: { invoiceLimit: 50, teamMembers: 3 },
  pro: { invoiceLimit: Infinity, teamMembers: Infinity },
}

export async function getUserPlan(userId: string): Promise<Plan> {
  const { data: sub } = await supabase
    .from('subscriptions')
    .select('plan, status')
    .eq('user_id', userId)
    .in('status', ['active', 'trialing'])
    .single()

  if (!sub) return 'free'
  return (sub.plan as Plan) ?? 'free'
}

export function canCreateInvoice(plan: Plan, currentCount: number): boolean {
  return currentCount < PLAN_FEATURES[plan].invoiceLimit
}
```

## Customer Portal (Manage Billing)

```ts
// Generate Stripe Customer Portal link
const portalSession = await stripe.billingPortal.sessions.create({
  customer: customerId,
  return_url: `${SITE_URL}/billing`,
})

return NextResponse.redirect(portalSession.url)
```

The Customer Portal handles: update payment method, view invoices, cancel subscription, change plan. Don't build these — use the portal.

## Upgrade / Downgrade

```ts
// Update the subscription's price (immediate proration)
const sub = await stripe.subscriptions.retrieve(subscriptionId)

await stripe.subscriptions.update(subscriptionId, {
  items: [{
    id: sub.items.data[0].id,
    price: newPriceId,
  }],
  proration_behavior: 'create_prorations',  // Charge/credit difference
})
```

The webhook `customer.subscription.updated` fires after this — sync your DB there.
