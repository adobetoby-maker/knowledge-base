# Plugin: Redis (ioredis)

## Overview

Redis is an in-memory data store used for: caching, session storage, rate limiting, pub/sub messaging, job queues, and distributed locks. `ioredis` is the recommended Node.js client — full-featured, TypeScript support, connection pooling.

## Install

```bash
npm install ioredis
```

## Connection

```ts
// lib/redis.ts
import Redis from 'ioredis'

// Singleton pattern — never create multiple connections
let redis: Redis | null = null

export function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(process.env.REDIS_URL!, {
      maxRetriesPerRequest: 3,
      lazyConnect: false,
      retryStrategy: (times) => {
        if (times > 5) return null
        return Math.min(times * 200, 2000)
      },
    })
    redis.on('error', (err) => console.error('Redis error:', err))
  }
  return redis
}
```

For Cloudflare Workers / serverless: use Upstash Redis (HTTP-based, no persistent connection).

## Core Operations

```ts
const redis = getRedis()

// String (most common — use for caching)
await redis.set('user:123', JSON.stringify(userData))
await redis.set('user:123', JSON.stringify(userData), 'EX', 3600)  // Expires in 1hr
const raw = await redis.get('user:123')
const user = raw ? JSON.parse(raw) : null

// Delete
await redis.del('user:123')

// Check existence
const exists = await redis.exists('user:123')  // 1 or 0

// Increment (atomic)
await redis.incr('page:views:home')
await redis.incrby('api:calls', 5)

// TTL management
await redis.expire('user:123', 3600)
const ttl = await redis.ttl('user:123')  // Remaining seconds, -1 = no TTL
```

## Caching Pattern

```ts
async function getCached<T>(
  key: string,
  ttlSeconds: number,
  fetch: () => Promise<T>,
): Promise<T> {
  const redis = getRedis()
  const cached = await redis.get(key)
  if (cached) return JSON.parse(cached) as T

  const fresh = await fetch()
  await redis.set(key, JSON.stringify(fresh), 'EX', ttlSeconds)
  return fresh
}

// Usage
const user = await getCached(
  `user:${userId}`,
  300,  // 5 minutes
  () => db.query.users.findFirst({ where: eq(users.id, userId) }),
)
```

## Rate Limiting

```ts
async function checkRateLimit(
  identifier: string,
  limit: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; remaining: number; resetIn: number }> {
  const redis = getRedis()
  const key = `ratelimit:${identifier}:${Math.floor(Date.now() / (windowSeconds * 1000))}`

  const count = await redis.incr(key)
  if (count === 1) {
    await redis.expire(key, windowSeconds)
  }

  const ttl = await redis.ttl(key)

  return {
    allowed: count <= limit,
    remaining: Math.max(0, limit - count),
    resetIn: ttl,
  }
}
```

## Distributed Lock

Prevent concurrent execution of the same operation:

```ts
async function withLock<T>(
  key: string,
  ttlSeconds: number,
  fn: () => Promise<T>,
): Promise<T | null> {
  const redis = getRedis()
  const lockKey = `lock:${key}`
  const lockValue = crypto.randomUUID()

  // SET key value NX EX seconds — atomic set-if-not-exists
  const acquired = await redis.set(lockKey, lockValue, 'NX', 'EX', ttlSeconds)
  if (!acquired) return null

  try {
    return await fn()
  } finally {
    // Release lock only if we still own it
    // Use a Lua script for atomic check-and-delete (see Redis docs for redlock pattern)
    const current = await redis.get(lockKey)
    if (current === lockValue) {
      await redis.del(lockKey)
    }
  }
}
```

Note: The check-and-delete above has a small race condition. For production distributed locks, use the `redlock` npm package which implements the correct Redlock algorithm.

## Pub/Sub

```ts
// Publisher
const publisher = getRedis()
await publisher.publish('orders:new', JSON.stringify({ orderId: '123' }))

// Subscriber (needs separate connection)
const subscriber = new Redis(process.env.REDIS_URL!)
await subscriber.subscribe('orders:new')

subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message)
  handleNewOrder(event)
})
```

Pub/Sub requires a dedicated connection for the subscriber — it can't be used for regular commands after subscribing.

## Hash (Structured Object)

```ts
// Store object fields separately (allows partial updates)
await redis.hset('user:123', {
  name: 'Jane Doe',
  email: 'jane@example.com',
  plan: 'pro',
})

const user = await redis.hgetall('user:123')
const plan = await redis.hget('user:123', 'plan')

// Update single field without serializing full object
await redis.hset('user:123', 'plan', 'enterprise')
```

## Serverless / Cloudflare Workers

ioredis requires persistent TCP connections — not compatible with serverless. Use Upstash:

```ts
import { Redis } from '@upstash/redis'

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
})

// Same get/set/del API — works in edge runtimes
const value = await redis.get('key')
```

Upstash REST API is compatible with Cloudflare Workers, Vercel Edge, and any HTTP-capable runtime.
