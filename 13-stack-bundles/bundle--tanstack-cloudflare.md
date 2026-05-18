# Stack Bundle: TanStack Start + Cloudflare Workers

## Overview

TanStack Start (React Router v7 + Vite) deployed on Cloudflare Workers. This is the stack for edge-first React apps: all rendering at the edge, zero cold starts, global distribution. Key differences from Next.js: no Node.js APIs, D1/KV/R2 instead of Supabase, different server function model.

## Project Structure

```
src/
  routes/
    __root.tsx           # Root layout + providers
    index.tsx            # / route
    _auth/               # Auth layout group
      login.tsx
    _app/                # App layout group
      layout.tsx
      dashboard.tsx
  server/
    db/
      schema.ts          # Drizzle schema for D1
      index.ts           # Drizzle D1 instance
    auth.ts              # Auth helpers
  functions/
    api.users.ts         # Server functions (TanStack)
    api.auth.ts
wrangler.toml            # Cloudflare config
```

## Cloudflare Bindings Access

```ts
// In server functions, access bindings via getRequestContext()
import { getRequestContext } from '@cloudflare/workers-sdk/runtime'

export const getUserFn = createServerFn('GET', async () => {
  const { env } = getRequestContext()
  // env.DB       — D1 Database
  // env.KV       — KV Namespace
  // env.R2       — R2 Bucket
  // env.SECRETS  — Service bindings
})
```

## D1 Database with Drizzle

```ts
// server/db/schema.ts
import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core'

export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull(),
})

// server/db/index.ts
import { drizzle } from 'drizzle-orm/d1'
import { getRequestContext } from '@cloudflare/workers-sdk/runtime'

export function getDb() {
  const { env } = getRequestContext()
  return drizzle(env.DB)
}
```

## Server Functions (TanStack)

```ts
// functions/api.users.ts
import { createServerFn } from '@tanstack/start'
import { z } from 'zod'
import { getDb } from '../server/db'
import { users } from '../server/db/schema'

export const getUser = createServerFn('GET', async (userId: string) => {
  const db = getDb()
  return db.select().from(users).where(eq(users.id, userId)).get()
})

export const createUser = createServerFn('POST',
  async (input: { email: string }) => {
    const validated = z.object({ email: z.string().email() }).parse(input)
    const db = getDb()
    const id = crypto.randomUUID()
    await db.insert(users).values({ id, email: validated.email, createdAt: new Date() })
    return { id }
  }
)
```

## KV Session Storage

```ts
// Store session in KV (edge-available)
export async function createSession(userId: string): Promise<string> {
  const { env } = getRequestContext()
  const sessionId = crypto.randomUUID()
  await env.KV.put(
    `session:${sessionId}`,
    JSON.stringify({ userId, createdAt: Date.now() }),
    { expirationTtl: 7 * 24 * 60 * 60 }  // 7 days
  )
  return sessionId
}

export async function getSession(sessionId: string): Promise<{ userId: string } | null> {
  const { env } = getRequestContext()
  const data = await env.KV.get(`session:${sessionId}`, 'json')
  return data as { userId: string } | null
}
```

## R2 File Storage

```ts
// Upload to R2 (Cloudflare's S3-compatible storage)
export const uploadFileFn = createServerFn('POST', async (input: { key: string; type: string }) => {
  const { env } = getRequestContext()

  // Generate presigned URL for direct upload from browser
  // R2 supports presigned URLs via S3 compatibility
  const url = await env.R2.createMultipartUpload(input.key)
  return { uploadId: url.uploadId, key: input.key }
})
```

## wrangler.toml

```toml
name = "my-app"
main = ".output/worker/index.mjs"
compatibility_date = "2024-12-01"
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "my-app-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

[[kv_namespaces]]
binding = "KV"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

[[r2_buckets]]
binding = "R2"
bucket_name = "my-app-assets"

[vars]
ENVIRONMENT = "production"
```

## Limitations vs Node.js

```
❌ No file system access (readFileSync, writeFileSync)
❌ No child_process (exec, spawn)
❌ Limited net module
❌ 10ms CPU time limit per request (not wall clock)
❌ No long-running processes (use Durable Objects for that)
✓ All standard Web APIs (fetch, crypto, TextEncoder, URL)
✓ V8 isolates — zero cold starts
✓ 128MB memory limit per request
```

The `nodejs_compat` flag enables many Node.js built-ins (Buffer, path, crypto). Check the Cloudflare docs for the current compatibility list.

## Key Rules

- Access bindings only inside server functions via `getRequestContext()` — bindings are not available in client code.
- D1 is SQLite — no `RETURNING` in older versions, no `NOW()` function (use `strftime`), no native JSON column type.
- KV has eventual consistency — not suitable for transactional data, perfect for sessions and config.
- The 10ms CPU limit is soft but real — heavy computation (image processing, PDF generation) should be offloaded to a Worker queue or Durable Object.
- `compatibility_flags = ["nodejs_compat"]` is required for any npm package that uses Node.js built-ins (most packages do).
