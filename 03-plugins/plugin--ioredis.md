# Plugin: ioredis

## Overview

ioredis is the standard Node.js Redis client. It handles connection pooling, auto-reconnect, pipeline/transaction support, Lua scripting, and cluster mode. For Upstash (serverless Redis), use `@upstash/redis` instead — ioredis requires a persistent TCP connection which doesn't work in serverless edge environments.

## Install

```bash
npm install ioredis
```

## Connection

```ts
import Redis from 'ioredis'

export const redis = new Redis(process.env.REDIS_URL)

// Explicit options
export const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  password: process.env.REDIS_PASSWORD,
  db: 0,
  maxRetriesPerRequest: 3,
  reconnectOnError: (err) => {
    if (err.message.includes('READONLY')) return true
    return false
  },
})

redis.on('error', (err) => {
  console.error('Redis connection error:', err)
})
```

## Basic Operations

```ts
// Strings
await redis.set('key', 'value')
await redis.set('key', 'value', 'EX', 3600)
const val = await redis.get('key')

// Numbers
await redis.incr('counter')
await redis.incrby('counter', 5)

// Delete
await redis.del('key')
await redis.del('key1', 'key2', 'key3')

// Expiry
await redis.expire('key', 3600)
await redis.ttl('key')
await redis.persist('key')

// Existence
const exists = await redis.exists('key')  // 0 or 1
```

## Hash Operations

```ts
await redis.hset('user:123', 'name', 'Alice', 'email', 'alice@example.com')
await redis.hget('user:123', 'email')
const user = await redis.hgetall('user:123')  // Record<string, string>

async function setHash(key: string, obj: Record<string, string | number>): Promise<void> {
  const flat = Object.entries(obj).flat().map(String)
  await redis.hset(key, ...flat)
}
```

## Lists and Sorted Sets

```ts
// Lists (queue pattern)
await redis.rpush('queue', 'item1', 'item2')
await redis.lpop('queue')
await redis.lrange('queue', 0, -1)

// Sorted sets (leaderboard pattern)
await redis.zadd('leaderboard', 1500, 'user:123')
await redis.zincrby('leaderboard', 50, 'user:123')
const top10 = await redis.zrevrange('leaderboard', 0, 9, 'WITHSCORES')
const rank = await redis.zrevrank('leaderboard', 'user:123')
```

## Pipeline (Batched Commands)

```ts
// Execute multiple commands in a single round-trip
const pipeline = redis.pipeline()
pipeline.get('key1')
pipeline.get('key2')
pipeline.set('key3', 'value3')
const results = await pipeline.exec()
// results: [[null, value1], [null, value2], [null, 'OK']]
```

## Transactions (MULTI/EXEC)

```ts
// Atomic: all or nothing
await redis
  .multi()
  .decrby('account:123:balance', 100)
  .incrby('account:456:balance', 100)
  .exec()
```

## Pub/Sub

```ts
// Subscriber requires a separate connection
const subscriber = redis.duplicate()

await subscriber.subscribe('notifications')
subscriber.on('message', (channel, message) => {
  const data = JSON.parse(message)
  console.log(channel, data)
})

// Publisher uses the main connection
await redis.publish('notifications', JSON.stringify({ type: 'order_ready', orderId: '123' }))
```

## Atomic Set-If-Not-Exists (Idempotency / Distributed Lock)

```ts
// SETNX: set only if key doesn't exist
const acquired = await redis.setnx(`lock:${resourceId}`, '1')
if (acquired) {
  await redis.expire(`lock:${resourceId}`, 30)  // Release after 30s max
  try {
    await doExclusiveWork()
  } finally {
    await redis.del(`lock:${resourceId}`)
  }
}
```

## Graceful Shutdown

```ts
process.on('SIGTERM', async () => {
  await redis.quit()  // Flush pipeline, send QUIT, close cleanly
  process.exit(0)
})
```

`redis.quit()` completes pending commands. `redis.disconnect()` closes immediately without flushing.

## Key Rules

- `redis.duplicate()` for pub/sub connections — a connection in pub/sub mode can only subscribe/receive, not send regular commands.
- `maxRetriesPerRequest: null` is required when using ioredis with BullMQ.
- Key naming: `{type}:{id}:{attribute}` — `user:123:session`, `order:456:status`. Consistent prefixes enable pattern scanning.
- Pipeline (`pipeline.exec()`) batches multiple commands in one TCP round-trip — use for independent reads/writes.
- In serverless (Vercel Edge, Cloudflare Workers), use Upstash Redis (`@upstash/redis`) — ioredis requires persistent TCP which serverless doesn't support.
