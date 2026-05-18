# Stack Bundle: Remix on Cloudflare Workers

## Overview
Remix on Cloudflare Workers runs your full-stack app at the edge with no cold starts, using Cloudflare's
V8 isolates instead of Node.js. The fundamental constraint is that the Cloudflare Workers runtime does
not implement all Node.js APIs, so every dependency must be Workers-compatible or polyfilled.

## Implementation

### Wrangler Config (wrangler.toml)
```toml
name = "my-remix-app"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]   # enables subset of Node.js APIs

[vars]
ENVIRONMENT = "production"

[[d1_databases]]
binding = "DB"          # available as env.DB in loaders/actions
database_name = "my-app-db"
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

[[r2_buckets]]
binding = "BUCKET"      # available as env.BUCKET
bucket_name = "my-uploads"

[[kv_namespaces]]
binding = "SESSION_KV"  # available as env.SESSION_KV
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

### getLoadContext — Passing Bindings to Remix
```ts
// worker.ts (entry point)
import { createRequestHandler } from '@remix-run/cloudflare';
import * as build from './build/index.js';

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    const handler = createRequestHandler(build, process.env.NODE_ENV);

    return handler(request, {
      // LoadContext — available as context in all loaders/actions
      env,
      ctx,
    });
  },
};
```
```ts
// In a loader
export async function loader({ context }: LoaderFunctionArgs) {
  const { env } = context as { env: Env };
  // Use D1, R2, KV through env bindings — NOT through process.env
  const result = await env.DB.prepare('SELECT * FROM users LIMIT 10').all();
  return json(result.results);
}
```

### D1 (SQLite at the Edge)
```ts
// Query
const { results } = await env.DB.prepare(
  'SELECT * FROM posts WHERE user_id = ?'
).bind(userId).all();

// Mutation
await env.DB.prepare(
  'INSERT INTO posts (title, body, user_id) VALUES (?, ?, ?)'
).bind(title, body, userId).run();

// Batch (atomic)
await env.DB.batch([
  env.DB.prepare('UPDATE users SET post_count = post_count + 1 WHERE id = ?').bind(userId),
  env.DB.prepare('INSERT INTO posts ...').bind(...args),
]);
```
D1 uses SQLite semantics. No stored procedures, no JSON column functions older than SQLite 3.38.
Migrations via `wrangler d1 migrations apply`.

### R2 (Object Storage)
```ts
// Upload
await env.BUCKET.put(key, body, {
  httpMetadata: { contentType: 'image/png' },
});

// Retrieve
const object = await env.BUCKET.get(key);
if (!object) throw new Response('Not Found', { status: 404 });
return new Response(object.body, {
  headers: { 'Content-Type': object.httpMetadata?.contentType ?? 'application/octet-stream' },
});
```

### KV (Session / Cache)
```ts
// Write (eventual consistency — may take 60s to propagate globally)
await env.SESSION_KV.put(sessionId, JSON.stringify(sessionData), {
  expirationTtl: 86400,  // seconds
});

// Read
const raw = await env.SESSION_KV.get(sessionId);
const session = raw ? JSON.parse(raw) : null;
```
KV is eventually consistent — not suitable for operations that require read-after-write guarantees.
Use D1 or Durable Objects for strong consistency.

### No Node.js APIs in Cloudflare Runtime
```ts
// ✗ WILL CRASH in Workers:
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';     // unless nodejs_compat flag enables it

// ✓ USE INSTEAD:
const hash = await crypto.subtle.digest('SHA-256', data);  // Web Crypto API
const randomId = crypto.randomUUID();                        // Web Crypto — always available
```
If a dependency uses `Buffer`, `process`, or `EventEmitter`, it may work with
`nodejs_compat` flag. If it uses `fs`, `net`, or `child_process`, it will never work.

## Key Rules
- All environment secrets must be in `wrangler.toml` bindings or Cloudflare dashboard secrets — never in code
- Use `nodejs_compat` compatibility flag to unlock Buffer, process.env, and Node-style streams
- D1 is SQLite — no UUID primary keys via database function, generate them in JS (`crypto.randomUUID()`)
- KV is for caching and sessions only — never for data that requires strong consistency
- R2 has no CDN by default — put a Cloudflare cache rule or Workers cache API in front for public assets
- `wrangler dev` runs locally but simulates the Workers environment; some differences exist vs production
- Remix loaders run on every request — implement caching explicitly using `Cache-Control` headers or KV
