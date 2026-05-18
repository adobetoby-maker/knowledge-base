# Cloudflare KV

## What KV Is

KV is Cloudflare's global key-value store. Reads are extremely fast (served from the nearest edge node). Writes are globally consistent within 60 seconds (eventually consistent).

Use KV for:
- Configuration and feature flags
- Session tokens and short-lived data
- Rate limiting counters
- Caching expensive API results
- Metadata lookups (slug → URL, code → config)

Do NOT use KV for:
- Data that needs to be queried by value (no filtering — keys only)
- Data with complex relationships
- Data that must be strongly consistent (rate limiters are fine because slight eventual consistency is acceptable; payment state is not)

## Setup

```bash
wrangler kv namespace create CACHE
wrangler kv namespace create CACHE --preview  # for dev
```

```toml
# wrangler.toml
[[kv_namespaces]]
binding = "CACHE"
id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
preview_id = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## Worker Handler with KV

```typescript
export interface Env {
  CACHE: KVNamespace
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const cacheKey = 'featured-articles'
    
    // Try cache first:
    const cached = await env.CACHE.get(cacheKey, 'json')
    if (cached) return Response.json(cached)
    
    // Fetch from origin:
    const articles = await fetchFeaturedArticles()
    
    // Cache with TTL (seconds):
    await env.CACHE.put(cacheKey, JSON.stringify(articles), { expirationTtl: 3600 })
    
    return Response.json(articles)
  }
}
```

## Value Types

```typescript
// String:
await env.KV.put('key', 'value')
const str = await env.KV.get('key')  // string | null

// JSON:
await env.KV.put('config', JSON.stringify({ flag: true }))
const config = await env.KV.get('config', 'json')  // parsed object | null

// Binary (ArrayBuffer):
await env.KV.put('image', buffer)
const data = await env.KV.get('image', 'arrayBuffer')

// Stream:
const stream = await env.KV.get('large-file', 'stream')
```

## Expiration

```typescript
// Expire at a specific Unix timestamp:
await env.KV.put('session', token, { expiration: Math.floor(Date.now() / 1000) + 3600 })

// Expire after N seconds:
await env.KV.put('cache', data, { expirationTtl: 300 })  // 5 minutes

// Minimum TTL is 60 seconds
```

## Listing Keys

```typescript
const { keys, list_complete, cursor } = await env.KV.list({ prefix: 'session:', limit: 100 })

for (const key of keys) {
  console.log(key.name, key.expiration, key.metadata)
}

// Paginate if list_complete is false:
if (!list_complete) {
  const nextPage = await env.KV.list({ prefix: 'session:', cursor })
}
```

## Metadata (Fast Lookups Without Value Reads)

Store small metadata alongside the key to avoid reading the full value:

```typescript
// Write with metadata:
await env.KV.put('invoice:abc123', JSON.stringify(invoice), {
  metadata: { status: 'paid', customerId: 'cust-456', amount: 15000 }
})

// List and check metadata without reading values:
const { keys } = await env.KV.list({ prefix: 'invoice:' })
const paidInvoices = keys.filter(k => (k.metadata as any)?.status === 'paid')
```

## Rate Limiting with KV

```typescript
export async function rateLimit(env: Env, key: string, limit: number, windowSeconds: number): Promise<boolean> {
  const current = parseInt(await env.KV.get(key) ?? '0')
  
  if (current >= limit) return false  // rate limited
  
  await env.KV.put(key, String(current + 1), { expirationTtl: windowSeconds })
  return true
}

// Usage:
const allowed = await rateLimit(env, `rate:${ip}:create-invoice`, 10, 60)
if (!allowed) return new Response('Too many requests', { status: 429 })
```

Note: KV's eventual consistency means rate limiting has ~1% tolerance — fine for abuse prevention, not for billing.
