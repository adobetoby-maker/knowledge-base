# Failure: Memory Leaks in Node.js

## Overview

Node.js memory leaks cause gradual memory growth until the process crashes with OOM. Common sources: event listeners not removed, closures retaining large objects, `setInterval` not cleared, caches without eviction, and streams not consumed or closed. Serverless environments mask leaks until cold starts stop and a warm instance accumulates hours of garbage.

## Event Listener Leaks

```ts
// BAD — new listener on every request, never removed
app.get('/stream', (req, res) => {
  process.on('data', (chunk) => res.write(chunk))  // Accumulates every time /stream is called
})

// GOOD — keep a reference and remove on disconnect
app.get('/stream', (req, res) => {
  const handler = (chunk: Buffer) => res.write(chunk)
  process.on('data', handler)
  req.on('close', () => process.removeListener('data', handler))
})
```

Check for listener accumulation:

```ts
process.on('warning', (warning) => {
  if (warning.name === 'MaxListenersExceededWarning') {
    logger.error('Memory leak suspected: too many event listeners')
  }
})
```

## Unbounded Cache

```ts
// BAD — cache grows forever
const cache = new Map<string, ProcessedData>()

function processData(key: string, data: RawData): ProcessedData {
  if (cache.has(key)) return cache.get(key)!
  const result = expensiveProcess(data)
  cache.set(key, result)  // Never evicted
  return result
}

// GOOD — LRU cache with size limit
import { LRUCache } from 'lru-cache'

const cache = new LRUCache<string, ProcessedData>({
  max: 500,
  ttl: 1000 * 60 * 5,  // 5 minute TTL
})
```

## setInterval Not Cleared

```ts
// BAD — interval survives module scope, accumulates on hot reload
setInterval(() => refreshData(), 30_000)

// GOOD — store reference and clean up
const intervalId = setInterval(() => refreshData(), 30_000)

// In tests or graceful shutdown:
process.on('SIGTERM', () => clearInterval(intervalId))

// In Next.js API routes or hot-reload contexts:
export const cleanup = () => clearInterval(intervalId)
```

## Closure Retaining Large Objects

```ts
// BAD — closure captures the entire request object forever
function createHandler(req: Request) {
  const largePayload = req.body  // Could be MB of data

  return function handleEvent(event: string) {
    if (event === 'done') {
      logger.info(`Request ${largePayload.id} completed`)  // Closure holds largePayload in memory
    }
  }
}

// GOOD — extract only what you need
function createHandler(req: Request) {
  const requestId = req.body.id  // Only the ID, not the whole payload

  return function handleEvent(event: string) {
    if (event === 'done') {
      logger.info(`Request ${requestId} completed`)
    }
  }
}
```

## Stream Not Consumed

```ts
// BAD — response body not consumed leaves socket open
const res = await fetch(url)
if (!res.ok) return null  // Body not consumed → memory leak

// GOOD — always consume the body
const res = await fetch(url)
if (!res.ok) {
  await res.text()  // Consume and discard
  return null
}
return res.json()
```

## Detecting Leaks

```bash
# Monitor heap over time
node --inspect server.js
# → Open chrome://inspect, take heap snapshots 30min apart, compare retained objects

# CLI monitoring
node --max-old-space-size=512 server.js  # Force OOM faster to surface the leak
```

```ts
// Log heap usage in production to spot trends
setInterval(() => {
  const { heapUsed, heapTotal } = process.memoryUsage()
  logger.info({
    heapUsedMb: Math.round(heapUsed / 1024 / 1024),
    heapTotalMb: Math.round(heapTotal / 1024 / 1024),
  }, 'Memory usage')
}, 60_000)
```

## WeakMap for Object-Keyed Caches

```ts
// WeakMap lets keys be garbage collected when no other references exist
const processedCache = new WeakMap<Request, ProcessedData>()

function processRequest(req: Request): ProcessedData {
  if (processedCache.has(req)) return processedCache.get(req)!
  const result = process(req)
  processedCache.set(req, result)  // Automatically freed when req is GC'd
  return result
}
```

## Key Rules

- Every `emitter.on(event, handler)` needs a matching `emitter.off(event, handler)` in cleanup.
- Caches need a maximum size or TTL — unbounded Maps grow forever.
- `setInterval` returns an ID — always store it and clear on shutdown.
- Closures capture their entire scope — extract only the primitives/IDs needed, not whole objects.
- In Next.js: API routes run in the same Node.js process — singletons (Redis connections, caches) persist across requests and can leak if not managed.
