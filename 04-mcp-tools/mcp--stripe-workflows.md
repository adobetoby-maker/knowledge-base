# Stripe MCP Workflows

## Authentication

Stripe MCP requires API key authentication. The key is typically set as an MCP server env var.

## Common Stripe Operations via API

For Stripe operations, use the Stripe CLI or REST API rather than the JS SDK when working from agent context:

```bash
# Stripe CLI (authenticated with stripe login)
stripe customers list --limit=5
stripe products list
stripe prices list
stripe invoices list --customer=cus_xxx
stripe events list --limit=10

# Create a customer
stripe customers create --email="customer@example.com" --name="John Doe"

# Create a price
stripe prices create \
  --currency=usd \
  --unit-amount=6900 \
  --recurring[interval]=month \
  --product-data[name]="Pro Plan"
```

## Webhook Events Reference

Key events to handle for subscription products:

| Event | Trigger | Action |
|-------|---------|--------|
| `checkout.session.completed` | Checkout completed | Provision access, create DB record |
| `customer.subscription.created` | Subscription starts | Set user as subscribed |
| `customer.subscription.updated` | Plan change, renewal | Update subscription in DB |
| `customer.subscription.deleted` | Cancellation | Revoke access |
| `invoice.payment_failed` | Payment fails | Send dunning email, update status |
| `invoice.payment_succeeded` | Renewal payment | Extend subscription period |
| `customer.updated` | Customer info changed | Sync customer data |

## Checking Customer Subscription Status

```bash
# Get customer subscriptions
stripe subscriptions list --customer=cus_xxx --status=active

# Get subscription details
stripe subscriptions retrieve sub_xxx
```

In code:
```typescript
// lib/stripe-helpers.ts
import { stripe } from './stripe'

export async function getActiveSubscription(customerId: string) {
  const subscriptions = await stripe.subscriptions.list({
    customer: customerId,
    status: 'active',
    limit: 1,
  })
  
  return subscriptions.data[0] ?? null
}

export async function cancelSubscription(subscriptionId: string) {
  return stripe.subscriptions.cancel(subscriptionId)
}

export async function createBillingPortalSession(customerId: string, returnUrl: string) {
  return stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  })
}
```

## Syncing Stripe to Supabase

The webhook handler should sync Stripe state to the DB. The DB is the source of truth for your app — not Stripe's API.

```typescript
// DB schema for subscriptions
// id, user_id, stripe_customer_id, stripe_subscription_id, status, price_id, current_period_end

// In webhook handler
async function syncSubscription(sub: Stripe.Subscription) {
  const supabase = createAdminClient()
  
  await supabase.from('subscriptions').upsert({
    stripe_subscription_id: sub.id,
    stripe_customer_id: sub.customer as string,
    status: sub.status,
    price_id: sub.items.data[0].price.id,
    current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
  }, { onConflict: 'stripe_subscription_id' })
}
```

## Test vs Live Mode

Stripe has separate test and live environments. Test mode uses `sk_test_` keys; live uses `sk_live_` keys.

Always develop against test mode. Switch to live for production.

Test card numbers:
- `4242 4242 4242 4242` — succeeds, any future expiry
- `4000 0000 0000 0002` — always declined
- `4000 0027 6000 3184` — requires authentication (3DS)

## Common Mistakes

- **Confusing test and live keys** — test webhooks require `sk_test_` keys; live webhooks require `sk_live_` keys
- **Not verifying webhook signature** — process raw body with `req.text()`, verify with `stripe.webhooks.constructEvent()`
- **Using Stripe API directly instead of syncing to DB** — for access checks, always query your DB, not Stripe's API in real-time
- **Missing idempotency** — Stripe retries webhooks; use the event ID to prevent double-processing
