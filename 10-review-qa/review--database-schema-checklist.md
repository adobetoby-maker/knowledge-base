# Review: Database Schema Checklist

## Before Running Any Migration

Run through every item before applying schema changes to production. This catches the mistakes that are hardest to fix after data exists.

## Primary Keys

- [ ] Every table has a primary key
- [ ] New tables use `UUID DEFAULT gen_random_uuid()` not SERIAL integers
  - Exception: high-volume append-only tables (logs, events) where integer sequences are more efficient
- [ ] Never use composite PKs unless modeling a true many-to-many junction table
- [ ] Junction tables have their own UUID PK (not just a composite PK)

## Column Types

- [ ] No `FLOAT` or `DOUBLE PRECISION` for money — use `INTEGER` (cents)
- [ ] Timestamps are `TIMESTAMPTZ` not `TIMESTAMP` — TIMESTAMPTZ stores UTC, TIMESTAMP doesn't
- [ ] String columns have appropriate length constraints (`VARCHAR(n)`) or `TEXT CHECK (length(col) <= n)`
- [ ] Boolean columns have `NOT NULL DEFAULT false` — never nullable booleans (NULL means neither true nor false)
- [ ] Enum-like strings use `TEXT CHECK (status IN ('draft', 'published'))` or Postgres `ENUM` type

## Constraints

- [ ] Every `NOT NULL` column that must have data has `NOT NULL`
- [ ] Email columns have `UNIQUE NOT NULL` if they're login identifiers
- [ ] Foreign key columns have `REFERENCES` constraints
- [ ] Foreign key constraints specify `ON DELETE` behavior: `CASCADE`, `SET NULL`, or `RESTRICT`
  - `CASCADE`: child rows deleted with parent — use for owned data (order items belong to order)
  - `SET NULL`: foreign key set to NULL when parent deleted — use for optional relationships
  - `RESTRICT`: prevent parent deletion while children exist — use for safety (can't delete a user who has invoices)
- [ ] Check constraints on columns where not all values are valid (`CHECK (price > 0)`)

## Row-Level Security

- [ ] Every table that contains user data has `ENABLE ROW LEVEL SECURITY`
- [ ] Every RLS-enabled table has at least one policy (or access is blocked for everyone)
- [ ] SELECT policies use `USING`, INSERT policies use `WITH CHECK`, UPDATE policies use both
- [ ] Admin tables (internal, no user data) either have RLS disabled intentionally or service-role-only access
- [ ] Policies don't use `USING (true)` without understanding it means "everyone" including anonymous users

## Indexes

- [ ] Every foreign key column has an index
- [ ] Columns used in `WHERE` clauses in hot queries have indexes
- [ ] `created_at` has an index on append-only tables (time-based pagination)
- [ ] Partial indexes where most queries filter by a condition (`WHERE deleted_at IS NULL`)
- [ ] No redundant indexes (the PK already indexes `id`, don't add another)
- [ ] Large tables: consider `CONCURRENTLY` for adding indexes (doesn't lock the table)

## Soft Delete

- [ ] Tables with soft delete have `deleted_at TIMESTAMPTZ` column
- [ ] Partial indexes exclude soft-deleted rows: `CREATE INDEX ... WHERE deleted_at IS NULL`
- [ ] RLS policies exclude soft-deleted rows from SELECT
- [ ] Hard deletes are still used for truly transient data (sessions, temp tokens)

## Naming Conventions

- [ ] Table names: plural snake_case (`orders`, `line_items`, `user_profiles`)
- [ ] Column names: snake_case (`created_at`, `user_id`, `first_name`)
- [ ] Foreign key columns: `{referenced_table_singular}_id` (`user_id`, `order_id`)
- [ ] Boolean columns: `is_*` or past tense (`is_active`, `email_verified`, `approved`)
- [ ] Timestamp columns: `*_at` suffix (`created_at`, `updated_at`, `deleted_at`, `sent_at`)
- [ ] Money columns: `*_cents` suffix (`price_cents`, `total_cents`)

## Migration Safety

- [ ] Adding a column: safe if nullable or has a default
- [ ] Adding a NOT NULL column: requires a default value or backfill in same migration
- [ ] Dropping a column: application must not reference it BEFORE migration runs
- [ ] Renaming a column: use a two-phase migration (add new, backfill, drop old)
- [ ] Adding a NOT NULL constraint to existing column: backfill nulls first
- [ ] Large table changes: test with `EXPLAIN ANALYZE` — some operations lock the table

## Verification Queries

```sql
-- Tables missing RLS
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
  AND tablename NOT IN (SELECT tablename FROM pg_tables WHERE rowsecurity = true)

-- Foreign keys without indexes
SELECT
  tc.table_name, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = tc.table_name AND indexdef LIKE '%' || kcu.column_name || '%'
  )

-- Nullable boolean columns
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND data_type = 'boolean'
  AND is_nullable = 'YES'
```
