# MCP Tool: supabase / apply_migration

**Plugin:** `plugin:supabase:supabase`
**Tool name:** `mcp__plugin_supabase_supabase__apply_migration`
**What it does:** Applies a named SQL migration to the Supabase project. Tracked in the migrations table — provides an audit trail.

## Parameters
```json
{
  "project_id": "string (required)",
  "name": "string (required) — snake_case migration name, e.g. 'add_user_preferences'",
  "query": "string (required) — SQL to execute"
}
```

## When to Use This vs execute_sql
```
execute_sql  → ad-hoc queries, debugging, SELECT inspection, quick fixes
apply_migration → schema changes you want to track:
  - CREATE TABLE
  - ALTER TABLE
  - CREATE INDEX
  - CREATE POLICY
  - DROP (with confirmation)
```

## Example Usage
```sql
-- Migration: create_orders_table
CREATE TABLE public.orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  total_cents INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = user_id);

CREATE INDEX idx_orders_user_id ON public.orders(user_id);
CREATE INDEX idx_orders_status ON public.orders(status);
```

## Naming Convention
Migration names follow snake_case, describe what changes:
```
add_profiles_table
add_user_preferences_column
create_orders_indexes
add_rls_to_products
backfill_display_names
drop_legacy_sessions_table
```

## Response
On success: `{ "success": true }`
On failure: error with the SQL error message.

## Safety
- Goes directly to the connected Supabase project — no staging
- No rollback mechanism — you need to write a compensating migration
- Always preview complex migrations with `execute_sql` SELECT first
- Confirm with user before: DROP TABLE, ALTER COLUMN (type change), TRUNCATE

## Check Migration History
```sql
-- Verify migration was applied
SELECT * FROM supabase_migrations.schema_migrations ORDER BY inserted_at DESC LIMIT 10;
```
