# Cloudflare Workers Patterns

## Worker Anatomy

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url)
    
    if (url.pathname === '/api/health') {
      return Response.json({ ok: true })
    }
    
    return new Response('Not Found', { status: 404 })
  }
}

// Type the env bindings
interface Env {
  DB: D1Database
  KV: KVNamespace
  R2: R2Bucket
  QUEUE: Queue
  SECRET_KEY: string
}
```

## KV Patterns

```typescript
// Write
await env.KV.put('session:user123', JSON.stringify(sessionData), {
  expirationTtl: 3600  // seconds
})

// Read
const raw = await env.KV.get('session:user123')
const session = raw ? JSON.parse(raw) : null

// Delete
await env.KV.delete('session:user123')

// List (prefix scan)
const list = await env.KV.list({ prefix: 'session:' })
const keys = list.keys.map(k => k.name)
```

KV is eventually consistent — reads after writes may be stale for up to 60 seconds globally. For strong consistency requirements, use D1.

## D1 Patterns

```typescript
// Simple query
const result = await env.DB
  .prepare('SELECT * FROM users WHERE id = ?')
  .bind(userId)
  .first()

// Multiple rows
const { results } = await env.DB
  .prepare('SELECT * FROM invoices WHERE user_id = ? ORDER BY created_at DESC LIMIT ?')
  .bind(userId, limit)
  .all()

// Insert with returning
const newRecord = await env.DB
  .prepare('INSERT INTO sessions (user_id, token) VALUES (?, ?) RETURNING *')
  .bind(userId, token)
  .first()

// Batch (atomic)
await env.DB.batch([
  env.DB.prepare('UPDATE accounts SET balance = balance - ? WHERE id = ?').bind(amount, fromId),
  env.DB.prepare('UPDATE accounts SET balance = balance + ? WHERE id = ?').bind(amount, toId),
])
```

D1 batch operations are atomic within the batch. Use batch for any multi-statement operation that must succeed or fail together.

## R2 Patterns

```typescript
// Upload
await env.R2.put('images/product-123.jpg', imageBuffer, {
  httpMetadata: { contentType: 'image/jpeg' }
})

// Download
const object = await env.R2.get('images/product-123.jpg')
if (!object) return new Response('Not Found', { status: 404 })

return new Response(object.body, {
  headers: {
    'content-type': object.httpMetadata?.contentType ?? 'application/octet-stream',
    'cache-control': 'public, max-age=31536000'
  }
})

// Delete
await env.R2.delete('images/product-123.jpg')

// List
const list = await env.R2.list({ prefix: 'images/', limit: 50 })
```

## Cron Triggers

```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    // Runs on schedule defined in wrangler.toml
    await processScheduledWork(env)
  }
}
```

In wrangler.toml:
```toml
[[triggers]]
crons = ["0 9 * * 1"]  # Monday 9am UTC
```

## CORS Pattern

```typescript
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS })
    }
    
    const response = await handleRequest(request, env)
    
    return new Response(response.body, {
      status: response.status,
      headers: { ...Object.fromEntries(response.headers), ...CORS_HEADERS }
    })
  }
}
```

For production: replace `'*'` with your actual origin. Wildcard CORS exposes APIs to any website.

## waitUntil — Background Work

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Start background work without blocking the response
    ctx.waitUntil(logAnalytics(request, env))
    
    // Return response immediately
    return handleRequest(request, env)
  }
}
```

`waitUntil` is critical — without it, the runtime terminates your Worker when the response is sent, killing in-flight async operations.

## Common Pitfalls

**Global state doesn't persist between requests.** Variables declared at module level may or may not persist between invocations depending on Worker instance reuse. Never rely on in-memory state for data that must be reliable — use KV or D1.

**No Node.js builtins.** Workers run on the V8 runtime, not Node.js. `fs`, `path`, `crypto` (Node), `Buffer` are not available. Use Web APIs: `crypto.subtle`, `ReadableStream`, `Blob`, `ArrayBuffer`.

**CPU time limit**: Workers have a 10-50ms CPU time limit (not wall time). Heavy computation will hit this limit. Offload to a Queue or use Durable Objects for longer-running work.

**Request size limit**: 100MB request body (Unbound workers: no limit with streaming).
