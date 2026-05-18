# Review: Database Migration Review Checklist

## Overview
Migrations are the most dangerous code in a production system — they're often irreversible, they can lock tables and cause downtime, and their impact scales with data volume. A migration that runs in 10ms on a dev database with 100 rows can take 45 minutes on production with 50 million rows. Review every migration with production scale in mind.

## Implementation / Key Points

### Down Migration (Reversibility)
```sql
-- up.sql
ALTER TABLE orders ADD COLUMN notes TEXT;

-- down.sql
ALTER TABLE orders DROP COLUMN notes;
```
Every `up.sql` needs a `down.sql` that reverses it. Exception: destructive operations (DROP TABLE, DELETE) where reversal is impossible — these require explicit acknowledgment and backup verification before running.

### Column Rename — Use Expand-Contract
```sql
-- Bad: immediate rename (breaks running application)
ALTER TABLE users RENAME COLUMN user_name TO username;

-- Good: expand-contract (3 deployments)
-- Step 1: add new column
ALTER TABLE users ADD COLUMN username TEXT;
-- Step 2: backfill, update app to write both columns
UPDATE users SET username = user_name;
-- Step 3 (later): app now reads only username
-- Step 4 (later): drop old column
ALTER TABLE users DROP COLUMN user_name;
```
Any rename while the application is running will cause errors in the deployed version still using the old name.

### NOT NULL Columns Must Have a Default
```sql
-- Bad: fails on tables with existing rows
ALTER TABLE orders ADD COLUMN region TEXT NOT NULL;

-- Good: provide a default
ALTER TABLE orders ADD COLUMN region TEXT NOT NULL DEFAULT 'us-east';
-- Or: add nullable, backfill, then add constraint
ALTER TABLE orders ADD COLUMN region TEXT;
UPDATE orders SET region = 'us-east';
ALTER TABLE orders ALTER COLUMN region SET NOT NULL;
```

### Production-Size Testing
```bash
# Before merging, test the migration against a production data dump
pg_restore -d dev_db production_dump.sql
psql dev_db -c "\timing" -f migration.sql
# If this takes > 10 seconds, it will lock the table in production
```
Development databases with 100 rows never reveal migration performance problems. Always test against a production-sized dataset.

### INDEX CREATE CONCURRENTLY
```sql
-- Bad: locks the table for the entire index build
CREATE INDEX idx_orders_customer ON orders(customer_id);

-- Good: builds index without locking (PostgreSQL)
CREATE INDEX CONCURRENTLY idx_orders_customer ON orders(customer_id);
```
A regular `CREATE INDEX` on a table with millions of rows takes an `AccessShareLock` that blocks writes. `CONCURRENTLY` takes longer but doesn't block. Note: cannot be run inside a transaction block.

### Lock Time Documentation
```sql
-- Migration: add-not-null-constraint.sql
-- Estimated lock time: ~2s (tested against production-size dump)
-- Lock type: ACCESS EXCLUSIVE (blocks reads and writes)
-- Deploy window: low-traffic period, maintenance mode if > 10s
ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
```
Document lock time and type in migration comments. This enables deployment planning.

### Irreversible Operation Safeguards
```sql
-- Bad: no warning, no backup verification
DROP TABLE legacy_invoices;

-- Good: explicit safeguard process
-- 1. Verify backup exists and is restorable: [link to backup verification runbook]
-- 2. Rename to _deprecated first, deploy, observe for 1 week
ALTER TABLE legacy_invoices RENAME TO legacy_invoices_deprecated;
-- 3. Only then drop
-- DROP TABLE legacy_invoices_deprecated;  -- run in separate deployment
```

### Migration Review Checklist
- [ ] `down.sql` exists for every `up.sql` (or documented justification why reversal is impossible)
- [ ] Column renames use expand-contract pattern
- [ ] New `NOT NULL` columns have a `DEFAULT` or go through nullable → backfill → constraint steps
- [ ] Migration tested against a production-size data dump
- [ ] Estimated lock time documented for any DDL statement
- [ ] New indexes use `CREATE INDEX CONCURRENTLY`
- [ ] DROP TABLE / irreversible operations have: backup verification, staging test, deploy window planned
- [ ] Migration runs in a reasonable time (< 30s) or has explicit maintenance window

### Common Lock Types (PostgreSQL)
| Operation | Lock Type | Blocks |
|---|---|---|
| `CREATE INDEX CONCURRENTLY` | ShareUpdateExclusiveLock | Other concurrent builds only |
| `CREATE INDEX` | ShareLock | Writes |
| `ALTER TABLE ADD COLUMN` (with default) | AccessExclusiveLock | Reads + writes |
| `ALTER TABLE ADD COLUMN NULL` | AccessExclusiveLock | Reads + writes (brief) |
| `UPDATE` (backfill) | RowExclusiveLock | Other writes to same rows |

## Key Rules
- Every migration needs a down migration unless irreversibility is explicitly acknowledged and documented
- Never rename a column in a single deployment — use expand-contract across multiple deployments
- New NOT NULL columns require a default value or a 3-step migration (add nullable, backfill, add constraint)
- Test all migrations against production-size data before merging — development data hides timing issues
- Use `CREATE INDEX CONCURRENTLY` for any index on a table that receives production traffic
- Document estimated lock time and type in the migration file — enables deployment planning
- Irreversible operations (DROP TABLE, DELETE data) require backup verification before running
