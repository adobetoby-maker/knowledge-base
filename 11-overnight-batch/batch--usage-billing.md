# Usage-Based Billing Batch Job

Usage-based billing aggregates metered events per billing period and reports them to a payment processor. The critical properties are correctness (no missed events, no double-counts), idempotency (safe to re-run after failures), and timezone accuracy (period boundaries must match what the customer agreed to).

## Aggregating Metered Usage Per Period

Metered events (API calls, messages sent, rows processed) must be summed per customer per billing period. The billing period is defined in the subscription record; don't hardcode monthly periods — enterprise customers may have custom periods.

```sql
SELECT
  customer_id,
  billing_period_start,
  billing_period_end,
  SUM(quantity) AS total_usage,
  metric_name
FROM usage_events
WHERE occurred_at >= billing_period_start
  AND occurred_at < billing_period_end
  AND billed = FALSE
GROUP BY customer_id, billing_period_start, billing_period_end, metric_name;
```

Use `occurred_at < period_end` (exclusive upper bound) to avoid counting the same event in two periods.

## Timezone-Aware Period Boundaries

Billing periods are agreements made in the customer's timezone. A period that ends "midnight on the 1st" means midnight in the customer's configured timezone, not UTC. Convert to UTC for database queries:

```typescript
const periodEndUTC = toUTC(subscription.periodEnd, customer.billingTimezone);
```

Use a library that handles DST transitions correctly (Luxon, date-fns-tz). Never use raw UTC offset arithmetic for DST-sensitive timezones.

Mishandling timezone boundaries is an undercharge or overcharge — both create customer support debt.

## Idempotent Aggregation

The job must be safe to re-run. If it crashes mid-run and is re-executed, it should produce the same billing totals, not doubled ones. Implement idempotency via:

1. **Aggregation table**: write aggregated totals to a `usage_aggregates` table with a unique constraint on `(customer_id, billing_period_start, metric_name)`. An upsert on re-run updates rather than inserts.
2. **Mark-then-report**: mark usage events as `billed = TRUE` only after the aggregation row is successfully written and the report is accepted by Stripe. If Stripe rejects, the events remain unbilled.
3. **Idempotency key on Stripe calls**: pass a deterministic idempotency key to Stripe's API: `${customerId}-${periodStart}-${metricName}`. If the same call is retried, Stripe returns the original response.

## Syncing to Stripe Usage Records

For Stripe Billing with metered subscriptions:
1. Look up the subscription item ID for the relevant price/metric.
2. Call `stripe.subscriptionItems.createUsageRecord(itemId, { quantity, timestamp, action: 'set' })` with `action: 'set'` to overwrite the total rather than `'increment'` to avoid double-counting on retries.
3. Confirm Stripe returns a usage record ID; store it on the aggregation row for audit purposes.

Use `action: 'set'` with the period's total, not `action: 'increment'` with per-event amounts, unless your architecture guarantees exactly-once delivery.

## Key Rules

- Use exclusive upper bound (`occurred_at < period_end`) to prevent cross-period double-counting.
- Convert all period boundaries to the customer's billing timezone before querying; use a DST-safe library.
- Idempotency key is mandatory on all Stripe usage record calls.
- Use `action: 'set'` (set period total) over `action: 'increment'` (per-event) on retryable jobs.
- Mark events as billed only after the Stripe call succeeds; never pre-mark.
- Store Stripe usage record IDs on the aggregation row for auditability.
