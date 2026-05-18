# MCP Tool: supabase / execute_sql

**Plugin:** `plugin:supabase:supabase`
**Tool name:** `mcp__plugin_supabase_supabase__execute_sql`
**What it does:** Runs arbitrary SQL against a Supabase project. Returns rows or error.

## Parameters
```json
{
  "project_id": "string (required) — Supabase project ref, e.g. 'abcdefghijklmnop'",
  "query": "string (required) — SQL query to execute"
}
```

## Common Uses

### Inspect data
```sql
SELECT * FROM public.users LIMIT 10;
SELECT COUNT(*) FROM public.orders WHERE status = 'pending';
```

### Debug RLS
```sql
-- Check if RLS is enabled on a table
SELECT relrowsecurity FROM pg_class WHERE relname = 'users';

-- Check policies
SELECT * FROM pg_policies WHERE tablename = 'users';
```

### Quick fixes
```sql
-- Backfill a column
UPDATE public.profiles SET display_name = email WHERE display_name IS NULL;

-- Create missing index
CREATE INDEX IF NOT EXISTS idx_orders_user ON public.orders(user_id);
```

### Schema inspection
```sql
-- List all tables
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';

-- List columns of a table
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'users' ORDER BY ordinal_position;
```

## Response Shape
```json
{
  "rows": [{ "column": "value", ... }],
  "rowCount": 5
}
```
On error: exception with message containing PostgreSQL error code.

## Safety Rules
- **Never run DROP, TRUNCATE, or DELETE without explicit user confirmation**
- SELECT queries are safe — read freely
- Always use `LIMIT` when inspecting unknown tables (could be millions of rows)
- `apply_migration` is safer for schema changes — it's versioned
- `execute_sql` bypasses RLS (runs as postgres superuser via service role)

## Getting the Project ID
```
# From Supabase dashboard URL: 
# https://supabase.com/dashboard/project/ABCDEFGHIJKLMNOP
#                                                ^^^^^^^^^^^^^^^^

# Or via MCP:
mcp__plugin_supabase_supabase__list_projects
# Returns: [{ id: "abcdefghijklmnop", name: "my-project" }]
```

## Alternatives
- `apply_migration` — for schema changes (tracked, versioned)
- `list_tables` — for schema inspection without SQL
- `get_advisors` — for detecting performance/security issues automatically
