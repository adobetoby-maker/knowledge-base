# Failure: Cloudflare Worker Memory Limits

## Overview
Cloudflare Workers have a 128MB memory limit per isolate instance. Critically, Workers are not fully stateless between requests — the same isolate instance handles multiple requests in sequence before being recycled. Module-level variables persist between requests within the same isolate. This means in-memory caches, growing collections, and module-level state accumulate over the lifetime of an isolate, eventually hitting the 128MB limit or producing incorrect behavior from stale state.

## The Isolate Lifetime Misconception

The common mental model of "each request gets a fresh Worker instance" is wrong:

```
Request 1  → Isolate A (cold start, ~50ms overhead)
Request 2  → Isolate A (warm, ~1ms overhead) ← same isolate, module state persists
Request 3  → Isolate A (warm)
...
Request 47 → Isolate A (still warm)
Request 48 → Isolate B (new isolate, old isolate evicted)
```

Module-level variables survive from Request 1 through Request 47 in the same isolate.

## Problem 1: Growing In-Memory Cache

```typescript
// WRONG: cache grows indefinitely within an isolate
const cache = new Map<string, unknown>();

export default {
  async fetch(request: Request): Promise<Response> {
    const key = new URL(request.url).pathname;
    if (!cache.has(key)) {
      const data = await fetchFromDB(key);
      cache.set(key, data); // ← grows with every unique request path
    }
    return Response.json(cache.get(key));
  }
};
```

After thousands of requests, the cache Map holds thousands of entries, consuming megabytes. Eventually: 128MB limit → isolate terminated → cold start.

**Fix: Use Cloudflare KV for shared cache**
```typescript
// RIGHT: KV is shared across all isolates, bounded by TTL
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const key = new URL(request.url).pathname;
    const cached = await env.MY_KV.get(key, "json");
    if (cached) return Response.json(cached);
    
    const data = await fetchFromDB(key);
    await env.MY_KV.put(key, JSON.stringify(data), { expirationTtl: 300 }); // 5 min TTL
    return Response.json(data);
  }
};
```

## Problem 2: Module-Level State

```typescript
// WRONG: connection or client initialized per-request within module scope
let dbClient: DatabaseClient | null = null;

function getClient() {
  if (!dbClient) {
    dbClient = new DatabaseClient(/* env vars not available at module scope */);
  }
  return dbClient;
}
```

The problem: `env` (Cloudflare environment bindings) is only available inside the `fetch` handler, not at module initialization. Accessing `env.DATABASE_URL` at module level throws.

**Fix: Initialize with env inside the handler**
```typescript
// RIGHT: lazy initialization with env bindings
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const client = getOrCreateClient(env.DATABASE_URL); // env available here
    // ...
  }
};

// Cached per-isolate but initialized correctly with env
let client: DatabaseClient | null = null;
function getOrCreateClient(url: string) {
  if (!client) client = new DatabaseClient(url);
  return client;
}
```

## Problem 3: Read-Only Module-Level Constants (This IS Fine)

```typescript
// OK: read-only data set once, never modified
const COUNTRY_CODES = new Set(["US", "CA", "GB", "AU", "NZ"]);
const TAX_RATES = { US: 0.08, CA: 0.13 } as const;

// This does not grow between requests and is initialized once at module load
```

Module-level constants that are never mutated are beneficial: they avoid re-creating large data structures on every request. The distinction is mutable vs immutable.

## Monitoring Memory Usage

```typescript
// Log memory usage for monitoring
export default {
  async fetch(request: Request): Promise<Response> {
    // Check memory at the start of expensive operations
    // @ts-ignore: not in standard types
    const mem = process.memoryUsage?.() ?? { heapUsed: 0 };
    
    if (mem.heapUsed > 100 * 1024 * 1024) { // > 100MB
      console.warn("High memory usage", { heapUsed: mem.heapUsed });
    }
    
    // ...
  }
};
```

Use `wrangler tail` to stream real-time logs from production Workers and observe memory patterns.

## Key Rules
- Never use module-level `Map`, `Set`, or `Array` that grows with each request
- Use Cloudflare KV for any cache that needs to be shared or bounded by TTL
- Module-level constants (read-only, fixed size) are fine and beneficial for performance
- `env` bindings are only available inside `fetch`/`scheduled`/`queue` handlers — not at module scope
- `wrangler tail` for real-time debugging of production Workers
- Test with high request volumes in development: `wrk` or `hey` for load testing
- Cloudflare R2 for binary data, KV for small string/JSON data (< 25MB per value), Durable Objects for strongly consistent state
