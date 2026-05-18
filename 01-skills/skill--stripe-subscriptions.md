# Skill: Stripe Subscription Lifecycle

## What This Covers

The full lifecycle of a Stripe subscription beyond initial creation: choosing the right entry point (Checkout vs Payment Link vs direct API), responding to `customer.subscription.updated`, handling mid-cycle plan changes with proration, and the distinction between soft cancel and immediate cancel, including reactivation.

## Entry Point Selection

**Checkout Session** — use when you control the purchase flow in your app, need to capture metadata (user ID, plan), or want trial periods. Most flexible.

**Payment Link** — use for simple one-off signup pages that don't need dynamic metadata. No server code to create the session, but you lose the ability to pre-attach the Stripe customer ID. You must reconcile back to your user via the webhook's `client_reference_id` or customer email.

**Direct API** (`stripe.subscriptions.create`) — use when the customer already has a saved payment method (e.g., upgrading from an existing sub). Skips the hosted page entirely. Requires `default_payment_method` set on the customer.

Decision rule: if the user is already authenticated and has a payment method on file, use the direct API or the Customer Portal. For new users, use Checkout Session — it handles SCA/3DS automatically.

## The Central Webhook: `customer.subscription.updated`

This fires for every state change: plan change, trial end, payment failure, cancellation scheduling, reactivation. It is the single source of truth for subscription state in your database.

Fields to always sync:
- `status` — `active`, `trialing`, `past_due`, `canceled`, `unpaid`, `paused`
- `current_period_end` — when the current billing cycle ends (as Unix timestamp)
- `cancel_at_period_end` — boolean, true means "will cancel at end of period"
- `canceled_at` — when the subscription was hard-canceled (null if still active)
- `items.data[0].price.id` — the current plan

Never derive plan tier from a Checkout Session's success URL. Always read it from the webhook payload.

## Proration on Mid-Cycle Upgrade

When a user upgrades mid-cycle, Stripe creates a proration credit for unused time on the old plan and charges for the remaining time on the new plan — all on the next invoice unless `payment_behavior: 'allow_incomplete'` is set.

```ts
await stripe.subscriptions.update(subscriptionId, {
  items: [{ id: existingItemId, price: newPriceId }],
  proration_behavior: 'create_prorations',  // default — bill the difference
})
// 'none' skips proration: customer gets the new plan without a mid-cycle charge.
// Use 'none' only for same-price plan switches (e.g., monthly ↔ annual same tier).
```

Downgrade proration: Stripe issues a credit, not a refund. The credit applies to the next invoice. If the customer cancels before the next invoice, the credit is lost unless you issue a refund manually.

## `cancel_at_period_end` vs Immediate Cancel

**Soft cancel** (`cancel_at_period_end: true`): subscription status stays `active` until `current_period_end`, then Stripe fires `customer.subscription.deleted`. The user keeps access through the end of the paid period. This is what the Stripe Customer Portal does by default.

```ts
await stripe.subscriptions.update(subscriptionId, {
  cancel_at_period_end: true,
})
```

**Immediate cancel** (`stripe.subscriptions.cancel`): status becomes `canceled` immediately. No refund is issued automatically — you decide whether to prorate and refund via `prorate: true` parameter.

```ts
await stripe.subscriptions.cancel(subscriptionId, {
  prorate: true,  // Stripe calculates unused days and issues a credit/refund
})
```

Use soft cancel as the default user-facing behavior. Use immediate cancel for fraud/abuse or admin-initiated termination.

## Reactivation

If `cancel_at_period_end` is true but the period hasn't ended yet, reactivation is simple — just un-schedule the cancellation:

```ts
await stripe.subscriptions.update(subscriptionId, {
  cancel_at_period_end: false,
})
```

If the subscription is already `canceled`, you cannot reactivate it — create a new subscription. Look up the customer's previous plan from your DB, create a new Checkout Session or use the direct API to re-subscribe. Stripe treats this as a brand-new subscription with a new ID; your DB must handle the new `stripe_subscription_id`.

## Handling `past_due`

`past_due` means payment failed but Stripe's retry schedule is still running (configurable in Dashboard, default: 4 attempts over ~2 weeks). During this window, do not immediately revoke access — it creates churn for users whose card temporarily failed. Instead:

1. Downgrade to a read-only mode or show a payment banner
2. Listen for `invoice.payment_failed` to trigger a "please update your card" email
3. Listen for `invoice.payment_succeeded` (after retry) to restore full access
4. On `customer.subscription.deleted` after exhausted retries — revoke access

## Key Rules

- Always sync subscription state from webhooks, never from Checkout redirect
- Use `cancel_at_period_end: true` (soft cancel) for user-initiated cancellation by default
- Never assume a `canceled` subscription can be reactivated — create a new one
- `past_due` does not mean canceled; preserve access during Stripe's retry window
- Proration creates credits, not refunds — inform users on downgrades
- Store `cancel_at_period_end` in your DB and expose it in the UI ("Cancels on Jan 1")
- Idempotency: record processed event IDs to handle Stripe's at-least-once delivery
