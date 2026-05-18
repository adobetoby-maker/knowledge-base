# Skill: stripe-integration

**Trigger:** Integrating Stripe payments — checkout sessions, subscriptions, webhooks, or customer portal.
**Returns:** Complete Stripe integration patterns for Next.js + Supabase apps.

## Stripe Client Setup

```typescript
// lib/stripe.ts
import Stripe from 'stripe'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-01-27',  // pin to specific API version
})
```

Never use `NEXT_PUBLIC_STRIPE_SECRET_KEY` — the secret key is server-only. `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` is the only Stripe key safe for the browser.

## Checkout Session — One-Time Payment

```typescript
// app/api/checkout/route.ts
import { stripe } from '@/lib/stripe'

export async function POST(request: Request) {
  const { priceId, userId } = await request.json()
  
  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${process.env.NEXT_PUBLIC_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${process.env.NEXT_PUBLIC_URL}/pricing`,
    metadata: { userId },  // pass through for webhook
    customer_email: userEmail,  // pre-fill email
  })
  
  return Response.json({ url: session.url })
}

// Client-side:
const { url } = await fetch('/api/checkout', { method: 'POST', body: JSON.stringify({ priceId, userId }) }).then(r => r.json())
window.location.href = url
```

## Subscription Pattern

```typescript
const session = await stripe.checkout.sessions.create({
  mode: 'subscription',
  payment_method_types: ['card'],
  line_items: [{ price: monthlyPriceId, quantity: 1 }],
  subscription_data: {
    trial_period_days: 14,  // optional trial
    metadata: { userId },
  },
  success_url: `${origin}/dashboard?success=true`,
  cancel_url: `${origin}/pricing`,
})
```

## Webhook Handler — Critical

Webhooks are the only reliable way to know payment succeeded. Do not trust the success_url callback alone — users can navigate away or their browser can close.

```typescript
// app/api/webhooks/stripe/route.ts
import { stripe } from '@/lib/stripe'

export async function POST(request: Request) {
  const body = await request.text()
  const sig = request.headers.get('stripe-signature')!
  
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  } catch (err) {
    return new Response('Invalid signature', { status: 400 })
  }
  
  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.CheckoutSession
      const userId = session.metadata?.userId
      
      if (session.mode === 'payment' && session.payment_status === 'paid') {
        await activateUserAccess(userId, session.id)
      }
      break
    }
    
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await syncSubscriptionStatus(sub)
      break
    }
    
    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await handlePaymentFailure(invoice.customer as string)
      break
    }
  }
  
  return new Response('OK', { status: 200 })
}

// Critical: must disable body parsing for webhook route
export const config = { api: { bodyParser: false } }
```

## Webhook Local Testing

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to localhost
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
```

## Customer Portal (Subscription Management)

```typescript
const portalSession = await stripe.billingPortal.sessions.create({
  customer: stripeCustomerId,
  return_url: `${process.env.NEXT_PUBLIC_URL}/dashboard`,
})

return Response.json({ url: portalSession.url })
```

Users manage subscriptions, update payment methods, and view billing history through the hosted portal — no custom UI needed.

## Syncing Stripe → Supabase

```typescript
// After successful payment, store in Supabase
async function activateUserAccess(userId: string, sessionId: string) {
  const supabase = createAdminClient()  // service role — needs to write to users table
  
  await supabase.from('subscriptions').upsert({
    user_id: userId,
    stripe_session_id: sessionId,
    status: 'active',
    activated_at: new Date().toISOString()
  }, { onConflict: 'user_id' })
}
```

## Environment Variables

```
STRIPE_SECRET_KEY         # sk_live_... or sk_test_...
STRIPE_PUBLISHABLE_KEY    # pk_live_... — safe for browser (NEXT_PUBLIC_)
STRIPE_WEBHOOK_SECRET     # whsec_... — from Stripe CLI or dashboard
NEXT_PUBLIC_URL           # https://yoursite.com — for success/cancel URLs
```

Never use production keys in development. Stripe provides test mode with `sk_test_` and `pk_test_` keys.
