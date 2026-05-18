# Review: Database Query Review Checklist

## Overview
Most application performance problems trace back to database queries. A single unindexed JOIN on a large table or an N+1 pattern in a loop can turn a fast endpoint into a multi-second response under real data volume. Query review is most valuable during code review, before the query reaches production with small data that hides the problem.

## Implementation / Key Points

### EXPLAIN ANALYZE — Use It
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM orders 
JOIN customers ON orders.customer_id = customers.id
WHERE orders.status = 'pending';
```
Key things to look for:
- `Seq Scan` on a large table → add an index
- `Rows=1000 Actual Rows=50000` → stale statistics, run `ANALYZE`
- High `Buffers: shared hit/read` → data not in cache
- Long `actual time` on a node → that node is the bottleneck

### No SELECT *
```sql
-- Bad: fetches all columns, includes large blobs, breaks if schema changes
SELECT * FROM users WHERE id = $1;

-- Good: fetch exactly what you need
SELECT id, name, email, created_at FROM users WHERE id = $1;
```
`SELECT *` is a performance tax (unnecessary data transfer) and a fragility tax (query result shape changes with schema changes).

### JOINs on Indexed Columns
```sql
-- Always verify both sides of a JOIN have indexes
-- Check with:
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'orders' AND indexdef LIKE '%customer_id%';
```
If `orders.customer_id` isn't indexed, a JOIN with `customers` does a sequential scan of orders for every customer row.

### N+1 Detection
N+1 occurs when code queries a list, then queries each item individually:
```typescript
// Bad: 1 query for orders + N queries for each customer
const orders = await db.select().from(ordersTable);
for (const order of orders) {
  const customer = await db.select()
    .from(customersTable)
    .where(eq(customersTable.id, order.customerId));
  // ...
}

// Good: 1 query with JOIN
const orders = await db
  .select({ order: ordersTable, customer: customersTable })
  .from(ordersTable)
  .leftJoin(customersTable, eq(ordersTable.customerId, customersTable.id));
```
In ORM logs, N+1 looks like the same query running dozens of times with different ID values.

### Pagination on All List Queries
```sql
-- Bad: unbounded — returns all 500,000 rows
SELECT * FROM events ORDER BY created_at DESC;

-- Good: cursor-based pagination
SELECT * FROM events 
WHERE created_at < $cursor 
ORDER BY created_at DESC 
LIMIT 50;
```
Any query that returns a list must have a LIMIT. Default the limit to 50–100, cap at 1000. Keyset (cursor) pagination is more performant than offset for large datasets.

### Parameterized Queries Only
```typescript
// Bad: SQL injection vector
const users = await db.query(`SELECT * FROM users WHERE email = '${email}'`);

// Good: parameterized
const users = await db.select()
  .from(usersTable)
  .where(eq(usersTable.email, email));
// Or with raw SQL:
await db.execute(sql`SELECT * FROM users WHERE email = ${email}`);
```
No exceptions. Even "trusted" internal inputs can contain quotes or injection payloads from upstream data.

### Index Review Checklist
```sql
-- Find missing indexes via pg_stat_user_tables
SELECT relname, seq_scan, idx_scan
FROM pg_stat_user_tables
WHERE seq_scan > idx_scan AND n_live_tup > 10000
ORDER BY seq_scan DESC;

-- Common columns that need indexes
-- - Foreign key columns (customer_id, order_id, etc.)
-- - Columns in WHERE clauses of frequent queries
-- - Columns in ORDER BY for large result sets
-- - Composite index: (status, created_at) for filtered+sorted queries
```

### Query Review Checklist
- [ ] `EXPLAIN ANALYZE` run on any query touching a table with > 10k rows
- [ ] No `SELECT *` — specific columns named
- [ ] All JOIN columns have indexes on both sides
- [ ] No query inside a loop (N+1 check)
- [ ] All list queries have LIMIT
- [ ] Parameterized query — no string interpolation
- [ ] Transaction used for multi-step operations that must be atomic

## Key Rules
- Run EXPLAIN ANALYZE on every new query that touches a large table before merging
- SELECT * is never acceptable in production queries — name your columns
- Foreign key columns must be indexed — ORMs don't create these automatically in all cases
- N+1 is the most common ORM mistake — look for loops that contain await/query calls
- Unbounded list queries will eventually OOM the service — LIMIT is always required
- Parameterized queries are non-negotiable — string interpolation into SQL is an injection vulnerability
