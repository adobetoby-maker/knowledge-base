# Principle: Migration Safety

## Overview
Database migrations run on live production data, often against tables with millions of rows and active traffic. A migration that takes 10 seconds on a development database can take 30 minutes on production and lock the table for the duration, causing a full outage. Safe migrations require treating the production database as a constraint — every migration must be designed around what the database can do without causing downtime, not what is convenient to write.

## Key Points

### Never Lock Tables in Production

PostgreSQL DDL that rewrites or locks tables:
```sql
-- DANGEROUS on large tables — holds ACCESS EXCLUSIVE lock for full rewrite
ALTER TABLE orders ADD COLUMN status VARCHAR(50) DEFAULT 'pending' NOT NULL;

-- SAFE — adds column nullable first, backfill separately, add constraint last
ALTER TABLE orders ADD COLUMN status VARCHAR(50);
UPDATE orders SET status = 'pending' WHERE status IS NULL; -- batched
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
```

```sql
-- DANGEROUS — locks table while building index
CREATE INDEX idx_orders_user ON orders(user_id);

-- SAFE — builds index without locking
CREATE INDEX CONCURRENTLY idx_orders_user ON orders(user_id);
```

### Test on Production-Size Data
Running a migration on 1,000 rows in dev that takes 0.3ms tells you nothing about its behavior on 50 million rows in production. Before running:
1. Restore a recent prod snapshot to a staging environment with full data
2. Run the migration and measure duration
3. Simulate production traffic during migration (even basic read queries)
4. If duration > 1 second, redesign as a zero-downtime migration

### Always Write a Rollback Migration
Every `up.sql` should have a corresponding `down.sql`:
```sql
-- up.sql
ALTER TABLE users ADD COLUMN subscription_tier VARCHAR(20) DEFAULT 'free';

-- down.sql
ALTER TABLE users DROP COLUMN subscription_tier;
```
The rollback is not just for comfort — it must be tested before the forward migration runs in production.

### Renaming Columns: Dual-Write Pattern
Renaming a column while code is running against it breaks reads or writes instantly:
```
Step 1: Add new column (old column still active)
Step 2: Write to both old + new column in application code
Step 3: Backfill new column from old column for existing rows
Step 4: Switch reads to new column
Step 5: Stop writing to old column
Step 6: Drop old column (after confirming no code references it)
```
This spreads a "rename" across multiple deploys — safe but slow. The alternative (one-shot rename) requires a maintenance window.

### Batched Backfills
Never run an unbatched UPDATE on millions of rows:
```sql
-- DANGEROUS — single transaction, locks rows, can cause replication lag
UPDATE orders SET processed = true WHERE processed IS NULL;

-- SAFE — update in batches, release locks between batches
DO $$
DECLARE
  batch_size INT := 1000;
  updated INT;
BEGIN
  LOOP
    UPDATE orders SET processed = true
    WHERE id IN (
      SELECT id FROM orders WHERE processed IS NULL LIMIT batch_size
    );
    GET DIAGNOSTICS updated = ROW_COUNT;
    EXIT WHEN updated = 0;
    PERFORM pg_sleep(0.1); -- brief pause to reduce contention
  END LOOP;
END $$;
```

### Migration Timing
- Run during lowest-traffic window if the migration is risky
- For zero-downtime migrations, timing matters less but still prefer off-peak for first production run
- Have rollback plan rehearsed before migration starts — not being decided during an incident

## Key Rules
- `CREATE INDEX CONCURRENTLY` always — never `CREATE INDEX` on a live table
- Adding NOT NULL columns: add nullable → backfill → add constraint (never add NOT NULL with a default in one step on large tables)
- Test migration duration on production-scale data before running on production
- Every migration file needs a companion rollback file
- Backfills must be batched and monitored, not run as a single transaction
- Column renames require the dual-write pattern across multiple deploys
- If a migration takes more than a few seconds on production data, it needs to be redesigned
