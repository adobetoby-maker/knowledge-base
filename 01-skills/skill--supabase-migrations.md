# Skill: supabase-migrations

**Trigger:** Creating or modifying database schema — adding tables, columns, indexes, RLS policies, or functions.
**Returns:** Migration SQL, naming conventions, safety checklist, rollback strategy.

## Migration File Naming

```
supabase/migrations/
  20260515120000_create_invoices.sql
  20260515130000_add_invoice_status_index.sql
  20260516090000_add_rls_policies_invoices.sql
```

Format: `YYYYMMDDHHMMSS_description.sql`
Always use timestamps, never sequential numbers. Timestamps prevent merge conflicts.

## Migration File Structure

```sql
-- Migration: create_invoices
-- Description: Creates the invoices table with RLS

-- Up migration (what this adds)
CREATE TABLE IF NOT EXISTS invoices (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  amount decimal(10,2) NOT NULL CHECK (amount > 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'cancelled')),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_user_id ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices(status);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at DESC);

-- Enable RLS
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own invoices"
  ON invoices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own invoices"
  ON invoices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invoices_updated_at
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

## Safety Checklist Before Running

```
[ ] Migration is additive (adds tables/columns), not destructive (drops/alters)
[ ] For ALTER TABLE: is this column nullable or has a default? (Required for tables with data)
[ ] RLS enabled on every table that contains user data
[ ] Indexes added for all foreign keys and frequently-queried columns
[ ] Tested in Supabase branch or local first, not directly on production
[ ] Rollback plan documented (usually: drop the new table/column)
```

## Destructive Migrations (High Risk)

For operations that alter existing data or remove columns/tables:

1. Never drop without a feature flag / staged rollout
2. Add column as nullable first → backfill data → add NOT NULL constraint → separate migration
3. Never drop a column that application code still references

```sql
-- Safe column addition to table with existing rows:
-- Step 1 (this migration): add nullable
ALTER TABLE users ADD COLUMN IF NOT EXISTS display_name text;

-- Step 2 (next migration, after backfill): add constraint
ALTER TABLE users ALTER COLUMN display_name SET NOT NULL;
```

## Running Migrations

```bash
# Apply pending migrations to linked project
supabase db push

# Generate migration from local schema diff
supabase db diff -f migration_name

# Reset local database to migration history
supabase db reset

# Apply to remote with confirmation
supabase db push --include-roles --include-seed
```

## Supabase MCP Tool Alternative

Via the MCP server (apply_migration tool):
```
apply_migration(project_id, name, query)
```

Always test with `execute_sql` (read-only queries) before running destructive migrations.

## Common Migration Patterns

### Add column with backfill
```sql
ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal decimal(10,2);
UPDATE orders SET subtotal = amount / 1.08 WHERE subtotal IS NULL;
```

### Add foreign key
```sql
ALTER TABLE line_items ADD COLUMN invoice_id uuid;
ALTER TABLE line_items ADD CONSTRAINT fk_line_items_invoice
  FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;
CREATE INDEX idx_line_items_invoice_id ON line_items(invoice_id);
```

### Create enum type
```sql
CREATE TYPE invoice_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');
ALTER TABLE invoices ALTER COLUMN status TYPE invoice_status USING status::invoice_status;
```
