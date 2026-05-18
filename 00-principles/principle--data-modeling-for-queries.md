# Data Modeling for Queries

The most common modeling mistake is designing tables to match the domain object's "natural" shape, then struggling to query it efficiently. Start with the queries instead. The schema exists to serve reads — writes happen once, reads happen constantly.

## Query-First Schema Design

Before writing a single CREATE TABLE, write the queries the UI will run. If the dashboard needs "all invoices for this customer with total, status, and line-item count in a single request," design the schema to serve exactly that without joins or post-processing.

List every query by frequency and latency requirement. The queries that run most often, or that block page load, drive the schema. Rare admin queries can afford joins; user-facing queries cannot.

## Denormalization Is a Tool, Not a Sin

3NF eliminates redundancy, which is valuable for writes. For reads, it creates joins, which are expensive at scale and hard to cache. Denormalize deliberately:

- Store `customer_name` on the `orders` table even though it's "also" on `customers` — avoids a join on every order list view
- Store `invoice_total` as a computed column updated on each line-item write — avoids SUM() on every invoice read
- Store `unread_count` on `conversations` — avoids COUNT on every inbox render

Every denormalized value needs a write trigger (application-level or DB trigger) to stay consistent. The cost is write complexity; the benefit is read simplicity. Pay the cost where writes are infrequent, reads are frequent.

## Composite Indexes Must Match Query Patterns

An index on `(user_id)` does not help a query filtering on `(user_id, status, created_at DESC)`. Indexes are used left-to-right — a composite index `(user_id, status, created_at)` satisfies filters on `user_id` alone, `user_id + status`, or all three. Order matters: put equality filters first, range/sort columns last.

Index every foreign key that appears in a WHERE clause or JOIN condition. Postgres does not automatically index foreign keys. An un-indexed FK on a large table means a sequential scan on every related lookup.

Covering indexes (include non-filtered columns) let Postgres satisfy a query from the index alone without touching the heap. For read-heavy tables, a covering index eliminates I/O on the hot path.

## The N+1 Trap

N+1 is what happens when a normalized schema meets a list view. The query fetches 50 orders, then for each order fires a separate query to get the customer name. Result: 51 queries instead of 1.

N+1 kills performance silently — the query log looks fine because each individual query is fast. Detect it by counting queries per request, not just total time.

Fix it at the query layer with joins or batch fetching (WHERE id IN (...)), not at the application layer with caching. Caching N+1 just makes the problem slower to notice.

## When to Normalize Anyway

Normalization is correct when data changes frequently and consistency matters more than read speed. User email addresses, prices, roles — these should stay normalized because stale denormalized copies cause correctness bugs, not just performance issues.

The rule: denormalize data that is read often and changes rarely. Keep normalized data that changes often or where stale reads are harmful.

## Key Rules

- Write the top 10 queries by frequency before designing the schema
- Denormalize read-heavy, write-infrequent data; keep normalized data that changes often
- Composite indexes must mirror the WHERE + ORDER BY clause left-to-right
- Index every FK column that appears in a JOIN or WHERE — Postgres doesn't do this automatically
- Detect N+1 by query count per request, not just latency
- Covering indexes eliminate heap access on hot-path queries — use them for read-heavy tables
- Computed columns (totals, counts) are cheaper than repeated aggregates at query time
