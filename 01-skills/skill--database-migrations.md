# Database Migrations

## What Is a Migration

A migration is a SQL file that describes a change to the database schema. Migrations are:
- **Versioned**: numbered in order (0001, 0002, ...)
- **Tracked**: Supabase records which have been applied
- **One-way by default**: write additive migrations, avoid destructive ones
- **Repeatable**: applying the same migration twice should not cause errors (use `IF NOT EXISTS`, `IF NOT COLUMN`)

## Creating Migrations with Supabase CLI

```bash
# From project directory with Supabase CLI configured
supabase migration new add_discount_to_invoices

# Creates: supabase/migrations/20260518120000_add_discount_to_invoices.sql
```

## Safe Migration Patterns

### Adding a Column (Safe)
```sql
-- 20260518_add_discount_to_invoices.sql
ALTER TABLE invoices 
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(10,2) DEFAULT 0;

COMMENT ON COLUMN invoices.discount_amount IS 'Discount applied to invoice total';
```

`IF NOT EXISTS` makes this idempotent — safe to run twice.

### Adding an Index (Safe)
```sql
CREATE INDEX IF NOT EXISTS idx_invoices_customer_id ON invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status) 
  WHERE status = 'pending';
```

### Adding a Table (Safe)
```sql
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own notifications"
ON notifications FOR SELECT
TO authenticated
USING (user_id = auth.uid());
```

### Adding NOT NULL Column to Existing Table

Must backfill BEFORE adding constraint:
```sql
-- Step 1: Add nullable column
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_email TEXT;

-- Step 2: Backfill (update existing rows)
UPDATE invoices 
SET customer_email = customers.email
FROM customers
WHERE invoices.customer_id = customers.id;

-- Step 3: Add NOT NULL constraint AFTER backfill
ALTER TABLE invoices ALTER COLUMN customer_email SET NOT NULL;
```

If you add NOT NULL without backfilling, the migration fails for tables with existing rows.

## Applying Migrations

### Via Supabase MCP (Preferred)
```
mcp__plugin_supabase_supabase__apply_migration
{
  "project_id": "...",
  "migration_content": "ALTER TABLE invoices ADD COLUMN discount_amount NUMERIC(10,2) DEFAULT 0;"
}
```

### Via Supabase Dashboard
Supabase dashboard → SQL Editor → paste and run.

### Via CLI (Local Dev)
```bash
supabase db push   # push local migrations to remote
supabase db reset  # reset local to match migrations (destructive locally)
```

## Checking What's Applied

```
mcp__plugin_supabase_supabase__list_migrations
```

Or via SQL:
```sql
SELECT version, name, created_at
FROM supabase_migrations.schema_migrations
ORDER BY version DESC;
```

## Dangerous Migration Patterns

### Dropping a Column
```sql
-- RISKY: any code referencing this column breaks
ALTER TABLE invoices DROP COLUMN old_notes;

-- SAFER SEQUENCE:
-- 1. Deploy code that doesn't reference old_notes
-- 2. Wait for all deployments
-- 3. Run: ALTER TABLE invoices DROP COLUMN old_notes;
```

### Renaming a Column
```sql
-- RISKY: breaks all queries using the old name
ALTER TABLE invoices RENAME COLUMN customer_name TO client_name;

-- SAFER: additive migration (see principle--additive-first.md)
```

### Changing Column Type
```sql
-- RISKY: existing data might not fit
ALTER TABLE invoices ALTER COLUMN total TYPE TEXT;

-- ALWAYS test in a branch database first:
-- Supabase branch: mcp__plugin_supabase_supabase__create_branch
```

## Using Supabase Branches for Testing Migrations

Before applying migrations to production:
1. Create a branch: `mcp__plugin_supabase_supabase__create_branch`
2. Apply migration to the branch
3. Test with the branch database URL
4. If successful: merge branch → applies to production
5. If failed: reset and fix

## Migration Naming Convention

```
YYYYMMDD_description_of_change.sql
20260518_add_discount_to_invoices.sql
20260519_add_notifications_table.sql
20260520_add_customer_email_to_invoices.sql
```

Descriptive names make it easy to understand the schema history without reading SQL.
