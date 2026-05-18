# Skill: Stripe Usage-Based Billing

## Overview
Usage-based billing charges customers based on what they actually consume (API calls, seats, GB processed) rather than a flat subscription fee. The implementation challenge is accurate, idempotent reporting: Stripe's billing period runs in the cloud; your usage events are recorded locally; reconciling the two without double-counting or gaps is the core problem. The correct approach: record raw usage events to your database as they happen, then report them to Stripe on a schedule — not in real time.

## Implementation

### Two APIs: Legacy Usage Records vs Meter-Based (2024+)

**Legacy** (subscription item + `createUsageRecord`): attached to a subscription item with `usage_type: 'metered'`.

**Meter-based** (new): define a `Meter`, send events to it independently of subscriptions. More flexible.

Use the legacy API if you already have metered subscriptions. Use Meters for new implementations.

### Option A: Meter-Based Billing (Recommended for New Projects)
```ts
// 1. Create a Meter (once, in Stripe dashboard or via API)
const meter = await stripe.billing.meters.create({
  display_name: 'API Calls',
  event_name: 'api_call',
  default_aggregation: {
    formula: 'sum',
  },
  value_settings: {
    event_payload_key: 'value', // the field in the event payload to aggregate
  },
});

// 2. Report usage events (can be batched)
async function reportAPICallUsage(customerId: string, calls: number) {
  await stripe.billing.meterEvents.create({
    event_name: 'api_call',
    payload: {
      stripe_customer_id: customerId,
      value: String(calls),
    },
    timestamp: Math.floor(Date.now() / 1000),
    identifier: `${customerId}-${Date.now()}`, // idempotency key
  });
}
```

### Option B: Legacy Usage Records
```ts
// Subscription item must have usage_type: 'metered'
const subscription = await stripe.subscriptions.create({
  customer: customerId,
  items: [{
    price: METERED_PRICE_ID,  // price with usage_type: 'metered'
  }],
});

const subscriptionItemId = subscription.items.data[0].id;

// Report usage for billing period
// Use action: 'set' with a timestamp to set the value at a point in time
// (safer than 'increment' — idempotent when retried with same timestamp)
async function reportUsage(subscriptionItemId: string, quantity: number) {
  await stripe.subscriptionItems.createUsageRecord(subscriptionItemId, {
    quantity,
    timestamp: Math.floor(Date.now() / 1000),
    action: 'set',      // 'set' = absolute value at this timestamp; 'increment' = add
  });
}
```

### Collect Events Locally, Batch Report
```ts
// Record raw events as they happen (real-time, in your application)
export async function recordAPICall(userId: string, endpoint: string) {
  await db.usageEvents.create({
    userId,
    eventType: 'api_call',
    endpoint,
    timestamp: new Date(),
    reported: false,   // not yet sent to Stripe
  });
}

// Batch report at end of hour (cron job)
export async function reportHourlyUsage() {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

  const unreported = await db.usageEvents.groupBy({
    by: ['userId'],
    where: { reported: false, timestamp: { lt: oneHourAgo } },
    _count: true,
  });

  for (const group of unreported) {
    const user = await db.users.findById(group.userId);
    if (!user.stripeCustomerId || !user.subscriptionItemId) continue;

    try {
      await stripe.subscriptionItems.createUsageRecord(user.subscriptionItemId, {
        quantity: group._count,
        timestamp: Math.floor(Date.now() / 1000),
        action: 'increment',
      });

      await db.usageEvents.updateMany({
        where: { userId: group.userId, reported: false, timestamp: { lt: oneHourAgo } },
        data: { reported: true },
      });
    } catch (err) {
      console.error(`Failed to report usage for user ${group.userId}:`, err);
    }
  }
}
```

### Preventing Double-Counting
```ts
// If using 'set' action: include timestamp as idempotency signal
// If using 'increment': use Stripe's idempotency key header

const idempotencyKey = `usage-${userId}-${billingPeriodStart}`;

await stripe.subscriptionItems.createUsageRecord(
  subscriptionItemId,
  { quantity, action: 'set', timestamp },
  { idempotencyKey }
);
```

### Querying Current Period Usage
```ts
export async function getCurrentPeriodUsage(subscriptionItemId: string) {
  const records = await stripe.subscriptionItems.listUsageRecordSummaries(
    subscriptionItemId,
    { limit: 1 }
  );
  return records.data[0]?.total_usage ?? 0;
}
```

## Key Rules
- Record usage events to your own database first, then report to Stripe on a schedule — never send directly to Stripe in the hot path of an API request.
- `action: 'set'` is idempotent for the same timestamp; `action: 'increment'` is not — prefer `set` when retrying.
- Always store `subscriptionItemId` per user in your DB — it's needed for every usage report call and is different from the subscription ID.
- Batch reports should run at least hourly — Stripe generates invoices at billing period end; there must be no gap.
- If a usage report fails, retry it — usage that wasn't reported is lost revenue. Log failures as high-priority alerts.
- Meter-based billing (new API) decouples event reporting from subscriptions — preferred for new projects as it's more flexible.
- Always show users their current period usage in the UI — billing surprises cause cancellations.
