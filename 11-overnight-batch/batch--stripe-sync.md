# Nightly Sync of Stripe Data to Local DB

## Why Sync Instead of Always Querying Stripe

Stripe's API has rate limits (100 read requests/second) and adds ~200–500ms per query. For any reporting, filtering, or joining Stripe data with your own DB (user table, order table), a local copy is essential. Syncing nightly covers the vast majority of use cases — only real-time payment confirmations warrant live API calls.

## Incremental Fetch Strategy

Never re-fetch all Stripe data nightly. For large accounts, a full resync takes hours and burns API quota.

Track a `last_synced_at` timestamp per entity type in a `stripe_sync_state` table:
```sql
CREATE TABLE stripe_sync_state (
  entity_type TEXT PRIMARY KEY,  -- 'customer', 'subscription', 'invoice', 'charge'
  last_synced_at TIMESTAMPTZ,
  last_run_status TEXT,
  records_synced INT
);
```

At sync time, fetch only records created or modified after `last_synced_at` using Stripe's `created` or `updated` filter:
```js
const charges = await stripe.charges.list({
  created: { gte: Math.floor(lastSyncedAt.getTime() / 1000) },
  limit: 100,
});
```

Use auto-pagination to handle result sets larger than 100 records:
```js
for await (const charge of stripe.charges.list({ created: { gte: since } })) {
  await upsertCharge(charge);
}
```

## Idempotent Upsert Pattern

The same Stripe object may be fetched multiple times (overlapping sync windows, retries). Use upsert with `ON CONFLICT DO UPDATE`:

```sql
INSERT INTO stripe_charges (stripe_id, customer_id, amount, status, created_at, raw_data)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (stripe_id) DO UPDATE SET
  status = EXCLUDED.status,
  amount = EXCLUDED.amount,
  raw_data = EXCLUDED.raw_data,
  synced_at = NOW();
```

Store the full raw JSON in a `raw_data` JSONB column alongside your structured columns. This lets you backfill structured columns later without re-fetching from Stripe.

## Handling Deleted Records

Stripe doesn't physically delete most objects — they're marked with `deleted: true`. But subscriptions can be cancelled and customers can be deleted via the API or dashboard.

Subscribe to the `customer.deleted` and `subscription.deleted` Stripe webhooks (real-time), and also handle them in the nightly sync. In the sync, mark records as `deleted = true` rather than `DELETE FROM` — hard deletes destroy audit history and break foreign key integrity.

For the nightly sync, check for records in your local DB that haven't appeared in Stripe's list for >7 days and flag them for manual review rather than auto-deleting.

## Sync Status Tracking

Record sync metadata per entity type per run:
```js
await db.query(`
  UPDATE stripe_sync_state SET
    last_synced_at = $1,
    last_run_status = $2,
    records_synced = $3
  WHERE entity_type = $4
`, [new Date(), 'success', recordCount, 'charge']);
```

On failure, set `last_run_status = 'failed'` and retain the previous `last_synced_at` — this ensures the next run re-fetches the failed window rather than skipping it.

Alert if any entity type hasn't synced successfully in >24 hours.

## Sync Order

Sync in dependency order to preserve foreign key integrity:
1. Customers
2. Payment methods
3. Subscriptions
4. Invoices
5. Charges / payment intents

Syncing invoices before customers will cause FK violations unless you defer constraints or use nullable foreign keys.

## Key Rules

- Always track `last_synced_at` per entity type; never re-fetch the full history nightly.
- Use upsert with `ON CONFLICT DO UPDATE` — never INSERT-or-ignore, which silently skips updates to existing records.
- Store raw JSON alongside structured columns for backfill flexibility.
- Mark deleted records with a `deleted` flag; never hard-delete synced Stripe data.
- On sync failure, leave `last_synced_at` unchanged so the next run covers the gap.
- Sync in FK dependency order: customers before subscriptions before invoices.
