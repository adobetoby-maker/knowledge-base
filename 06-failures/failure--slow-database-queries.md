# Failure: Slow Database Queries

## Overview
A query that runs in 2ms on a 1000-row development database can take 8000ms on a 1-million-row production table because of sequential scans, missing indexes, or N+1 patterns. Database performance problems are invisible during development and appear as mysterious slowdowns after launch. The tools exist to find and fix them — the failure is not using them before users experience the problem.

## Step 1: Find Slow Queries

**PostgreSQL `pg_stat_statements` extension** shows cumulative slow queries across all sessions:
```sql
-- Enable once per database
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find the top 10 slowest queries by total time
SELECT
  query,
  calls,
  total_exec_time / 1000 AS total_sec,
  mean_exec_time AS avg_ms,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

This reveals queries that run fast individually but are called 50,000 times (N+1 patterns).

**Supabase:** Available in the Dashboard → SQL Editor → Performance Advisor, or query `pg_stat_statements` directly.

## Step 2: Understand a Specific Query

`EXPLAIN ANALYZE` shows the actual execution plan with real row counts and timing:

```sql
EXPLAIN ANALYZE
SELECT o.*, c.name AS customer_name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 50;
```

**Red flags in the output:**
- `Seq Scan on orders` — scanning the whole table instead of using an index
- `cost=0.00..48291.00` — very high estimated cost
- `Rows Removed by Filter: 987432` — index could eliminate these rows before the scan
- `Sort Method: external merge Disk` — sort spilled to disk; needs `work_mem` increase or index

## Step 3: Add the Right Index

Missing index is the most common cause. Add on columns used in WHERE, JOIN, and ORDER BY:

```sql
-- WHERE clause
CREATE INDEX idx_orders_status ON orders(status);

-- Combined filter + sort
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);

-- Foreign key (always index FK columns — joins use them constantly)
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Partial index (for high-selectivity filters)
CREATE INDEX idx_orders_pending ON orders(created_at DESC)
WHERE status = 'pending';  -- Only indexes pending orders — much smaller
```

After adding the index, run `EXPLAIN ANALYZE` again to confirm `Index Scan` replaces `Seq Scan`.

## The N+1 Problem

The second most common cause. Loading a list of 50 orders, then running a separate query for each order's customer = 51 queries instead of 1.

```typescript
// N+1: 50 orders → 50 individual customer queries
const orders = await db.order.findMany({ where: { status: 'pending' } });
for (const order of orders) {
  const customer = await db.customer.findUnique({ where: { id: order.customerId } });
  // ^ This query runs 50 times
}

// Correct: single query with join
const orders = await db.order.findMany({
  where: { status: 'pending' },
  include: { customer: true },  // Prisma: single JOIN query
});
```

Detection: if your slow query log shows many nearly-identical queries with different `WHERE id = ?` values, it's N+1.

## Query Optimization Patterns

```sql
-- Use covering index (all needed columns in the index)
CREATE INDEX idx_orders_list ON orders(status, created_at DESC)
INCLUDE (id, customer_id, total_cents);
-- Query can be satisfied entirely from the index without touching the main table

-- Avoid SELECT * in joins — fetch only needed columns
SELECT o.id, o.status, o.total_cents, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
-- Not: SELECT o.*, c.*

-- Paginate with cursor, not OFFSET
-- OFFSET 10000 scans and discards 10000 rows before returning results
SELECT * FROM orders WHERE created_at < :cursor ORDER BY created_at DESC LIMIT 50;
```

## Key Rules
- `EXPLAIN ANALYZE` before and after every index addition — confirm it's used
- `pg_stat_statements` surfaces real production slow queries; check it weekly on growing tables
- Always index foreign key columns — joins without indexes cause full table scans
- N+1 queries are undetectable in unit tests; use query count assertions in integration tests
- `OFFSET`-based pagination degrades as offset grows; use cursor pagination for large datasets
- Adding an index on a large live table takes time and briefly impacts write performance — do it during low-traffic hours
