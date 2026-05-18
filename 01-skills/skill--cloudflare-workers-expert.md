# Skill: cloudflare-workers-expert

**Trigger:** Writing Cloudflare Workers, Pages Functions, D1 queries, KV operations, R2 storage, Durable Objects, or deploying via Wrangler.
**Invoke:** `/cloudflare-workers-expert`
**Returns:** Worker patterns, bindings config, D1 SQL, KV patterns, R2 operations, cron triggers, Wrangler commands.

## When to Invoke
- Writing a new Cloudflare Worker
- Setting up D1 database queries
- KV store read/write patterns
- R2 file upload/download
- Cron trigger setup
- Debugging "not available in Workers" errors
- Configuring wrangler.toml bindings

## Core Constraint — V8 Isolate Environment
Workers do NOT have Node.js. No `fs`, no `path`, no `crypto` (use `globalThis.crypto`), no `process.env` (use `env` param).

```typescript
// WRONG
import fs from 'fs'
process.env.MY_SECRET

// RIGHT
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const secret = env.MY_SECRET  // from wrangler.toml bindings
  }
}
```

## Worker Shape
```typescript
export interface Env {
  DB: D1Database
  KV: KVNamespace
  BUCKET: R2Bucket
  MY_SECRET: string
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url)
    
    if (url.pathname === '/api/data') {
      return handleData(request, env)
    }
    
    return new Response('Not found', { status: 404 })
  },
  
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    // cron trigger
    await runScheduledJob(env)
  }
}
```

## D1 Database
```typescript
// Query
const { results } = await env.DB.prepare(
  'SELECT * FROM users WHERE id = ?'
).bind(userId).all()

// Insert
await env.DB.prepare(
  'INSERT INTO users (id, name) VALUES (?, ?)'
).bind(newId, name).run()

// Batch
await env.DB.batch([
  env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(Date.now()),
  env.DB.prepare('INSERT INTO logs (msg) VALUES (?)').bind('cleaned')
])
```

## KV Store
```typescript
// Read (may be stale — eventual consistency)
const value = await env.KV.get('key')
const json = await env.KV.get('key', { type: 'json' })

// Write with TTL
await env.KV.put('key', JSON.stringify(data), { expirationTtl: 3600 })

// Delete
await env.KV.delete('key')
```
KV is eventually consistent — don't rely on read-after-write in the same Worker run.

## R2 Storage
```typescript
// Upload
await env.BUCKET.put('path/file.jpg', request.body, {
  httpMetadata: { contentType: 'image/jpeg' }
})

// Download
const object = await env.BUCKET.get('path/file.jpg')
if (!object) return new Response('Not found', { status: 404 })
return new Response(object.body, {
  headers: { 'Content-Type': object.httpMetadata?.contentType ?? 'application/octet-stream' }
})
```

## wrangler.toml
```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

[[kv_namespaces]]
binding = "KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"

[vars]
ENVIRONMENT = "production"

[[crons]]
crons = ["0 * * * *"]  # every hour
```

## What Skill Returns
Advanced routing patterns, middleware composition, streaming responses, WebSocket handling, Durable Objects, queue consumers, and deployment strategies.
