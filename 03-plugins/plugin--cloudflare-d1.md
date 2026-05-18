# Cloudflare D1 (SQLite at the Edge)

## What D1 Is

D1 is Cloudflare's serverless SQLite database. It runs at the edge alongside Cloudflare Workers. It's NOT the same as Supabase — it's a SQLite database, not Postgres, and it has no built-in auth or RLS.

Use D1 when:
- Your app is deployed as a Cloudflare Worker (not Vercel)
- You need a database that co-locates with your compute
- The data model is simple (SQLite constraints apply)
- You don't need Postgres-specific features (jsonb, full-text search, triggers)

Do NOT use D1 as a replacement for Supabase in projects that need auth, RLS, or real-time.

## Setup

```bash
npm install @cloudflare/workers-types
wrangler d1 create my-database
```

```toml
# wrangler.toml
[[d1_databases]]
binding = "DB"
database_name = "my-database"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## Schema and Migrations

D1 uses SQLite syntax. Create migrations:

```bash
wrangler d1 migrations create my-database init-schema
```

```sql
-- migrations/0001_init-schema.sql
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),  -- UUID equivalent
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))         -- ISO string
);

CREATE INDEX IF NOT EXISTS items_status_idx ON items (status);
```

```bash
# Apply to local dev:
wrangler d1 migrations apply my-database --local

# Apply to production:
wrangler d1 migrations apply my-database
```

## Worker Handler with D1

```typescript
// src/worker.ts
export interface Env {
  DB: D1Database
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url)
    
    if (url.pathname === '/api/items' && request.method === 'GET') {
      const { results } = await env.DB.prepare(
        'SELECT * FROM items WHERE status = ? ORDER BY created_at DESC LIMIT 20'
      ).bind('active').all()
      
      return Response.json({ items: results })
    }
    
    return new Response('Not found', { status: 404 })
  }
}
```

## Parameterized Queries (Required)

Always use `?` placeholders — never string concatenation:

```typescript
// WRONG — SQL injection vulnerability:
const results = await env.DB.prepare(
  `SELECT * FROM items WHERE name = '${name}'`
).all()

// CORRECT — parameterized:
const results = await env.DB.prepare(
  'SELECT * FROM items WHERE name = ?'
).bind(name).all()

// Multiple params:
const result = await env.DB.prepare(
  'INSERT INTO items (id, name, status) VALUES (?, ?, ?)'
).bind(crypto.randomUUID(), name, 'active').run()
```

## Query Methods

```typescript
// .all() — returns all matching rows:
const { results } = await env.DB.prepare('SELECT * FROM items').all()
// results: Record<string, unknown>[]

// .first() — returns first row or null:
const item = await env.DB.prepare('SELECT * FROM items WHERE id = ?').bind(id).first()

// .run() — for INSERT/UPDATE/DELETE:
const { success, meta } = await env.DB.prepare(
  'UPDATE items SET status = ? WHERE id = ?'
).bind('inactive', id).run()
// meta.changes: number of rows affected
```

## TypeScript Types

```typescript
interface Item {
  id: string
  name: string
  status: string
  created_at: string
}

// Cast after query:
const { results } = await env.DB.prepare('SELECT * FROM items').all<Item>()
// results: Item[]
```

## D1 vs KV vs R2

| Store | Use for |
|---|---|
| D1 (SQLite) | Structured relational data, queries, reporting |
| KV | Key-value lookups, config, feature flags, rate limits |
| R2 | Binary files, images, documents (S3-compatible) |

Don't use D1 for storing blobs or large JSON documents — use KV or R2 instead.
