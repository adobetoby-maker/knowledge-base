# Disambig: Redis vs Memcached

## Overview
Redis and Memcached both provide in-memory key-value caching, but Redis is a superset of what Memcached does—it adds data structures, persistence, pub/sub, atomic operations, and scripting. Memcached's one genuine advantage is its multi-threaded architecture for pure cache workloads at extreme scale, but that advantage only matters when Redis's single-threaded model becomes a bottleneck (rare in practice). For most applications, Redis is the correct choice because cache + pub/sub + queues in one system beats three separate systems.

## Comparison

| Property | Redis | Memcached |
|---|---|---|
| Data structures | String, Hash, List, Set, Sorted Set, Stream | String only |
| Persistence | Optional (RDB snapshots, AOF journal) | None (volatile) |
| Pub/Sub | Native | None |
| Atomic operations | Yes (INCR, MULTI/EXEC, Lua scripting) | Basic (CAS) |
| TTL per key | Yes | Yes |
| Threading | Single-threaded (Redis 6+ has I/O threads) | Multi-threaded |
| Cluster mode | Redis Cluster (built-in sharding) | Client-side sharding only |
| Memory efficiency | Slightly higher overhead | Slightly lower overhead |
| Use as queue | Yes (BullMQ, RSMQ) | No |
| Sorted sets | Yes (leaderboards, rate limiting) | No |

## When to Use Redis

```
Cache + anything else
→ pub/sub, queues, rate limiting, sessions, leaderboards
→ Redis does all of them; one system vs four

Session storage
→ TTL-aware, persistent through restart, readable by multiple servers

Rate limiting
→ INCR + EXPIRE = atomic counter with TTL; sorted sets for sliding window rate limits

BullMQ / job queues
→ BullMQ requires Redis; Memcached cannot serve as a queue

Real-time features (chat, notifications, live updates)
→ Redis Pub/Sub broadcasts messages to all subscribers

Leaderboards
→ Sorted Sets (ZADD/ZRANGE) are purpose-built for score-ranked data

Distributed locks
→ SET key value NX EX timeout = atomic lock acquisition; no Memcached equivalent
```

## When Memcached Might Win

```
Pure object cache, extreme scale, multi-threaded requirement
→ Memcached can use all CPU cores for cache operations
→ Redis is single-threaded for command execution
→ This matters at ~100k+ ops/sec on a CPU-bound workload

Simple slab-allocated cache with no other requirements
→ Memcached's memory allocation is predictable; Redis has overhead per key

Legacy system already using Memcached
→ Replacing a working Memcached install with Redis has a risk/reward tradeoff
```

## Redis Common Patterns

```ts
import Redis from 'ioredis';
const redis = new Redis(process.env.REDIS_URL!);

// 1. Cache-aside pattern
async function getCachedUser(id: string) {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(id);
  await redis.setex(`user:${id}`, 300, JSON.stringify(user)); // 5 min TTL
  return user;
}

// 2. Atomic rate limiting (sorted set sliding window)
async function isRateLimited(ip: string, limit: number, windowMs: number): Promise<boolean> {
  const key = `ratelimit:${ip}`;
  const now = Date.now();
  const windowStart = now - windowMs;

  const pipeline = redis.pipeline();
  pipeline.zremrangebyscore(key, '-inf', windowStart); // remove old entries
  pipeline.zadd(key, now, String(now));                // add current request
  pipeline.zcard(key);                                 // count requests in window
  pipeline.pexpire(key, windowMs);                     // cleanup TTL
  const results = await pipeline.exec();

  const count = results?.[2]?.[1] as number;
  return count > limit;
}

// 3. Pub/Sub (separate connection required for subscriber)
const subscriber = new Redis(process.env.REDIS_URL!);
subscriber.subscribe('notifications');
subscriber.on('message', (channel, message) => {
  broadcastToClients(JSON.parse(message));
});

// Publisher (on the regular connection)
redis.publish('notifications', JSON.stringify({ userId, type: 'order_ready' }));
```

## Key Rules
- **Redis by default** — Memcached's only advantage is multi-threaded performance at extreme scale.
- **One Redis for multiple concerns** — cache, sessions, pub/sub, and queues sharing one Redis instance is fine.
- **Pub/sub needs a separate connection** — Redis subscriber connections block waiting for messages; use a dedicated connection, not the shared cache connection.
- **TTL on every cache key** — keys without TTL grow unbounded; always set an expiry.
- **Sorted sets for rate limiting** — the sliding window approach with ZREMRANGEBYSCORE + ZADD + ZCARD is atomic and accurate.
- **Never use Redis as primary database** — persistence is optional; it's a cache, not source of truth.
