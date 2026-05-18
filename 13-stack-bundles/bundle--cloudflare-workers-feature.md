# Stack Bundle: Cloudflare Workers Feature Development

**Use when:** Building or debugging a Cloudflare Worker. This bundle covers Workers architecture, D1/KV/R2 patterns, common failures, and deployment.
**Replaces:** plugin--cloudflare.md + skill--cloudflare-workers-expert.md + failure--cloudflare-nodejs-apis.md

---

## Core Constraint — V8 Isolate Environment

Workers run in V8 isolates — NOT Node.js. Missing APIs:
```
NO: fs, path, process.env, require()
NO: crypto (Node version), Buffer (Node version)
NO: setTimeout with >30s, setInterval

USE: env parameter, globalThis.crypto, Web Streams API
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
    if (url.pathname.startsWith('/api/')) return handleApi(request, env, ctx)
    return new Response('Not found', { status: 404 })
  },
  
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(runBackgroundJob(env))
  }
}
```

## D1 Database
```typescript
// SELECT
const { results } = await env.DB.prepare(
  'SELECT * FROM users WHERE id = ?'
).bind(userId).all()

// INSERT
await env.DB.prepare(
  'INSERT INTO items (id, name, user_id) VALUES (?, ?, ?)'
).bind(newId, name, userId).run()

// Batch (atomic)
await env.DB.batch([
  env.DB.prepare('DELETE FROM sessions WHERE expires_at < ?').bind(now),
  env.DB.prepare('INSERT INTO audit_log (action) VALUES (?)').bind('cleanup')
])
```

## KV Store
```typescript
// Read (eventually consistent)
const value = await env.KV.get('key')
const json = await env.KV.get<MyType>('key', { type: 'json' })

// Write with TTL
await env.KV.put('key', JSON.stringify(data), { expirationTtl: 3600 })

// List keys with prefix
const list = await env.KV.list({ prefix: 'user:' })
```
IMPORTANT: KV is eventually consistent. Do not read immediately after write.

## R2 Storage
```typescript
// Upload
await env.BUCKET.put('images/photo.jpg', request.body, {
  httpMetadata: { contentType: 'image/jpeg' }
})

// Download
const object = await env.BUCKET.get('images/photo.jpg')
if (!object) return new Response('Not found', { status: 404 })
return new Response(object.body, {
  headers: { 'Content-Type': object.httpMetadata?.contentType ?? 'application/octet-stream' }
})
```

## wrangler.toml
```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-09-23"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

[[kv_namespaces]]
binding = "KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

[[r2_buckets]]
binding = "BUCKET"
bucket_name = "my-bucket"

[[crons]]
crons = ["0 */6 * * *"]
```

## Wrangler CLI
```
wrangler dev                     — local development
wrangler deploy                  — deploy to production
wrangler secret put MY_SECRET    — add a secret
wrangler d1 execute my-db --file=./migrations/0001_init.sql
```

## Common Failures

### Node.js module not available
```
Error: No such module "node:fs"
```
Cloudflare Workers do NOT support Node.js built-ins. Use Web APIs.

### process is not defined
Use `env` parameter from the Worker handler, not `process.env`.

### CPU time exceeded
Free tier: 10ms CPU. Paid: 30s. Move heavy computation to D1 or Queues.

### KV read returns stale value
Expected — eventual consistency. Do not rely on same-request read-after-write.
