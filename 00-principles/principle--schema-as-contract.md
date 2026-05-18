# Principle: Schema as Contract

## Overview
A database schema is a public API. Columns are parameters; their types are the contract. Every service that reads your database — your own app, analytics pipelines, reporting tools, data warehouses — is a consumer of that contract. Breaking changes to the schema break consumers silently: no compiler error, no HTTP 400, just wrong data or runtime crashes discovered hours later.

## Breaking vs Non-Breaking Changes

### Non-breaking (safe to deploy without coordination)
- Add a new nullable column: existing queries ignore it
- Add a new table: nothing reads it yet
- Add an index: transparent to queries (briefly locks for creation, but readable)
- Widen a type: `VARCHAR(100)` → `VARCHAR(255)` is backward-compatible
- Add a check constraint that all existing data already satisfies

```sql
-- Safe: additive, existing code unaffected
ALTER TABLE orders ADD COLUMN shipped_at TIMESTAMPTZ;
ALTER TABLE orders ADD INDEX idx_orders_customer_id (customer_id);
```

### Breaking (require coordinated multi-step migration)
- Rename a column: old code references the old name, new name doesn't exist yet
- Change a type narrowly: `TEXT` → `ENUM` rejects values not in the set
- Add `NOT NULL` without a default: existing rows violate the constraint immediately
- Remove a column: any code reading it fails
- Change a foreign key: cascades, deletes, or constraint changes affect dependent rows

```sql
-- Dangerous in one step:
ALTER TABLE users RENAME COLUMN username TO handle;
ALTER TABLE users ALTER COLUMN status TYPE status_enum USING status::status_enum;
ALTER TABLE users DROP COLUMN legacy_id;
```

## Treating Schema Like an API

**Versioning mindset:**
- Breaking changes require a migration plan, just like a breaking API change requires a new version
- Deprecate before removing: add the new column, keep the old one for one full release cycle
- Communicate schema changes in the same place you communicate API changes

**Consumer-driven thinking:**
Ask before removing: "who reads this column?" Querying `pg_stat_user_tables` or looking at application code is not enough — analytics scripts, BI tools, and third-party integrations may read directly.

```sql
-- Find all columns in a table to audit before dropping
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'orders'
ORDER BY ordinal_position;
```

## The Rename Trap

Renaming a column is the most common schema break:
1. Developer renames column in migration
2. Deploys migration to production
3. Old app code tries to read old column name → crashes
4. Rollback requires reverting both the migration AND the app code simultaneously

Correct approach: add the new name, write both from application code, backfill, then drop the old.

## Schema in Code Reviews

Every schema migration deserves the same scrutiny as an API change:
- Is this additive or breaking?
- Which services read this table?
- Is there a corresponding application code change, and does deployment order matter?
- Is there a rollback path without a compensating migration?
- Will this migration take a table lock, and for how long?

## Key Rules
- Adding nullable columns and indexes is safe; everything else requires a migration plan
- Never rename a column in a single deploy; use expand-contract over two release cycles
- `ADD COLUMN ... NOT NULL` without a `DEFAULT` rewrites every row — add a default or backfill first
- Treat analytics and BI tools as schema consumers — they have no app-layer type safety
- Document schema change rationale in the migration file itself, not just the PR
- After a schema change is fully deployed and stable, clean up any temporary columns or dual-write code
