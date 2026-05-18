# Failure Patterns: Cloudflare Workers Errors

## "Module not found" for Node.js Built-ins

Error: `Cannot find module 'crypto'` or `Cannot find module 'stream'`

Cause: Cloudflare Workers run in a V8 isolate, not Node.js. Many Node.js built-ins don't exist or need compatibility flags.

Fix: Use the Web Crypto API instead:

```typescript
// WRONG — Node.js crypto not available in Workers:
import crypto from 'crypto'
const hash = crypto.createHmac('sha256', key).update(data).digest('hex')

// CORRECT — Web Crypto API:
const key = await crypto.subtle.importKey(
  'raw',
  new TextEncoder().encode(secret),
  { name: 'HMAC', hash: 'SHA-256' },
  false,
  ['sign']
)
const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data))
const hex = Array.from(new Uint8Array(signature)).map(b => b.toString(16).padStart(2, '0')).join('')
```

Or enable Node.js compat in `wrangler.toml`:
```toml
compatibility_flags = ["nodejs_compat"]
```

This enables `node:` prefix imports: `import crypto from 'node:crypto'`

## "Too many subrequests"

Cause: Cloudflare limits outgoing fetch calls. A single Worker invocation can make at most 50 subrequests to the same zone, 6 to external hosts simultaneously.

Fix: Batch external calls or use `waitUntil` for non-critical work:
```typescript
// WRONG — sequential fetches:
for (const id of ids) {
  await fetch(`/api/item/${id}`)  // hits limit quickly
}

// CORRECT — batch or parallelize carefully:
const results = await Promise.all(ids.slice(0, 6).map(id => fetch(`/api/item/${id}`)))
```

## "Script exceeded CPU time limit"

Workers have CPU time limits: 10ms for free plans, 30s (CPU time, not wall time) for paid.

Fix: Move heavy computation to Durable Objects or break into multiple requests:
```typescript
// Heavy loops are the common culprit
// Split into chunks and use waitUntil or KV as a queue

ctx.waitUntil(processChunkAsync(chunk))  // non-blocking, runs after response
return new Response('Processing')
```

## KV Consistency Delay

KV writes are eventually consistent (up to 60 seconds before changes propagate globally). Reading immediately after write might return the old value.

```typescript
// WRONG — read immediately after write:
await env.KV.put('key', 'value')
const result = await env.KV.get('key')  // might still be old value globally

// Handle eventual consistency:
// Option 1: Pass the value through directly instead of re-reading
// Option 2: Use the local binding (reads from origin, not CDN cache)
```

## D1 "Network Error" in Local Dev

`wrangler dev` with D1 sometimes fails with network errors when the database isn't initialized.

Fix:
```bash
# Initialize D1 locally:
wrangler d1 create my-database
wrangler d1 execute my-database --local --file=schema.sql
```

Also: `wrangler dev` must be running for D1 to be accessible. It's NOT a standalone database.

## Environment Variables vs Secrets

```typescript
// WRONG — using wrangler.toml vars for secrets:
[vars]
STRIPE_SECRET_KEY = "sk_live_..."  # visible in wrangler.toml, committed to git

// CORRECT — use secrets:
wrangler secret put STRIPE_SECRET_KEY
# Encrypted at rest, not in source control

// Access is the same in code:
const key = env.STRIPE_SECRET_KEY  // works for both vars and secrets
```

## Response Body Already Used

Error: `TypeError: Failed to execute 'json' on 'Response': body stream already read`

Cause: `req.json()`, `req.text()`, `req.arrayBuffer()` can only be called once. The body is a stream.

Fix: Clone the request if you need to read the body multiple times:
```typescript
// WRONG:
const body = await req.json()      // reads the body
const text = await req.text()      // body already consumed — error

// CORRECT — read once and use the value:
const text = await req.text()
const body = JSON.parse(text)      // parse it yourself

// OR clone for multiple reads:
const cloned = req.clone()
const body = await req.json()
const bodyText = await cloned.text()
```

## Durable Objects Not Available in Free Plan

Durable Objects require the Workers Paid plan. If you deploy code using Durable Objects on a free account, it silently fails or gives a cryptic error.

Fix: Use KV for simple state, upgrade to paid plan for Durable Objects, or redesign to avoid mutable server state.
