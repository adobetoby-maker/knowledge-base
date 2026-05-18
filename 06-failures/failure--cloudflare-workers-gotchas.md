# Cloudflare Workers — Gotchas and Failure Modes

## Module System: ESM Required

Cloudflare Workers require ES Modules syntax. CommonJS (`require()`, `module.exports`) does not work.

```typescript
// Wrong
const { createClient } = require('@supabase/supabase-js')
module.exports = { handler }

// Right
import { createClient } from '@supabase/supabase-js'
export default { fetch: handler }
```

If a dependency only ships CommonJS, use a bundler (esbuild via Wrangler) to transform it.

## No process.env — Use env Bindings

```typescript
// Wrong — process.env doesn't exist in Workers
const key = process.env.API_KEY

// Right — env is passed to fetch handler
export default {
  async fetch(req: Request, env: Env) {
    const key = env.API_KEY  // defined as secret in wrangler.toml / dashboard
  }
}
```

Environment variables in Workers are either secrets (encrypted, for sensitive values) or vars (plaintext). Both are accessed via the `env` parameter.

## KV is Eventually Consistent

KV reads after writes can be stale for up to 60 seconds globally. Do not use KV for:
- Rate limiting (use Durable Objects or D1)
- Session validation where you need strong consistency
- Any pattern where you write and immediately read back the same key in different requests

Use KV for: caching, user preferences, configuration that changes infrequently.

## No Shared Memory Between Invocations

Module-level variables may persist across requests in the same Worker instance (a V8 isolate), but this is not guaranteed. A new isolate can be created at any time. Never rely on module-level state for correctness:

```typescript
// Dangerous — may or may not persist
let requestCount = 0
export default {
  async fetch() {
    requestCount++  // this is not reliable
  }
}

// Correct — use KV for persistence
export default {
  async fetch(req: Request, env: Env) {
    const count = Number(await env.KV.get('request_count') ?? '0')
    await env.KV.put('request_count', String(count + 1))
  }
}
```

## D1 Prepared Statement Binding

Parameters must be bound positionally with `?` placeholders. Named parameters (`:name`) are not supported.

```typescript
// Wrong
.prepare('SELECT * FROM users WHERE id = :id').bind({ id: userId })

// Right
.prepare('SELECT * FROM users WHERE id = ?').bind(userId)
```

## CPU Time vs Wall Time

Workers have a CPU time limit (default 10ms on Bundled, 50ms CPU time on Unbound). Wall time can be longer — network I/O doesn't count against CPU time.

A Worker that does `await fetch(url)` and waits 500ms gets billed for wall time but only 5ms of CPU. The CPU time limit is for actual computation, not waiting.

If you hit CPU time limits: the operation is genuinely too heavy for a Worker. Offload to a Durable Object or move computation to D1 stored procedures.

## wrangler.toml Pitfalls

Missing binding definition:
```toml
# Must declare ALL bindings — if missing, env.MY_BINDING will be undefined
[[kv_namespaces]]
binding = "KV"
id = "abc123..."

[[d1_databases]]
binding = "DB"
database_id = "xyz..."
database_name = "my-db"
```

If a binding is in the code but not in `wrangler.toml`, it's `undefined` — causes confusing runtime errors.

## Response Streaming

Workers support streaming responses via `ReadableStream`. The Vercel AI SDK's `toDataStreamResponse()` works correctly in Workers. However, the Worker must be configured for streaming in wrangler.toml if applicable.

## Cron Not Firing

If a scheduled worker stops firing:
1. Check Cloudflare dashboard → Workers → [worker] → Triggers — verify cron is listed
2. Check the worker has the `scheduled` handler exported (not just `fetch`)
3. Check the worker was last deployed successfully — a failed deploy disables triggers
4. Verify the cron syntax in wrangler.toml — `"*/5 * * * *"` not `"every 5 minutes"`

## opennextjs/cloudflare Next.js Compatibility

When running a Next.js app on Cloudflare via `@opennextjs/cloudflare`:
- Pages Router is NOT supported — App Router only
- Node.js-specific APIs must be replaced with Web APIs or will fail silently
- Edge runtime is the default; routes that need Node.js must be explicitly configured
- `npm run build` produces a standard Next.js build; `npx @opennextjs/cloudflare build` produces the Workers bundle — always run the CF build before deploying
