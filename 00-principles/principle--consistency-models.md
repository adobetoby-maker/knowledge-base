# Principle: Consistency Models

## Overview
"Use eventual consistency for performance" is one of the most misunderstood tradeoffs in distributed systems. Eventual consistency doesn't just mean data is sometimes stale — it means your application must be designed to handle conflicting writes, out-of-order reads, and the possibility that two users see different values for the same record simultaneously. Choosing the wrong model leads to either invisible data corruption or unnecessary architectural complexity.

## The Spectrum

### Strong Consistency
Every read sees the most recent write. If user A writes a value, any subsequent read — by any user, from any node — sees that value.

- **Where it applies:** Traditional relational databases with read-from-primary, synchronous replicas
- **Cost:** Higher latency (write must propagate before ACK), lower availability during network partitions
- **When to choose:** Financial balances, inventory counts, anything where stale reads cause incorrect business decisions

### Read-Your-Writes Consistency
After you write something, you'll always see your own write — but others might see the old value briefly.

- **Where it applies:** Most "consistent" web apps using primary reads for write requests, replicas for others
- **Cost:** Write requests hit the primary, adding latency; most reads can use replicas
- **When to choose:** User profile updates, settings changes, most CRUD applications

### Eventual Consistency
Writes propagate asynchronously; replicas will eventually converge on the same value, but reads during propagation may return stale data.

- **Where it applies:** NoSQL databases, CDN caches, DNS, Supabase read replicas when configured, Redis replication
- **Cost:** Requires conflict resolution strategy, idempotent writes, tolerant reader logic
- **When to choose:** Social feed likes/counts, analytics aggregations, catalog search indexes — data where brief staleness is acceptable

## What Eventual Consistency Actually Requires

Choosing eventual consistency is not free. Your application must handle:

**1. Conflict resolution strategy**
If two users update the same document simultaneously:
- Last-write-wins (LWW): whoever has the later timestamp wins (loses data)
- Merge: application merges both changes (complex, domain-specific)
- Optimistic locking: reject second writer with conflict error (requires client retry)

**2. Idempotent writes**
Retrying a write due to unclear ACK must not create duplicate data:
```typescript
// Idempotent: same ID always → same row, not a new row
await db.upsert({ id: generateIdempotencyKey(data), ...data });

// Not idempotent: retry creates duplicate
await db.insert(data);
```

**3. Tolerant reads**
UI must handle stale data gracefully. After creating a record, showing "0 results" briefly is confusing:
```typescript
// Optimistic update while write propagates
queryClient.setQueryData(['items'], (old) => [...old, newItem]);
// Invalidate and refetch after write confirms
await mutation.mutateAsync(newItem);
queryClient.invalidateQueries(['items']);
```

## CAP Theorem Simplified

In a distributed system, during a network partition you must choose:
- **CP (Consistency + Partition tolerance):** Return an error rather than stale data (HBase, Zookeeper)
- **AP (Availability + Partition tolerance):** Return stale data rather than an error (DynamoDB, Cassandra)

For most web apps on a single-region PostgreSQL, this is theoretical — you rarely hit network partitions. For globally distributed systems, this is a real design decision.

## Practical Guidance for Common Systems

| System | Default model | Notes |
|---|---|---|
| PostgreSQL (primary) | Strong | Reads from primary always current |
| PostgreSQL (read replica) | Eventual | Replication lag can be 0ms–seconds |
| Redis (single instance) | Strong | |
| Redis (replication) | Eventual | Async replication |
| Supabase (connection pooler) | Strong | Proxies to primary |
| Cloudflare KV | Eventual | ~60s propagation globally |
| CDN cache | Eventual | Until TTL expires |

## Key Rules
- "Eventual consistency for performance" is only justified when staleness is tolerable and conflicts are handled
- Eventual consistency requires: conflict resolution strategy, idempotent writes, tolerant UI
- Never use eventual consistency for financial balances, inventory, or seat reservations
- Read replicas introduce replication lag — reads immediately after writes may see stale data
- Optimistic locking (version columns) is the standard conflict resolution strategy for most apps
- Default to strong consistency and add eventual consistency only where scale demands it and the tradeoffs are explicitly understood
