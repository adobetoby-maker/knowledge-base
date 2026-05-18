# Reconciling Payment Processor Records vs Local DB

## Why Reconciliation Is Non-Optional

Your local DB and Stripe can diverge. Webhook delivery fails. A Stripe event fires during a DB outage. A developer scripts a fix directly in Stripe without updating your DB. A race condition in webhook processing creates a duplicate. Reconciliation is the process that catches these discrepancies before they become customer-facing bugs or revenue reporting errors.

Run reconciliation nightly on the previous day's data — it's fast (you're matching a bounded time window) and catches issues within 24 hours.

## Querying Stripe Charges for the Period

Fetch all charges created in the reconciliation window (previous calendar day in UTC):

```js
const startOfDay = Math.floor(startOfYesterday.getTime() / 1000);
const endOfDay = Math.floor(endOfYesterday.getTime() / 1000);

const stripeCharges = [];
for await (const charge of stripe.charges.list({
  created: { gte: startOfDay, lte: endOfDay },
  limit: 100,
})) {
  stripeCharges.push(charge);
}
```

Also fetch refunds for the period separately — refunds have their own Stripe events and are not embedded in charge objects in a way that's easy to query by date.

## Matching to Local Records

Match on `payment_intent_id` (for checkout flows) or `charge_id` (for direct charges). Never match on amount + timestamp — two different customers can pay the same amount in the same second.

```sql
SELECT o.id, o.payment_intent_id, o.amount_paid, o.status
FROM orders o
WHERE o.payment_intent_id = ANY($1::text[])
```

Build a lookup map from your local records:
```js
const localByPaymentIntent = new Map(
  localRecords.map(r => [r.payment_intent_id, r])
);
```

Iterate Stripe charges:
1. Found in local → compare `amount`, `status`, `currency`. Flag mismatches.
2. Not found in local → charge exists in Stripe but not in your DB (missed webhook).

Iterate local records:
1. Found in Stripe → already handled above.
2. Not found in Stripe → local record exists with no corresponding Stripe charge (phantom record, possible fraud vector).

## Flagging Unmatched Records

Write all discrepancies to a `reconciliation_issues` table, not just a log file. A table lets you query, filter, and assign them to team members:

```sql
CREATE TABLE reconciliation_issues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reconciliation_date DATE NOT NULL,
  issue_type TEXT NOT NULL,  -- 'stripe_only', 'local_only', 'amount_mismatch', 'status_mismatch'
  stripe_charge_id TEXT,
  local_order_id UUID,
  stripe_amount INT,
  local_amount INT,
  details JSONB,
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

`stripe_only` issues need an update to your local DB. `local_only` issues need investigation — did the payment actually process? `amount_mismatch` may indicate a partial refund not applied locally. `status_mismatch` may indicate a failed webhook.

## Discrepancy Report

Generate a daily summary report:
- Total charges in Stripe for the period
- Total charges in local DB for the period
- Match rate (%)
- Count per issue type
- Total unresolved issues older than 48 hours

Send to an ops Slack channel or email. A match rate below 99% warrants immediate investigation. 99.5%+ is healthy; occasional webhook delivery failures are expected.

## Auto-Resolution for Known Patterns

Some discrepancies are safe to auto-resolve:
- `stripe_only` where the charge is successful and the `payment_intent_id` matches a local order in `payment_pending` status → update local status to `paid` and mark resolved.

Never auto-resolve `local_only` discrepancies — they require human review.

## Key Rules

- Always match on `payment_intent_id` or `charge_id`; never on amount+timestamp.
- Write discrepancies to a DB table, not just logs — tables are queryable and auditable.
- Reconcile nightly on the prior day's window; don't accumulate a backlog.
- Distinguish four issue types: stripe_only, local_only, amount_mismatch, status_mismatch — each has a different resolution path.
- Auto-resolve only patterns that are safe and well-understood; escalate all other types to human review.
- Alert immediately if match rate drops below 99%; don't wait for daily review.
