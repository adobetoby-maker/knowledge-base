# Optimizing Read Paths Separately from Write Paths

The same data structure that is optimal for writing is rarely optimal for reading. Writes favor normalized data (single source of truth, referential integrity, small row sizes for updates). Reads favor denormalized data (pre-joined, pre-aggregated, shaped for the exact query). Treating reads and writes as the same problem is the root cause of most query performance issues.

## Denormalization for Reads

Normalization eliminates redundancy — the same fact is stored in one place. This is correct for writes. For reads, it means every query that needs related data must join across tables.

Denormalization accepts controlled redundancy in exchange for read performance. Rather than joining `orders`, `users`, and `products` at query time, a read model stores a pre-flattened row: `{ order_id, user_email, product_name, quantity, total }`. The join happened at write time.

Pre-computed counts are the most common form: instead of `SELECT COUNT(*) FROM comments WHERE post_id = ?` on every page load, store `comment_count` on the `posts` row and increment it when a comment is added. The trade-off is complexity in the write path; the gain is a trivially fast read.

The discipline: denormalization must be intentional, not accidental. Accidental denormalization (copying data around without a strategy) creates inconsistency. Intentional denormalization is bounded to specific read models that have explicit ownership.

## Materialized Views

A materialized view is a denormalized query result stored as a table and refreshed on a schedule or on write. Useful when:
- The query is expensive (multiple joins, aggregations)
- The data doesn't need to be real-time (a summary updated every 5 minutes is fine)
- The source data changes less frequently than it's read

In Postgres, `CREATE MATERIALIZED VIEW` + `REFRESH MATERIALIZED VIEW CONCURRENTLY` (no read lock). In Supabase, refresh via a scheduled function. In application code, the refresh can be triggered after writes that affect the view's source data.

The failure mode: forgetting to refresh the view after a schema change that affects its query. Always test materialized view refresh in CI.

## Caching Read Models

When a read model's source data changes infrequently relative to how often it's read, cache the read model at the application layer. The key insight is that cache invalidation is simpler when you own the write path: every write that modifies the underlying data is an explicit event you can hook into to invalidate or update the cache.

Cache the full read model shape, not individual fields. Fetching from cache should be a single key lookup that returns exactly what the UI needs, without any transformation.

Tag-based invalidation (e.g., Redis tags) is more robust than TTL-based for data that must be consistent after writes. TTL is fine for data where brief staleness is acceptable.

## Eventual Consistency Trade-off

Separating read models from write models implies a gap: the read model may lag behind the write model. A user who just wrote data might not see it reflected in the read model for milliseconds to seconds, depending on propagation.

This is the eventual consistency trade-off. For many read models (analytics, leaderboards, public feeds), a small lag is acceptable. For reads that immediately follow a user's own write ("you just updated your profile; here's what it looks like"), it is not acceptable.

Design around this by:
- Optimistic UI: update the local view immediately from the submitted values, don't wait for the read model
- Returning the written entity directly from the write endpoint, not from the read model
- Using a "read-your-writes" consistency guarantee where the read model accepts the current user's writes synchronously before going async for others

## Key Rules

- Normalize for writes; denormalize for reads — they are different optimization targets
- Pre-compute aggregates (counts, sums) at write time rather than recalculating at read time
- Materialized views are the right tool when query cost is high and data can tolerate lag
- Cache read models by shape (full UI payload), not by field, and invalidate on write events
- Eventual consistency is acceptable for shared/aggregated reads; not acceptable for reads immediately following a user's own write
- Denormalization must be intentional with explicit ownership; accidental data copying creates inconsistency
