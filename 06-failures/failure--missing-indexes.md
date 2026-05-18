# Failure: Missing Database Indexes

## What It Is

A query without an index on the filtered/sorted columns performs a sequential scan (full table scan) — it reads every row. A 1M-row table without an index takes seconds per query; with an index, milliseconds.

## Detection

### Postgres EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE user_id = 'abc' AND status = 'pending' ORDER BY created_at DESC;
```

Look for:
- `Seq Scan` = no index used (often bad)
- `Index Scan` = index used (good)
- `Index Only Scan` = covering index (best)
- High `cost=` values relative to other queries

### Supabase Dashboard

Supabase → Database → Query Performance — shows slow queries and missing indexes automatically.

### pg_stat_user_tables

```sql
SELECT relname, seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > 1000
ORDER BY seq_scan DESC;
```

Tables with high `seq_scan` counts are candidates for indexing.

## What to Index

### WHERE clauses

```sql
-- Query: WHERE user_id = $1
CREATE INDEX orders_user_id_idx ON orders (user_id);

-- Query: WHERE user_id = $1 AND status = $2
CREATE INDEX orders_user_status_idx ON orders (user_id, status);
-- Column order matters: most selective / most used first
```

### ORDER BY

```sql
-- Query: ORDER BY created_at DESC
CREATE INDEX orders_created_at_idx ON orders (created_at DESC);

-- Combined: WHERE status = $1 ORDER BY created_at DESC
CREATE INDEX orders_status_created_idx ON orders (status, created_at DESC);
```

### Foreign Keys

Always index foreign keys — JOINs and ON DELETE CASCADE need them:

```sql
CREATE INDEX orders_user_id_idx ON orders (user_id);
CREATE INDEX comments_post_id_idx ON comments (post_id);
```

### Partial Indexes

Index only the rows you actually query:

```sql
-- Only index active users (most queries filter by active = true)
CREATE INDEX active_users_email_idx ON users (email) WHERE active = true;

-- Only index unprocessed jobs
CREATE INDEX pending_jobs_idx ON jobs (created_at) WHERE status = 'pending';
```

Partial indexes are smaller and faster than full-table indexes.

## Common Missing Index Patterns

```sql
-- Multi-tenant app without org_id index
SELECT * FROM documents WHERE org_id = $1 AND user_id = $2;
-- CREATE INDEX documents_org_user_idx ON documents (org_id, user_id);

-- Soft delete pattern without index on deleted_at
SELECT * FROM users WHERE deleted_at IS NULL;
-- CREATE INDEX users_not_deleted_idx ON users (id) WHERE deleted_at IS NULL;

-- Status + timestamp queries (common in job queues)
SELECT * FROM jobs WHERE status = 'pending' ORDER BY priority DESC, created_at ASC;
-- CREATE INDEX jobs_pending_idx ON jobs (priority DESC, created_at ASC) WHERE status = 'pending';
```

## Index Costs

Indexes are not free:
- **Write overhead**: every INSERT/UPDATE/DELETE updates all relevant indexes.
- **Storage**: indexes use disk space (can be 50%+ of table size).
- **Bloat**: frequent updates cause index bloat; run `REINDEX` or `VACUUM` periodically.

Don't index every column — index columns that appear in:
- High-frequency WHERE clauses
- JOIN conditions
- ORDER BY on large tables

Don't index:
- Columns with very low cardinality (boolean flags) — unless using partial index
- Tables under 10,000 rows — sequential scan is often faster at that size

## Key Rules

- Check `EXPLAIN ANALYZE` before declaring a query "done" on any table expected to grow.
- Foreign key columns almost always need an index.
- Multi-tenant apps need `(org_id, ...)` composite indexes on every shared table.
- Add indexes as part of the migration that adds the column or creates the query — not as a later "fix."
