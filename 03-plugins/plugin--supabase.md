# Plugin: supabase@claude-plugins-official

**What it provides:** Direct API access to Supabase projects — schema, migrations, logs, SQL, storage, edge functions.
**When to reach for it:** Anytime you need to inspect or modify a Supabase project without writing code. Faster than looking in the dashboard.

## Key MCP Tools (load schema with ToolSearch first)

### Schema & Tables
- `list_tables` — see all tables in a project. Always run first before modifying schema.
- `execute_sql` — run any SQL. SELECT for inspection, careful with mutations.
- `apply_migration` — apply a SQL migration file. Runs in a transaction.
- `list_migrations` — see migration history.
- `generate_typescript_types` — generate TypeScript types from current schema. Run after schema changes.

### Debugging
- `get_logs` — fetch recent logs by service (api, auth, storage, realtime, edge). Best first step for any Supabase bug.
- `get_advisors` — security and performance advisor results. Run before going live.

### Project Management
- `list_projects` — all your Supabase projects with IDs.
- `get_project` — details for a specific project.
- `get_project_url` — get the API URL for a project. Needed for client config.
- `get_publishable_keys` — get anon key. Safe to expose in browser code.

### Branches
- `create_branch`, `list_branches`, `merge_branch`, `delete_branch` — for Supabase branching (like git for DB).

### Edge Functions
- `deploy_edge_function` — deploy an edge function from code.
- `list_edge_functions`, `get_edge_function`

## Common Workflows

**Inspect a broken query:**
```
1. list_tables → confirm table name is correct
2. execute_sql → run the query directly, see actual results
3. get_logs → check API logs for RLS rejections or errors
```

**After schema change:**
```
1. apply_migration → run the migration
2. generate_typescript_types → update types file
3. Copy output to src/types/supabase.ts
```

**Debug auth issue:**
```
1. get_logs (service: "auth") → see auth events
2. execute_sql → check if user exists in auth.users
3. execute_sql → check RLS policies: SELECT * FROM pg_policies WHERE tablename = 'your_table'
```

## Schema Loading
```javascript
ToolSearch("select:mcp__plugin_supabase_supabase__execute_sql,mcp__plugin_supabase_supabase__list_tables")
```

## Important Constraints
- `apply_migration` goes directly to the remote project — no local staging
- `execute_sql` mutations are immediate and real — no undo
- Always `list_tables` before `apply_migration` to confirm schema state
