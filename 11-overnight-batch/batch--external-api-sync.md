# Batch: Third-Party API Data Sync

## Overview
External APIs (CRM, billing platform, analytics, ERP) are authoritative sources for data that your application needs locally for queries, reporting, and business logic. Syncing that data nightly ensures your local copy stays current without requiring real-time API calls in the hot path. The sync pipeline must detect changes (not just overwrite), handle rate limits, log diffs for auditing, and alert when the external API returns unexpected values.

## Implementation

### Sync Record Schema
```sql
CREATE TABLE external_sync_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source          TEXT NOT NULL,        -- 'stripe', 'hubspot', 'quickbooks'
  entity_type     TEXT NOT NULL,        -- 'customer', 'invoice', 'contact'
  external_id     TEXT NOT NULL,
  synced_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  status          TEXT NOT NULL,        -- 'success', 'error', 'no_change'
  changes_detected JSONB,              -- diff: { field: [old, new] }
  error           TEXT
);

-- Last sync timestamp per source/entity type
CREATE TABLE sync_cursors (
  source      TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  last_synced TIMESTAMPTZ NOT NULL,
  last_id     TEXT,                     -- for cursor-based pagination
  PRIMARY KEY (source, entity_type)
);
```

### Stripe Customer Sync
```ts
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function syncStripeCustomers() {
  const cursor = await getSyncCursor('stripe', 'customers');
  let startingAfter: string | undefined;
  let totalSynced = 0;
  let totalChanges = 0;

  do {
    // Rate limit awareness: Stripe allows 100 req/s for live mode
    const customers = await stripe.customers.list({
      limit: 100,
      starting_after: startingAfter,
      created: cursor.lastSynced
        ? { gte: Math.floor(cursor.lastSynced.getTime() / 1000) }
        : undefined,
    });

    for (const customer of customers.data) {
      const diff = await upsertCustomer(customer);
      if (Object.keys(diff).length > 0) {
        await logSyncChange('stripe', 'customers', customer.id, diff);
        totalChanges++;
      }
      totalSynced++;
    }

    startingAfter = customers.data[customers.data.length - 1]?.id;

    // Respect rate limits
    if (customers.has_more) {
      await delay(100); // 100ms between pages = 10 pages/second
    }

  } while (startingAfter);

  await updateSyncCursor('stripe', 'customers');
  return { totalSynced, totalChanges };
}

async function upsertCustomer(stripeCustomer: Stripe.Customer): Promise<Record<string, [unknown, unknown]>> {
  const existing = await db.customers.findOne({
    where: { stripeId: stripeCustomer.id }
  });

  const mapped = {
    stripeId: stripeCustomer.id,
    email: stripeCustomer.email ?? null,
    name: stripeCustomer.name ?? null,
    phone: stripeCustomer.phone ?? null,
    created: new Date(stripeCustomer.created * 1000),
    metadata: stripeCustomer.metadata,
    deleted: stripeCustomer.deleted ?? false,
  };

  if (!existing) {
    await db.customers.create(mapped);
    return { _created: [null, true] };
  }

  // Compute diff
  const diff: Record<string, [unknown, unknown]> = {};
  for (const [key, newValue] of Object.entries(mapped)) {
    if (JSON.stringify(existing[key]) !== JSON.stringify(newValue)) {
      diff[key] = [existing[key], newValue];
    }
  }

  if (Object.keys(diff).length > 0) {
    await db.customers.update(mapped, { where: { stripeId: stripeCustomer.id } });
  }

  return diff;
}
```

### Rate Limit Handling
```ts
async function withRateLimit<T>(
  fn: () => Promise<T>,
  retryAfterMs = 1000,
  maxRetries = 3
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      if (err?.statusCode === 429 || err?.code === 'rate_limited') {
        const waitMs = err.headers?.['retry-after']
          ? parseInt(err.headers['retry-after']) * 1000
          : retryAfterMs * Math.pow(2, attempt); // exponential backoff
        console.warn(`Rate limited. Waiting ${waitMs}ms before retry ${attempt + 1}`);
        await delay(waitMs);
      } else {
        throw err;
      }
    }
  }
  throw new Error(`Max retries exceeded`);
}
```

### Change Detection and Alerting
```ts
async function alertOnUnexpectedChanges(source: string, changes: SyncChange[]) {
  // Alert on fields that should rarely change
  const MONITORED_FIELDS = ['email', 'stripeId', 'accountStatus', 'planId'];

  const sensitiveChanges = changes.filter(c =>
    Object.keys(c.diff).some(field => MONITORED_FIELDS.includes(field))
  );

  if (sensitiveChanges.length > 10) {
    await sendSlackAlert({
      channel: '#data-sync-alerts',
      message: `SYNC ALERT: ${source} — ${sensitiveChanges.length} sensitive field changes detected`,
      details: sensitiveChanges.slice(0, 5).map(c =>
        `${c.externalId}: ${JSON.stringify(c.diff)}`
      ),
    });
  }
}
```

### Sync Orchestrator
```ts
export async function runExternalApiSync() {
  const syncTasks = [
    { name: 'stripe-customers', fn: syncStripeCustomers },
    { name: 'stripe-subscriptions', fn: syncStripeSubscriptions },
    { name: 'hubspot-contacts', fn: syncHubspotContacts },
  ];

  const results = [];
  for (const task of syncTasks) {
    const start = Date.now();
    try {
      const result = await task.fn();
      results.push({ ...result, task: task.name, status: 'success', durationMs: Date.now() - start });
    } catch (err) {
      results.push({ task: task.name, status: 'error', error: (err as Error).message, durationMs: Date.now() - start });
    }
  }

  return results;
}
```

## Key Rules
- Store a sync cursor per source/entity type — only fetch records changed since the last sync, not the full dataset.
- Compute a diff before updating — don't overwrite records where nothing changed; log diffs for auditing.
- Alert when more than N records show unexpected field changes — this can indicate bugs in the external system or a data corruption event.
- Respect API rate limits: check `Retry-After` header on 429 responses and use exponential backoff.
- Use upsert (`ON CONFLICT DO UPDATE`) not separate SELECT + INSERT/UPDATE — prevents race conditions.
- Never delete local records based on absence from external API — the record may have been created after the sync started, or the API may be returning partial data.
- Log the sync duration — if it suddenly takes 10x longer, the external API may have new data volumes or performance issues.
