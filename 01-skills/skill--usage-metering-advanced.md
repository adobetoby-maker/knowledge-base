# Skill: Advanced Usage Metering for Billing

## Why Metering Is Harder Than It Looks

A simple counter per user seems sufficient until you need to handle: duplicate events (retry storms from failed webhooks), events that arrive out of order, billing periods that don't align with calendar months, and the difference between "usage this period" and "total usage ever." Building metering correctly means treating it as an event log with aggregation on top, not a mutable counter.

## Event Ingestion Pattern

Write every usage event to an append-only events table. Never update a counter in place.

```sql
CREATE TABLE usage_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  event_type TEXT NOT NULL,      -- 'api_call', 'file_upload', 'message_sent'
  quantity NUMERIC NOT NULL DEFAULT 1,
  idempotency_key TEXT UNIQUE,   -- prevents duplicate ingestion
  metadata JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON usage_events (tenant_id, event_type, occurred_at);
```

The `idempotency_key` prevents duplicate counting when events are retried. Generate it from the event's natural identity (e.g., `sha256(request_id + event_type)`).

## Period Aggregation

Aggregate on read, not on write. Pre-aggregated counters become wrong when events arrive late or are backfilled.

```sql
-- Current period usage for a tenant
SELECT 
  event_type,
  SUM(quantity) as total
FROM usage_events
WHERE tenant_id = $1
  AND occurred_at >= date_trunc('month', NOW())
  AND occurred_at < date_trunc('month', NOW()) + interval '1 month'
GROUP BY event_type;
```

For high-volume tenants (millions of events), materialize this into a `usage_snapshots` table on a schedule and query the snapshot + any events since the last snapshot. Don't do a full-table scan on every billing check.

## Overage Detection

Check against plan limits before or after an action, depending on the use case:

- **Before (hard limit):** Check current period total + pending quantity. If it exceeds the limit, reject the action and return a 429/402. Right for limits that must never be exceeded (free tier API calls, storage quotas).
- **After (soft limit / overage billing):** Allow the action, record the event, then check if the tenant is now over the limit and flag for billing. Right for paid overage tiers.

For real-time checks, cache the current period total in Redis with a short TTL:

```ts
const key = `usage:${tenantId}:${eventType}:${periodKey}`;
const current = await redis.incrby(key, quantity);
await redis.expireat(key, endOfPeriodTimestamp);

if (current > planLimit) {
  throw new OverageLimitError({ current, limit: planLimit });
}
```

The Redis counter is the fast path. Periodically reconcile against the source-of-truth events table to catch any drift.

## Stripe Usage Records API

For metered Stripe subscriptions (`billing_scheme: 'per_unit'` with `aggregate_usage`), report usage at billing period end or in aggregate via the Stripe Metered Billing API:

```ts
// Report usage for a subscription item
await stripe.subscriptionItems.createUsageRecord(
  subscriptionItemId,
  {
    quantity: totalUnitsForPeriod,
    timestamp: Math.floor(Date.now() / 1000),
    action: 'set', // 'set' replaces; 'increment' adds to existing
  }
);
```

Use `action: 'set'` with the total for the period rather than `action: 'increment'` per event — it's idempotent if your job runs multiple times. Run a daily aggregation job that reconciles `usage_events` totals and calls `createUsageRecord`.

## Grace Limits

Free tier users who hit their limit at 11:58 PM on the last day of the month should get a small buffer rather than a hard rejection. Implement grace limits as plan limits × 1.05 before triggering hard blocks — or allow a fixed number of overage units before the next billing cycle.

Document grace limits explicitly so they're not accidentally removed when plan limits are adjusted.

## Deduplication

Idempotency keys in the database are the primary deduplication mechanism. For high-throughput event streams where many events arrive per second from the same tenant, also use a Redis set to gate duplicate events in the hot path before the DB write:

```ts
const alreadySeen = await redis.setnx(`dedup:${idempotencyKey}`, '1');
await redis.expire(`dedup:${idempotencyKey}`, 86400); // 24h TTL
if (!alreadySeen) return; // duplicate, skip
```

## Key Rules

- Write usage events to an append-only log; never mutate counters in place
- Include an `idempotency_key` column with a UNIQUE constraint to prevent duplicate counting
- Aggregate by querying the events table per period; pre-aggregate only for high-volume tenants
- Use `action: 'set'` (total) not `action: 'increment'` when reporting to Stripe to ensure idempotency
- Implement soft grace limits (5-10% overage) before hard blocks to avoid frustrating edge cases
- Reconcile Redis fast-path counters against the events table daily
