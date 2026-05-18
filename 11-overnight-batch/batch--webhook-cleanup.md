# Batch: Webhook Delivery Log Cleanup

## What This Covers

Pruning old webhook delivery logs: defining a retention policy, batch-deleting in chunks to avoid table locks, archiving failed deliveries before deletion, and reporting freed space.

## Why Delivery Logs Accumulate Dangerously

Every webhook delivery attempt creates a row in the delivery log: timestamp, payload, response code, response body, attempt number, latency. At 100 webhooks/minute, that is 144,000 rows/day — over 50 million rows/year. Without pruning, query performance on the delivery log degrades, and the table consumes gigabytes of storage.

The nightly job enforces retention policy so the table stays bounded.

## Schema

```sql
CREATE TABLE webhook_deliveries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id      UUID NOT NULL REFERENCES webhooks(id),
  event_type      TEXT NOT NULL,
  payload         JSONB NOT NULL,
  attempt         INTEGER NOT NULL DEFAULT 1,
  status          TEXT NOT NULL,  -- 'success', 'failed', 'retrying'
  status_code     INTEGER,
  response_body   TEXT,
  duration_ms     INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  archived_at     TIMESTAMPTZ           -- set before deletion
);

CREATE INDEX ON webhook_deliveries (created_at);
CREATE INDEX ON webhook_deliveries (status, created_at);
```

## Retention Policy

Define explicitly and document it in your API docs so customers know how long delivery history is available:

| Status | Retention |
|--------|-----------|
| `success` | 30 days |
| `failed` | 90 days (longer for debugging) |
| `retrying` | Until resolved or 90 days |

Failed deliveries warrant longer retention because customers may not notice a failed webhook for days and need history to debug integrations.

## Archive Before Delete

Before hard-deleting failed deliveries, export them so they survive the retention window if needed for support or audits.

```ts
async function archiveFailedDeliveries(olderThan: Date) {
  // Select in batches to avoid memory pressure
  let offset = 0
  const BATCH = 500
  
  while (true) {
    const rows = await db.query(`
      SELECT * FROM webhook_deliveries
      WHERE status = 'failed'
        AND created_at < $1
        AND archived_at IS NULL
      ORDER BY created_at
      LIMIT $2 OFFSET $3
    `, [olderThan, BATCH, offset])
    
    if (rows.rows.length === 0) break
    
    // Write to S3 as newline-delimited JSON (cheap, queryable with Athena)
    const key = `webhook-archive/${olderThan.toISOString().split('T')[0]}/batch-${offset}.ndjson`
    const ndjson = rows.rows.map(r => JSON.stringify(r)).join('\n')
    
    await s3.send(new PutObjectCommand({
      Bucket: process.env.ARCHIVE_BUCKET!,
      Key: key,
      Body: ndjson,
      ContentType: 'application/x-ndjson',
    }))
    
    // Mark as archived
    const ids = rows.rows.map(r => r.id)
    await db.query(`
      UPDATE webhook_deliveries SET archived_at = now() WHERE id = ANY($1)
    `, [ids])
    
    offset += BATCH
    console.log(`Archived ${offset} failed deliveries`)
  }
}
```

## Batch Delete in Chunks

Never delete millions of rows in a single statement. A `DELETE FROM ... WHERE created_at < $1` on 5 million rows holds an exclusive lock on the table for the entire duration, blocking all webhook delivery writes.

Delete in chunks of 1,000–5,000 rows with a brief pause between batches:

```ts
async function deleteOldDeliveries(status: string, olderThan: Date) {
  const CHUNK_SIZE = 2000
  let totalDeleted = 0
  
  while (true) {
    const result = await db.query(`
      DELETE FROM webhook_deliveries
      WHERE id IN (
        SELECT id FROM webhook_deliveries
        WHERE status = $1
          AND created_at < $2
          AND (status != 'failed' OR archived_at IS NOT NULL)  -- only delete archived failures
        ORDER BY created_at
        LIMIT $3
      )
    `, [status, olderThan, CHUNK_SIZE])
    
    const deleted = result.rowCount ?? 0
    totalDeleted += deleted
    
    if (deleted < CHUNK_SIZE) break  // no more rows to delete
    
    // Brief pause: yield to other queries between chunks
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  
  return totalDeleted
}
```

The subquery `SELECT id ... LIMIT N` approach is important: it gives the planner a bounded scan, preventing sequential full-table scans on each delete batch.

## Main Cleanup Job

```ts
async function cleanupWebhookDeliveries() {
  const now = new Date()
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 3600_000)
  const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 3600_000)
  
  // Archive failed deliveries before deleting them
  console.log('Archiving failed deliveries...')
  await archiveFailedDeliveries(ninetyDaysAgo)
  
  // Delete successful deliveries older than 30 days
  const deletedSuccess = await deleteOldDeliveries('success', thirtyDaysAgo)
  
  // Delete failed deliveries older than 90 days (now archived)
  const deletedFailed = await deleteOldDeliveries('failed', ninetyDaysAgo)
  
  // Report table size before and after
  const sizeResult = await db.query(`
    SELECT pg_size_pretty(pg_total_relation_size('webhook_deliveries')) AS table_size
  `)
  
  console.log([
    `Cleanup complete:`,
    `  Deleted ${deletedSuccess} successful deliveries (>30 days)`,
    `  Deleted ${deletedFailed} failed deliveries (>90 days, archived)`,
    `  Current table size: ${sizeResult.rows[0].table_size}`,
  ].join('\n'))
  
  // Run VACUUM ANALYZE after large deletes to reclaim space and update planner stats
  // Note: run outside a transaction
  await db.query('VACUUM ANALYZE webhook_deliveries')
}
```

## Reporting Freed Space

Track table size over time to verify the cleanup is effective and to project future growth:

```ts
await db.query(`
  INSERT INTO maintenance_log (job, ran_at, details)
  VALUES ('webhook_delivery_cleanup', now(), $1)
`, [JSON.stringify({ deletedSuccess, deletedFailed, tableSize })])
```

Alert if the table size is still growing despite cleanup — it indicates webhook volume is increasing faster than the retention policy removes old rows, and the retention window may need adjustment.

## Key Rules

- Archive failed deliveries to S3 before deleting — failures are needed for customer debugging
- Delete in chunks of 1,000–5,000 rows with pauses between batches to avoid locking writes
- Never use a single `DELETE WHERE created_at < X` on large tables without a `LIMIT` in a subquery
- Keep failed delivery history 3x longer than successful delivery history (90 days vs 30 days)
- Run `VACUUM ANALYZE` after large deletes so Postgres reclaims space and updates statistics
- Log table size before and after cleanup to track whether the policy is keeping pace with growth
- Document the retention policy in your API docs so customers know how long logs are available
