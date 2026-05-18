# Database Migration Checklist

## Before Writing the Migration

- [ ] Run `list_tables` via MCP to see current schema
- [ ] Check if target table has RLS enabled — if so, new columns need policy consideration
- [ ] Confirm column names match existing convention (snake_case, consistent suffixes: `_id`, `_at`, `_cents`)
- [ ] Check if any existing indexes cover the column — avoid duplicates

## Migration Rules

**Additive first:**
- ADD column before using it
- ADD new index before dropping old one
- ADD new function before modifying callers
- NEVER DROP in the same migration as the ADD — wait for deployment to confirm no issues

**Safe default values:**
```sql
-- WRONG — adding NOT NULL without default on table with data:
ALTER TABLE invoices ADD COLUMN sent_at timestamptz NOT NULL;

-- CORRECT — add nullable first:
ALTER TABLE invoices ADD COLUMN sent_at timestamptz;
-- Then backfill if needed:
UPDATE invoices SET sent_at = created_at WHERE status = 'sent';
-- Then add constraint if needed (in a later migration):
ALTER TABLE invoices ALTER COLUMN sent_at SET NOT NULL WHERE status = 'sent';
```

**Lock-safe for large tables:**
```sql
-- WRONG — takes full table lock on large table:
ALTER TABLE large_table ADD COLUMN status text DEFAULT 'active';

-- CORRECT — add nullable, backfill in batches, then set default:
ALTER TABLE large_table ADD COLUMN status text;

-- Backfill in batches (outside migration, in a script):
UPDATE large_table SET status = 'active' WHERE id IN (
  SELECT id FROM large_table WHERE status IS NULL LIMIT 1000
);
-- Repeat until done

ALTER TABLE large_table ALTER COLUMN status SET DEFAULT 'active';
ALTER TABLE large_table ALTER COLUMN status SET NOT NULL;
```

## Migration Template

```sql
-- Migration: add_due_date_to_invoices
-- Date: 2025-01-15
-- Description: Add optional due date field to invoices table

-- Up:
ALTER TABLE invoices
ADD COLUMN due_date date;

CREATE INDEX invoices_due_date_idx ON invoices (due_date)
WHERE due_date IS NOT NULL;

-- Down (document but don't execute automatically):
-- DROP INDEX invoices_due_date_idx;
-- ALTER TABLE invoices DROP COLUMN due_date;
```

## RLS Considerations

When adding a column:
- [ ] Does any existing SELECT policy need to filter on this column? (e.g., soft delete `deleted_at`)
- [ ] Does the new column contain sensitive data that should be hidden from some users?
- [ ] If adding a FK column, does the referenced table have RLS that could cause JOIN issues?

When adding a new table:
- [ ] Add `ENABLE ROW LEVEL SECURITY`
- [ ] Add SELECT policy before any data is inserted
- [ ] Add INSERT/UPDATE/DELETE policies matching your auth pattern
- [ ] Test with browser client (not admin client) to verify policies work

## Index Review

Before adding an index:
- [ ] Will this index be used? Check with `EXPLAIN ANALYZE`
- [ ] Is the column already covered by a composite index?
- [ ] Is it a FK column? (Postgres doesn't auto-index FKs — always add one)

```sql
-- Always index foreign keys:
CREATE INDEX invoices_customer_id_idx ON invoices (customer_id);

-- Partial indexes for common filtered queries:
CREATE INDEX invoices_unpaid_idx ON invoices (due_date)
WHERE status IN ('pending', 'overdue');

-- Composite index for a common sort+filter combo:
CREATE INDEX invoices_customer_status_idx ON invoices (customer_id, status);
```

## Testing the Migration

```sql
-- Before applying to production, test:

-- 1. Apply migration on development/staging branch
-- 2. Verify table structure:
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'invoices'
ORDER BY ordinal_position;

-- 3. Verify indexes:
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'invoices';

-- 4. Verify RLS policies:
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'invoices';

-- 5. Verify with anon user (check RLS works):
SET LOCAL role = anon;
SELECT * FROM invoices LIMIT 1;  -- should fail or return empty
```

## Rollback Plan

Document the rollback for every migration before applying:

```
Migration: add_due_date_to_invoices
Rollback:
1. DROP INDEX invoices_due_date_idx
2. ALTER TABLE invoices DROP COLUMN due_date
3. No data loss if column was empty
4. If column had data: need to consider if downstream code used it
```

If rollback would lose data, that's a signal to reconsider the migration approach.
