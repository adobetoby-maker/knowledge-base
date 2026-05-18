# MCP: Supabase Schema Operations

## Tool Reference

| Tool | Purpose |
|---|---|
| `list_tables` | Show all tables and their columns |
| `execute_sql` | Run SQL queries and migrations |
| `apply_migration` | Apply a migration with a tracked name |
| `list_migrations` | Show migration history |
| `get_advisors` | Security and performance recommendations |

## Inspecting Existing Schema

Before making any schema changes, always inspect first:

```
Use mcp__plugin_supabase_supabase__list_tables to see:
- All tables and their columns
- Column types, nullable, defaults
- Foreign key relationships
```

When targeting a specific table:
```
execute_sql: SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'invoices'
ORDER BY ordinal_position;
```

## Checking Existing Indexes

```sql
-- Run via execute_sql:
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'invoices';
```

Check before adding an index — duplicates waste space and slow writes.

## Checking RLS Policies

```sql
-- Run via execute_sql:
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'customers';
```

When adding a new table or column, check what policies exist and whether they need updating.

## Applying a Migration

Use `apply_migration` for tracked changes (named, visible in migration history):

```
apply_migration({
  name: "add_due_date_to_invoices",
  query: "ALTER TABLE invoices ADD COLUMN due_date date;"
})
```

Use `execute_sql` for one-off queries (not tracked in migration history):
- Data backfills
- Checking data
- Testing a query

## Safe Migration Patterns via MCP

**Add column:**
```sql
ALTER TABLE invoices ADD COLUMN notes text;
```

**Add column with default (existing rows get default immediately):**
```sql
ALTER TABLE invoices ADD COLUMN status text NOT NULL DEFAULT 'draft';
```

**Add index:**
```sql
CREATE INDEX CONCURRENTLY invoices_customer_id_idx ON invoices (customer_id);
```
Use `CONCURRENTLY` for large tables — avoids full table lock.

**Add FK:**
```sql
ALTER TABLE invoices ADD COLUMN customer_id uuid REFERENCES customers(id);
CREATE INDEX invoices_customer_id_fk_idx ON invoices (customer_id);
```
Always create the index after adding the FK — Postgres doesn't auto-index FK columns.

## Creating a Table with Full Setup

```sql
-- Full table creation pattern:
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  amount_cents integer NOT NULL CHECK (amount_cents > 0),
  payment_method text NOT NULL DEFAULT 'cash',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes:
CREATE INDEX payments_invoice_id_idx ON payments (invoice_id);
CREATE INDEX payments_created_at_idx ON payments (created_at DESC);

-- RLS:
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policies (adjust to your auth pattern):
CREATE POLICY "Admins can manage payments"
ON payments FOR ALL
USING (true)
WITH CHECK (true);
-- Above is wide open — refine with actual auth.uid() check
```

## Generating TypeScript Types After Migration

After applying a migration, regenerate types:

```
Use mcp__plugin_supabase_supabase__generate_typescript_types
```

Then update `src/types/database.ts` (or wherever generated types live) to reflect the new schema.

## Checking for Advisors (Security/Performance)

```
Use mcp__plugin_supabase_supabase__get_advisors

Returns recommendations like:
- "Table X is missing indexes on FK columns"
- "Row level security is enabled but no policies exist"
- "Table X doesn't have RLS enabled"
```

Run after schema changes to catch issues early.
