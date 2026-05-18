# MCP Tool: supabase / list_tables

**Plugin:** `plugin:supabase:supabase`
**Tool name:** `mcp__plugin_supabase_supabase__list_tables`
**What it does:** Returns all tables in the public schema with their columns, types, and constraints. The fastest way to understand a database schema without writing SQL.

## Parameters
```json
{
  "project_id": "string (required)"
}
```

## Usage
```javascript
mcp__plugin_supabase_supabase__list_tables({
  project_id: "abcdefghijklmnop"
})
```

## Response Shape
```json
{
  "tables": [
    {
      "name": "users",
      "columns": [
        { "name": "id", "type": "uuid", "nullable": false, "default": "gen_random_uuid()" },
        { "name": "email", "type": "text", "nullable": false },
        { "name": "created_at", "type": "timestamptz", "nullable": false, "default": "now()" }
      ],
      "primaryKey": ["id"],
      "foreignKeys": [
        { "column": "org_id", "referencedTable": "organizations", "referencedColumn": "id" }
      ]
    }
  ]
}
```

## When to Use list_tables vs execute_sql

### list_tables
- Understanding schema quickly
- Finding what tables and columns exist
- Before writing queries (know the column names first)
- At start of any database work

### execute_sql for schema inspection
When you need more detail:
```sql
-- Check indexes
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'your_table';

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'your_table';

-- Check triggers
SELECT trigger_name, event_manipulation, action_statement 
FROM information_schema.triggers WHERE event_object_table = 'your_table';

-- Check foreign key relationships in detail
SELECT tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table_name, 
       ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = 'your_table';
```

## Getting the Project ID
```javascript
// If you don't know the project ID
mcp__plugin_supabase_supabase__list_projects({})
// Returns: [{ id: "abcdefghijklmnop", name: "jrs-auto-repair", status: "active" }]
```

## Related Tools
- `execute_sql` — run queries against the tables
- `apply_migration` — change the schema
- `get_advisors` — check for performance/security issues in the schema
- `generate_typescript_types` — generate TypeScript types from the schema
