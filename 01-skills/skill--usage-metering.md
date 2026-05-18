# Skill: Usage Metering

## Overview

Track and bill for usage-based features: API calls, AI tokens, storage GB, seats, messages sent. Two patterns: prepaid credits (buy a bucket, drain it) and post-pay metering (track usage, charge at billing cycle). Stripe Billing Meters handles both.

## Event-Based Metering (Stripe Billing Meters)

```ts
// Record a usage event
async function recordUsageEvent(customerId: string, meterId: string, value: number) {
  await stripe.billing.meterEvents.create({
    event_name: 'api_calls',  // Must match the meter's event name
    payload: {
      stripe_customer_id: customerId,
      value: value.toString(),
    },
  })
}

// Create the meter in Stripe (once, in setup)
const meter = await stripe.billing.meters.create({
  display_name: 'API Calls',
  event_name: 'api_calls',
  default_aggregation: { formula: 'sum' },
  customer_mapping: { event_payload_key: 'stripe_customer_id', type: 'by_id' },
  value_settings: { event_payload_key: 'value' },
})
```

## In-App Credit System

For prepaid credits (buy 1000 AI tokens, use them down):

```sql
CREATE TABLE credit_transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID NOT NULL REFERENCES organizations(id),
  amount      INTEGER NOT NULL,   -- Positive = purchase, negative = usage
  type        TEXT NOT NULL,      -- 'purchase', 'usage', 'refund', 'bonus'
  reference   TEXT,               -- Usage event ID, payment ID, etc.
  description TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT now()
);
```

```ts
async function getCreditBalance(orgId: string): Promise<number> {
  const result = await db.execute(sql`
    SELECT COALESCE(SUM(amount), 0) as balance
    FROM credit_transactions
    WHERE org_id = ${orgId}
  `)
  return Math.max(0, Number(result[0].balance))
}

async function consumeCredits(
  orgId: string,
  amount: number,
  reference: string,
  description: string,
): Promise<boolean> {
  const balance = await getCreditBalance(orgId)
  if (balance < amount) return false

  await db.insert(creditTransactions).values({
    orgId,
    amount: -amount,
    type: 'usage',
    reference,
    description,
  })
  return true
}
```

## Request-Level Usage Tracking

Track usage on every API request:

```ts
// middleware
async function trackUsage(req: Request, orgId: string, feature: string): Promise<boolean> {
  const limits = await getFeatureLimits(orgId, feature)
  const used = await getMonthlyUsage(orgId, feature)

  if (used >= limits.max) {
    return false  // Limit reached
  }

  // Fire-and-forget — don't block request
  db.insert(usageEvents).values({
    orgId,
    feature,
    count: 1,
    recordedAt: new Date(),
  }).catch(err => logger.error('Usage tracking failed', err))

  return true
}
```

## Monthly Usage Summary

```ts
async function getMonthlyUsage(orgId: string, feature: string): Promise<number> {
  const startOfMonth = new Date()
  startOfMonth.setDate(1)
  startOfMonth.setHours(0, 0, 0, 0)

  const result = await db.execute(sql`
    SELECT COALESCE(SUM(count), 0) as total
    FROM usage_events
    WHERE org_id = ${orgId}
      AND feature = ${feature}
      AND recorded_at >= ${startOfMonth}
  `)
  return Number(result[0].total)
}
```

## Usage Dashboard

Show current period usage vs limits:

```tsx
function UsageMeter({ feature, used, limit }: { feature: string; used: number; limit: number }) {
  const pct = Math.min(100, (used / limit) * 100)
  const color = pct >= 90 ? 'bg-red-500' : pct >= 75 ? 'bg-amber-500' : 'bg-blue-500'

  return (
    <div className="space-y-1">
      <div className="flex justify-between text-sm">
        <span>{feature}</span>
        <span>{used.toLocaleString()} / {limit.toLocaleString()}</span>
      </div>
      <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
        <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  )
}
```

## Key Rules

- Track usage asynchronously — don't block the API response waiting for a usage insert.
- Enforce limits synchronously at the start of the request, before doing expensive work.
- Reset monthly usage based on the billing cycle date, not the calendar month (if a customer signed up on the 15th, their month resets on the 15th).
- Warn at 80% and 95% usage via email/in-app notification — don't let users hit limits without warning.
