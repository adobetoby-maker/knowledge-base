# Batch: Stale Data Cleanup

## Overview
Production databases accumulate stale data that wastes storage, degrades query performance, and
creates compliance risk. Automated cleanup must be implemented carefully — a DELETE without proper
batching can generate huge write-ahead log entries that replicate slowly and cause replication lag.
The rule is: always batch, never delete unbounded.

## Implementation

### Archive Records Beyond Retention Policy
```sql
-- Move old records to archive table before deletion
-- Retention example: keep active orders for 2 years, archive beyond that

-- Create archive table with same schema
CREATE TABLE orders_archive AS SELECT * FROM orders LIMIT 0;

-- Archive in batches (1000 rows at a time to avoid lock contention)
DO $$
DECLARE
    batch_size INT := 1000;
    rows_moved INT;
BEGIN
    LOOP
        WITH moved AS (
            DELETE FROM orders
            WHERE created_at < NOW() - INTERVAL '2 years'
              AND status IN ('completed', 'cancelled')
            LIMIT batch_size
            RETURNING *
        )
        INSERT INTO orders_archive SELECT * FROM moved;

        GET DIAGNOSTICS rows_moved = ROW_COUNT;
        EXIT WHEN rows_moved = 0;

        PERFORM pg_sleep(0.1);  -- brief pause between batches
    END LOOP;
END $$;
```

### Soft-Delete → Hard-Delete After Grace Period
```ts
// Soft deletes (deleted_at IS NOT NULL) accumulate forever without cleanup
// Hard-delete 30 days after soft-delete

async function hardDeleteExpiredSoftDeletes() {
  const BATCH_SIZE = 500;
  const GRACE_PERIOD_DAYS = 30;

  let totalDeleted = 0;
  let batchDeleted: number;

  do {
    const result = await db.execute(sql`
      WITH batch AS (
        SELECT id FROM user_data
        WHERE deleted_at < NOW() - INTERVAL '${GRACE_PERIOD_DAYS} days'
        LIMIT ${BATCH_SIZE}
        FOR UPDATE SKIP LOCKED   -- safe for parallel workers
      )
      DELETE FROM user_data
      WHERE id IN (SELECT id FROM batch)
    `);

    batchDeleted = result.rowsAffected;
    totalDeleted += batchDeleted;

    if (batchDeleted > 0) {
      await sleep(100);  // 100ms pause between batches
    }
  } while (batchDeleted === BATCH_SIZE);  // stop when we get < full batch

  return { deleted: totalDeleted };
}
```

### Orphaned Files in Storage
```ts
// Files in storage that no longer have a database record referencing them
async function cleanupOrphanedStorageFiles() {
  // Get all file paths from storage
  const { data: storageFiles } = await supabase.storage
    .from('uploads')
    .list('', { limit: 1000 });

  // Get all referenced file paths from DB
  const referencedPaths = new Set(
    await db.select('file_path').from('attachments').pluck('file_path')
  );

  // Find orphans
  const orphans = storageFiles
    ?.filter(f => !referencedPaths.has(f.name))
    .map(f => f.name) ?? [];

  // Delete in batches of 100 (storage API limit)
  for (let i = 0; i < orphans.length; i += 100) {
    const batch = orphans.slice(i, i + 100);
    await supabase.storage.from('uploads').remove(batch);
  }

  return { deletedFiles: orphans.length };
}
```

### Expired Sessions
```ts
async function cleanupExpiredSessions() {
  // Sessions table can grow unbounded without cleanup
  const result = await db.execute(sql`
    DELETE FROM sessions
    WHERE expires_at < NOW() - INTERVAL '7 days'  -- extra buffer after expiry
  `);
  // Note: sessions table can be large — add a partial index:
  // CREATE INDEX idx_sessions_expired ON sessions (expires_at) WHERE expires_at < NOW();
  return { deleted: result.rowsAffected };
}
```

### Rate Limit Logs Cleanup
```sql
-- Rate limit entries older than 90 days are never queried
DELETE FROM rate_limit_log
WHERE created_at < NOW() - INTERVAL '90 days';
-- Add to cron: runs nightly, fast because of index on created_at
```

### Safety Rules Enforced in Code
```ts
// Never run DELETE without a LIMIT or date boundary
async function safeDelete(table: string, where: string, limit = 1000) {
  if (!where.includes('WHERE')) {
    throw new Error('Delete without WHERE clause is not allowed');
  }
  // The application should enforce batch limits
  return db.execute(`DELETE FROM ${table} WHERE ${where} LIMIT ${limit}`);
}
```

## Key Rules
- Always batch deletes — never `DELETE FROM table WHERE created_at < cutoff` without `LIMIT`
- Use `FOR UPDATE SKIP LOCKED` when running cleanup in parallel workers to prevent double-processing
- Archive before deleting for compliance-sensitive data — hard deletes are irreversible
- Grace period (30 days after soft-delete) provides recovery window before permanent loss
- Create partial indexes on `deleted_at` and `expires_at` columns for cleanup query performance
- Log cleanup results (rows deleted per run) for audit trail and anomaly detection
- Run storage orphan cleanup after DB cleanup — never delete DB records then discover storage still has the files
