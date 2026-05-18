# Batch: Subscription Renewal Processing

## Overview

Subscription renewals run on a cron: charge the customer, update the subscription period, handle failures with retry logic, and send appropriate emails. The key challenge: failed payments need a dunning flow (retry schedule with escalating communication) rather than immediate cancellation.

## Schema

```sql
CREATE TABLE subscriptions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id),
  plan_id       text NOT NULL,
  status        text NOT NULL DEFAULT 'active',  -- active, past_due, canceled
  current_period_start timestamptz NOT NULL,
  current_period_end   timestamptz NOT NULL,
  stripe_subscription_id text,
  stripe_customer_id   text NOT NULL,
  payment_failure_count int NOT NULL DEFAULT 0,
  next_retry_at timestamptz
);
```

## The Renewal Job

```ts
// src/jobs/subscription-renewal.ts
export async function processSubscriptionRenewals() {
  // Find subscriptions due for renewal in the next hour
  const due = await db.select()
    .from(subscriptions)
    .where(
      and(
        eq(subscriptions.status, 'active'),
        lte(subscriptions.currentPeriodEnd, new Date(Date.now() + 60 * 60 * 1000)),
        gte(subscriptions.currentPeriodEnd, new Date()),
      )
    )

  const results = await Promise.allSettled(
    due.map(sub => renewSubscription(sub))
  )

  const failed = results.filter(r => r.status === 'rejected')
  if (failed.length > 0) {
    logger.error({ count: failed.length }, 'subscription renewals failed')
  }

  return { processed: due.length, failed: failed.length }
}
```

## Stripe-Managed Renewals

If using Stripe Subscriptions, Stripe handles renewals automatically. The job instead processes the webhook:

```ts
// Webhook handler for invoice events
export async function handleStripeWebhook(event: Stripe.Event) {
  switch (event.type) {
    case 'invoice.paid': {
      const invoice = event.data.object as Stripe.Invoice
      await db.update(subscriptions)
        .set({
          status: 'active',
          currentPeriodStart: new Date(invoice.period_start * 1000),
          currentPeriodEnd: new Date(invoice.period_end * 1000),
          paymentFailureCount: 0,
        })
        .where(eq(subscriptions.stripeSubscriptionId, invoice.subscription as string))
      break
    }

    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      await handlePaymentFailure(invoice.subscription as string, invoice.attempt_count ?? 1)
      break
    }

    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await db.update(subscriptions)
        .set({ status: 'canceled' })
        .where(eq(subscriptions.stripeSubscriptionId, sub.id))
      await sendSubscriptionCanceledEmail(sub.customer as string)
      break
    }
  }
}
```

## Dunning Flow (Payment Failure Handling)

```ts
const DUNNING_SCHEDULE = [
  { attemptNumber: 1, delayDays: 0,  email: 'payment-failed-soft' },   // Same day — gentle
  { attemptNumber: 2, delayDays: 3,  email: 'payment-failed-retry' },  // Day 3 — retry notice
  { attemptNumber: 3, delayDays: 7,  email: 'payment-failed-urgent' }, // Day 7 — urgent
  { attemptNumber: 4, delayDays: 14, email: 'subscription-canceled' }, // Day 14 — cancel
]

async function handlePaymentFailure(stripeSubId: string, attemptCount: number) {
  const sub = await db.query.subscriptions.findFirst({
    where: eq(subscriptions.stripeSubscriptionId, stripeSubId),
  })
  if (!sub) return

  const step = DUNNING_SCHEDULE[Math.min(attemptCount - 1, DUNNING_SCHEDULE.length - 1)]

  if (attemptCount >= DUNNING_SCHEDULE.length) {
    // Final attempt failed — cancel
    await db.update(subscriptions)
      .set({ status: 'canceled' })
      .where(eq(subscriptions.id, sub.id))
    await sendEmail(sub.userId, step.email)
    return
  }

  // Mark past_due, schedule next retry
  await db.update(subscriptions)
    .set({
      status: 'past_due',
      paymentFailureCount: attemptCount,
      nextRetryAt: new Date(Date.now() + step.delayDays * 24 * 60 * 60 * 1000),
    })
    .where(eq(subscriptions.id, sub.id))

  await sendEmail(sub.userId, step.email)
}
```

## Grace Period (Access During Dunning)

```ts
// Allow access during dunning period — only revoke on final cancel
async function hasActiveSubscription(userId: string): Promise<boolean> {
  const sub = await db.query.subscriptions.findFirst({
    where: eq(subscriptions.userId, userId),
  })
  // Allow access if active OR past_due (dunning — not yet canceled)
  return sub?.status === 'active' || sub?.status === 'past_due'
}
```

## Key Rules

- Let Stripe handle the renewal charge — don't attempt to charge in your own cron; webhook events are the source of truth.
- Dunning (payment failure + retry schedule) is standard practice — immediately canceling on first failure loses recoverable customers.
- Send dunning emails immediately on failure, not on the next retry attempt — the first email is a chance to update the card before retry.
- Grace period during dunning is expected by users — revoke access only after final cancellation, not on first failure.
- Idempotent webhook handling is critical — Stripe may fire `invoice.payment_failed` multiple times for the same invoice.
