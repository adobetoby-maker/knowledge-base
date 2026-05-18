# Database Review Checklist

## Before Applying Any Migration

- [ ] Migration has an UP operation AND can be rolled back
- [ ] No destructive operations (DROP TABLE, DROP COLUMN) without explicit review
- [ ] NOT NULL columns include a DEFAULT or backfill before constraint is added
- [ ] New FK constraint has an index on the FK column
- [ ] Migration tested on a branch database before applying to production

## Schema Design

- [ ] UUIDs for primary keys (`gen_random_uuid()`) — not serial integers
- [ ] Timestamps use `TIMESTAMPTZ` — not `TIMESTAMP` (timezone-aware)
- [ ] NULLABLE vs NOT NULL: will this always have a value? If yes: NOT NULL + DEFAULT
- [ ] TEXT vs VARCHAR: prefer TEXT (no length enforcement) unless there's a real max
- [ ] NUMERIC(10,2) for money — not FLOAT (float imprecision for currency)
- [ ] JSONB for structured but schema-flexible data — not JSON (JSONB is indexed)

## Indexes

- [ ] Primary key indexed (automatic)
- [ ] FK columns indexed (NOT automatic — must add manually)
- [ ] Columns used in WHERE clauses frequently: add index
- [ ] Columns used in ORDER BY on large tables: add index
- [ ] Partial index where only a subset needs indexing (e.g., only pending invoices)

```sql
-- Missing FK index is a common mistake
-- After adding FK:
CREATE INDEX idx_invoices_customer_id ON invoices(customer_id);

-- Partial index example
CREATE INDEX idx_invoices_pending ON invoices(created_at) WHERE status = 'pending';
```

## RLS Policies

- [ ] RLS enabled on every table with user data
- [ ] Each policy has a meaningful name
- [ ] `auth.uid()` used correctly (returns UUID of authenticated user)
- [ ] Admin access uses service-role client (bypasses RLS) — not a policy granting admin access
- [ ] Test: does the policy correctly restrict rows for authenticated users?
- [ ] Test: does the policy correctly block unauthenticated access?

```sql
-- Verify policies exist
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename;

-- Test policy as specific user
SET request.jwt.claims = '{"sub": "user-uuid-here"}';
SELECT * FROM invoices;  -- should only show that user's invoices
```

## Query Patterns

- [ ] No N+1: fetching a list and then querying each item individually
- [ ] JOINs used where data from multiple tables is needed
- [ ] `.count()` used for count queries — not fetching all rows to `Array.length`
- [ ] `.range()` used for pagination — not fetching all rows and slicing
- [ ] `.single()` used when expecting exactly one row (throws on 0 or 2+)
- [ ] `.maybeSingle()` when row might not exist (returns null, not error)

## Data Integrity

- [ ] Foreign key constraints defined for all relationships
- [ ] CHECK constraints for enum-like values: `CHECK (status IN ('pending', 'paid'))`
- [ ] `ON DELETE CASCADE` vs `ON DELETE RESTRICT` — which is correct for this relationship?
- [ ] Unique constraints on fields that must be unique (invoice numbers, email)

```sql
-- Example constraints
ALTER TABLE invoices 
  ADD CONSTRAINT invoices_status_check CHECK (status IN ('pending', 'paid', 'overdue')),
  ADD CONSTRAINT invoices_number_unique UNIQUE (number);
```

## Large Tables (> 100k rows)

- [ ] Queries use indexed columns in WHERE
- [ ] No full table scans in production queries
- [ ] VACUUM/ANALYZE scheduled (Supabase handles this automatically on paid plans)
- [ ] Consider partitioning for time-series data (invoices older than 2 years)

## Backup Verification

Before any destructive migration:
- [ ] Supabase automatic backup is recent (check Supabase dashboard)
- [ ] Know how to restore: Supabase dashboard → Database → Backups → Restore
- [ ] Test the restore process in a branch before relying on it

## Supabase-Specific

- [ ] Extensions needed? (`pg_crypto`, `vector`, etc.) — enable in dashboard first
- [ ] Edge Functions have proper auth headers if they need to access the database
- [ ] Supabase Storage bucket policies set correctly (public vs private)
- [ ] Realtime subscription tables have realtime enabled (default is off)
