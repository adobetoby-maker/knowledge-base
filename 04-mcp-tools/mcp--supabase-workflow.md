# MCP: Supabase Workflow

## Overview
The Supabase MCP tools provide a structured path from schema inspection to production changes. The most important rule: DDL changes (CREATE TABLE, ALTER COLUMN, ADD INDEX) always go through `apply_migration`—never `execute_sql`—because migrations are versioned, tracked, and can be reviewed before applying. Using `execute_sql` for DDL bypasses the migration history, making rollbacks impossible and team collaboration fragile.

## Tool Reference

| Tool | Use For | Avoid For |
|---|---|---|
| `list_tables` | Understanding current schema before changes | — |
| `apply_migration` | DDL: CREATE, ALTER, DROP, CREATE INDEX | DML queries |
| `execute_sql` | DML: SELECT, INSERT, UPDATE, DELETE | Schema changes |
| `get_logs` | Debugging errors, slow queries | — |
| `get_advisors` | Performance hints, index suggestions | — |
| `list_branches` | Preview branch management | — |
| `create_branch` | Isolate schema changes from production | — |

## Workflow: Add a Column Safely
```
1. list_tables(projectId: "xxx")
   → inspect current schema, find the table, note existing columns

2. apply_migration(projectId: "xxx", name: "add_user_phone", sql: "
     ALTER TABLE users
     ADD COLUMN phone TEXT,
     ADD COLUMN phone_verified_at TIMESTAMPTZ;
   ")
   → migration is versioned and tracked

3. execute_sql(projectId: "xxx", query: "
     SELECT id, phone FROM users LIMIT 5;
   ")
   → verify the column exists and data shape looks right
```

## Workflow: Debug a Production Error
```
1. get_logs(projectId: "xxx", service: "api", limit: 50)
   → scan for: "relation X does not exist", "permission denied for table Y",
     "violates foreign key constraint"

2. execute_sql(projectId: "xxx", query: "
     SELECT schemaname, tablename, tableowner, rowsecurity
     FROM pg_tables WHERE tablename = 'orders';
   ")
   → verify table exists and RLS is enabled

3. get_advisors(projectId: "xxx")
   → check for missing indexes, unused indexes, bloated tables
```

## Workflow: Preview Branch for Risky Changes
```
1. create_branch(projectId: "xxx", branchName: "add-billing-schema")
   → creates isolated DB copy

2. apply_migration on branch:
   apply_migration(projectId: "branch_xxx", name: "billing_tables", sql: "...")

3. Test against branch with execute_sql

4. merge_branch(projectId: "xxx", branchId: "branch_xxx")
   → applies migration to production
```

## RLS Policy Patterns
```sql
-- Always verify RLS is on before adding policies
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Users can only read their own documents
CREATE POLICY "users_own_documents"
ON documents FOR SELECT
USING (auth.uid() = user_id);

-- Service role bypasses RLS (used in server-side admin operations)
-- Never grant service role key to client-side code
```

## Common Migration Patterns
```sql
-- Safe column add (never NOT NULL without DEFAULT on existing rows)
ALTER TABLE orders
ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb NOT NULL;

-- Add index concurrently (doesn't lock table in production)
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);

-- Rename with compatibility (add new, keep old, drop old later)
ALTER TABLE users ADD COLUMN display_name TEXT;
UPDATE users SET display_name = full_name;
-- (deploy app pointing to display_name)
-- (later migration drops full_name)
```

## Key Rules
- **`apply_migration` for DDL, `execute_sql` for DML** — never mix; DDL via `execute_sql` has no rollback path.
- **`list_tables` before any schema change** — verify the current state before altering it.
- **`get_logs` before `get_advisors`** — logs reveal immediate errors; advisors reveal structural performance issues.
- **Use `CREATE INDEX CONCURRENTLY`** — regular `CREATE INDEX` takes a write lock; CONCURRENTLY runs without locking.
- **Never add `NOT NULL` column without `DEFAULT`** — existing rows will fail the constraint during migration.
- **Branch for risky changes** — schema changes that can't be rolled back easily should be tested on a preview branch.
- **`get_advisors` after schema changes** — Supabase's advisor detects missing foreign key indexes automatically.
