# MCP: Supabase — Common Workflows

## Tool Reference

The Supabase MCP server exposes these tools for database management:

```
list_tables(project_id)
execute_sql(project_id, query)
apply_migration(project_id, name, query)
get_project(project_id)
get_project_url(project_id)
get_publishable_keys(project_id)
get_logs(project_id, service)
get_advisors(project_id)
list_organizations
list_projects
```

## Safe Read Operations (execute_sql)

Use `execute_sql` for any read or diagnostic query. It executes directly and returns results.

```
execute_sql(project_id, "SELECT COUNT(*) FROM invoices WHERE status = 'pending'")
execute_sql(project_id, "SELECT * FROM pg_policies WHERE tablename = 'invoices'")
execute_sql(project_id, "SELECT * FROM cron.job")
execute_sql(project_id, "EXPLAIN ANALYZE SELECT * FROM invoices WHERE user_id = '...'")
```

## Schema Changes (apply_migration)

For any DDL (CREATE, ALTER, DROP), use `apply_migration` not `execute_sql`. This creates a tracked migration record.

```
apply_migration(
  project_id,
  "add_invoice_status_index",
  "CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_status ON invoices(status);"
)
```

The `CONCURRENTLY` keyword prevents table locking on index creation — always use it for production tables with data.

## Common Diagnostic Queries

### Find slow queries
```sql
SELECT query, mean_exec_time, calls, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

### Find tables without RLS
```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT IN (
  SELECT DISTINCT tablename FROM pg_policies
);
```

### Find missing indexes on foreign keys
```sql
SELECT conrelid::regclass AS table, a.attname AS column
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'
AND NOT EXISTS (
  SELECT 1 FROM pg_index i
  WHERE i.indrelid = c.conrelid
  AND a.attnum = ANY(i.indkey)
);
```

### Check table sizes
```sql
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
  pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC;
```

## RLS Policy Management

### View current policies
```sql
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

### Add select policy
```sql
CREATE POLICY "users_view_own" ON invoices
  FOR SELECT USING (auth.uid() = user_id);
```

### Add service-role bypass (for admin operations)
```sql
CREATE POLICY "service_role_bypass" ON invoices
  TO service_role USING (true) WITH CHECK (true);
```

## Reading Logs

```
get_logs(project_id, 'api')       -- API request logs
get_logs(project_id, 'postgres')  -- Database logs
get_logs(project_id, 'edge')      -- Edge function logs
```

Look for:
- 401/403 errors → RLS or auth issue
- Slow query warnings (>1000ms) → missing index
- Connection limit warnings → connection pooling needed

## Advisor Checks

```
get_advisors(project_id)
```

Returns Supabase's built-in recommendations:
- Performance: missing indexes, N+1 patterns
- Security: tables without RLS, weak policies
- Reliability: connection pool settings

Run advisors after any significant schema change.

## Getting Project Credentials for Code

```
get_project_url(project_id)    -- NEXT_PUBLIC_SUPABASE_URL value
get_publishable_keys(project_id)  -- NEXT_PUBLIC_SUPABASE_ANON_KEY value
```

These are safe to expose in client-side code — they are intentionally public. The service role key is NOT accessible via MCP (correct security behavior).
