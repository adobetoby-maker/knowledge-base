# MCP Tool: supabase / get_advisors

**Plugin:** `plugin:supabase:supabase`
**Tool name:** `mcp__plugin_supabase_supabase__get_advisors`
**What it does:** Runs Supabase's built-in advisor against the database and returns detected performance and security issues. Like a free audit.

## Parameters
```json
{
  "project_id": "string (required)"
}
```

## Usage
```javascript
mcp__plugin_supabase_supabase__get_advisors({
  project_id: "abcdefghijklmnop"
})
```

## What It Detects

### Security Issues
```
- RLS disabled on tables that probably should have it
- Policies that unintentionally expose all rows (e.g., USING (true) on sensitive tables)
- Auth schema exposure (anon role accessing auth.* tables)
- Missing auth checks on storage buckets
```

### Performance Issues
```
- Missing indexes on foreign key columns (causes full table scans on joins)
- Unused indexes (waste space, slow writes)
- Tables without any indexes at all
- Large tables with no primary key
- Missing indexes on commonly filtered columns
```

## Response Shape
```json
{
  "advisors": [
    {
      "name": "no-index-fk",
      "title": "Missing index on foreign key",
      "severity": "warn",
      "description": "Table 'orders' column 'user_id' references users(id) but has no index. This causes full table scans when joining.",
      "remediation": "CREATE INDEX idx_orders_user_id ON public.orders(user_id);"
    },
    {
      "name": "rls-disabled",
      "title": "RLS not enabled",
      "severity": "error",
      "description": "Table 'invoices' has no RLS policy and is accessible by the anon role.",
      "remediation": "ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;"
    }
  ]
}
```

## Workflow
```
1. list_tables         → understand schema
2. get_advisors        → detect issues automatically  
3. execute_sql         → investigate specific issues
4. apply_migration     → fix the issues
5. get_advisors again  → verify issues resolved
```

## Common Findings in New Projects
These are almost always found in fresh schemas:
1. Missing index on `user_id` foreign key — fix: `CREATE INDEX idx_{table}_user_id ON public.{table}(user_id)`
2. RLS not enabled on sensitive tables — fix: `ALTER TABLE public.{table} ENABLE ROW LEVEL SECURITY`
3. Missing `updated_at` index if you filter by recency

## Severity Levels
```
error  → security risk, fix immediately
warn   → performance issue, fix before production traffic
info   → suggestion, consider it
```
