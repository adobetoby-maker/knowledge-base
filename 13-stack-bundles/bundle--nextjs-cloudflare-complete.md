# Bundle: Next.js + Cloudflare Complete

## Context

Complete reference for deploying Next.js 15+ to Cloudflare Pages/Workers using `@opennextjs/cloudflare`. This stack runs entirely in the Cloudflare network — no Node.js server, no Vercel.

## Architecture Overview

```
Browser → Cloudflare Pages (Edge) → Workers (SSR) → D1 / R2 / KV
                                   ↓
                               Supabase (external Postgres)
```

`@opennextjs/cloudflare` adapts Next.js App Router to run on Cloudflare Workers. Server Components execute at the edge. Static assets go to Pages CDN.

## Setup

```bash
npm create cloudflare@latest -- --framework next
# Or add to existing:
npm install @opennextjs/cloudflare wrangler
```

```ts
// next.config.ts
import type { NextConfig } from 'next'

const config: NextConfig = {
  // No output: 'export' — CF adapter handles this
}

export default config
```

```ts
// wrangler.jsonc
{
  "name": "my-nextjs-app",
  "compatibility_date": "2025-01-01",
  "compatibility_flags": ["nodejs_compat"],
  "pages_build_output_dir": ".vercel/output/static",
  "d1_databases": [
    { "binding": "DB", "database_name": "my-db", "database_id": "<id>" }
  ],
  "kv_namespaces": [
    { "binding": "KV", "id": "<id>" }
  ],
  "r2_buckets": [
    { "binding": "BUCKET", "bucket_name": "my-bucket" }
  ],
  "vars": {
    "NEXT_PUBLIC_APP_URL": "https://myapp.pages.dev"
  }
}
```

## Accessing Bindings in Server Components

Cloudflare Workers expose bindings via `getCloudflareContext()`:

```ts
// lib/cloudflare.ts
import { getCloudflareContext } from '@opennextjs/cloudflare'

export function getD1() {
  const { env } = getCloudflareContext()
  return env.DB
}

export function getKV() {
  const { env } = getCloudflareContext()
  return env.KV
}
```

```ts
// In a Server Component or Route Handler
import { getD1 } from '@/lib/cloudflare'

export default async function Page() {
  const db = getD1()
  const { results } = await db.prepare('SELECT * FROM users LIMIT 10').all()
  return <div>{results.length} users</div>
}
```

## Drizzle ORM with D1

```ts
// db/index.ts
import { drizzle } from 'drizzle-orm/d1'
import { getCloudflareContext } from '@opennextjs/cloudflare'

export function getDb() {
  const { env } = getCloudflareContext()
  return drizzle(env.DB)
}
```

D1 uses SQLite — use `sqliteTable` from `drizzle-orm/sqlite-core`, not `pgTable`.

## KV for Caching

```ts
import { getKV } from '@/lib/cloudflare'

async function getCachedData<T>(key: string, ttl: number, fetcher: () => Promise<T>): Promise<T> {
  const kv = getKV()

  const cached = await kv.get(key, 'json')
  if (cached) return cached as T

  const fresh = await fetcher()
  await kv.put(key, JSON.stringify(fresh), { expirationTtl: ttl })
  return fresh
}

// Usage
const posts = await getCachedData('posts:all', 3600, fetchPosts)
```

## R2 Storage

```ts
import { getCloudflareContext } from '@opennextjs/cloudflare'

// Route Handler for file upload
export async function POST(req: Request) {
  const { env } = getCloudflareContext()
  const formData = await req.formData()
  const file = formData.get('file') as File

  const key = `uploads/${crypto.randomUUID()}-${file.name}`
  await env.BUCKET.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
  })

  return Response.json({ key, url: `${process.env.R2_PUBLIC_URL}/${key}` })
}
```

## What Doesn't Work in CF Workers

- **Node.js built-ins**: `fs`, `path`, `child_process`, `crypto` (use Web Crypto API instead)
- **Long-running processes**: Workers have a 50ms CPU time limit
- **Sharp**: Not available — use Cloudflare Images API or resize at upload time
- **WebSockets with long connections**: Use CF Durable Objects instead
- **Any npm package using Node-only APIs**: Check with `npx wrangler dev` before deploying

## Environment Variables

```bash
# Local development — wrangler.jsonc [vars] section for non-secrets
# Secrets — NEVER in wrangler.jsonc
npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
npx wrangler secret put ANTHROPIC_API_KEY
```

`NEXT_PUBLIC_` prefixed vars work the same way — put them in `wrangler.jsonc` vars.

## Build and Deploy

```bash
# Development
npx wrangler pages dev

# Build and preview
npm run build
npx wrangler pages dev .vercel/output/static

# Deploy
npx wrangler pages deploy .vercel/output/static

# Or CI
npx wrangler pages deploy .vercel/output/static --branch main
```

## Middleware Compatibility

Next.js Middleware runs as a Cloudflare Worker. Supabase SSR middleware works but requires the `@supabase/ssr` package and proper cookie handling:

```ts
// middleware.ts — same as standard Supabase SSR middleware
// No changes needed for CF — the adapter handles runtime differences
```

## Performance Characteristics

- Cold start: 0ms (Workers are pre-warmed by Cloudflare)
- Request execution: 50ms CPU limit (wall clock can be longer for I/O)
- D1 latency: ~3-5ms (same-region) to ~30ms (cross-region)
- KV read: ~1ms (edge cache hit) to ~10ms (from storage)
- R2: ~50-100ms for first byte on large objects
