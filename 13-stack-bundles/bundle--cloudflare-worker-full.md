# Stack Bundle: Cloudflare Worker — Full Setup

## Project Structure

```
worker/
  src/
    index.ts          ← Entry point with fetch + scheduled handlers
    routes/
      api.ts          ← Route handler dispatch
    lib/
      auth.ts         ← Auth utilities
      db.ts           ← D1 query helpers
  wrangler.toml       ← Worker configuration
  package.json
  tsconfig.json
```

## Entry Point Pattern

```typescript
// src/index.ts
interface Env {
  DB: D1Database
  KV: KVNamespace
  R2: R2Bucket
  CRON_SECRET: string
  API_KEY: string
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url)
    
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        }
      })
    }
    
    try {
      return await handleFetch(request, env, ctx)
    } catch (error) {
      console.error('Unhandled error:', error)
      return Response.json({ error: 'Internal server error' }, { status: 500 })
    }
  },
  
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(runScheduledWork(env))
  }
}
```

## wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2025-01-01"

[[d1_databases]]
binding = "DB"
database_name = "my-db"
database_id = "your-database-id"

[[kv_namespaces]]
binding = "KV"
id = "your-kv-namespace-id"

[[r2_buckets]]
binding = "R2"
bucket_name = "my-bucket"

[vars]
ENVIRONMENT = "production"

[[triggers]]
crons = ["0 */6 * * *"]
```

Secrets (not in wrangler.toml):
```bash
wrangler secret put API_KEY
wrangler secret put CRON_SECRET
```

## D1 Helper Pattern

```typescript
// src/lib/db.ts
export async function queryOne<T>(db: D1Database, sql: string, params: unknown[] = []): Promise<T | null> {
  const result = await db.prepare(sql).bind(...params).first<T>()
  return result ?? null
}

export async function queryMany<T>(db: D1Database, sql: string, params: unknown[] = []): Promise<T[]> {
  const { results } = await db.prepare(sql).bind(...params).all<T>()
  return results
}

export async function batchExecute(db: D1Database, statements: D1PreparedStatement[]): Promise<void> {
  await db.batch(statements)
}
```

## KV Session Pattern

```typescript
interface Session {
  userId: string
  email: string
  expiresAt: string
}

export async function createSession(kv: KVNamespace, userId: string, email: string): Promise<string> {
  const token = crypto.randomUUID()
  const session: Session = {
    userId,
    email,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  }
  
  await kv.put(`session:${token}`, JSON.stringify(session), {
    expirationTtl: 7 * 24 * 60 * 60
  })
  
  return token
}

export async function getSession(kv: KVNamespace, token: string): Promise<Session | null> {
  const data = await kv.get(`session:${token}`, 'json') as Session | null
  if (!data || new Date(data.expiresAt) < new Date()) {
    if (data) await kv.delete(`session:${token}`)
    return null
  }
  return data
}
```

## Auth Middleware Helper

```typescript
export async function requireAuth(request: Request, env: Env): Promise<Session | Response> {
  const authHeader = request.headers.get('Authorization')
  const token = authHeader?.replace('Bearer ', '')
  
  if (!token) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  
  const session = await getSession(env.KV, token)
  if (!session) return Response.json({ error: 'Session expired' }, { status: 401 })
  
  return session
}
```

## Critical Rules

1. **No process.env** — use `env.MY_VAR` bindings, not `process.env`
2. **No Node.js builtins** — use Web APIs (crypto.subtle, ReadableStream, ArrayBuffer)
3. **No global state** — module-level variables are not guaranteed to persist
4. **waitUntil for background work** — otherwise work is killed when response sends
5. **D1 is not ACID** across tables — use batch for atomicity within supported limits
6. **KV is eventually consistent** — don't use for rate limiting or strong consistency needs

## Deploy and Debug

```bash
wrangler dev --local        # local development with bindings
wrangler deploy             # deploy to production
wrangler tail               # stream live production logs
```
