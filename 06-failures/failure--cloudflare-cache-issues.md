# Failure: Cloudflare Cache Issues

## Problem: Cached Response Returned After Update

**Symptom**: API returns stale data; page shows outdated content after a Vercel redeploy or after a database update.

**Root cause**: Cloudflare caches HTTP responses by default based on `Cache-Control` headers. If a Route Handler or static page returns a cacheable response and you update the underlying data, Cloudflare continues serving the old version until the TTL expires.

**Fix 1**: Set appropriate Cache-Control headers:
```ts
// For API routes that return dynamic data — never cache
export async function GET() {
  const data = await fetchData()
  return NextResponse.json(data, {
    headers: {
      'Cache-Control': 'no-store, no-cache, must-revalidate',
    },
  })
}

// For static pages that rarely change — short TTL with stale-while-revalidate
// Cache-Control: public, max-age=60, s-maxage=3600, stale-while-revalidate=86400
```

**Fix 2**: Purge the cache via Cloudflare API when data changes:
```ts
async function purgeCloudflareCache(urls: string[]) {
  await fetch(`https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${CF_API_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ files: urls }),
  })
}
```

## Problem: KV Data Stale After Write

**Symptom**: Write to Cloudflare KV, read it back immediately, get the old value.

**Root cause**: KV has eventual consistency. Writes propagate globally within 60 seconds but reads from edge locations may return stale values immediately after a write.

**Fix**: For data that must be immediately consistent after write, use D1 (SQLite) instead of KV. KV is appropriate for data that can tolerate eventual consistency (feature flags, cached content, rate limit counters with approximate accuracy).

```ts
// If you need read-after-write consistency: use D1
const result = await env.DB.prepare('INSERT INTO sessions VALUES (?, ?)').bind(key, value).run()
const row = await env.DB.prepare('SELECT * FROM sessions WHERE key = ?').bind(key).first()
// D1 guarantees read-after-write consistency within the same region
```

## Problem: Workers Assets (Static Files) Not Updating

**Symptom**: After deploying a new Cloudflare Worker with updated static assets, the old files are still being served.

**Root cause**: Cloudflare caches Workers assets by content hash. If the hash doesn't change (file appears identical), the cached version is served.

**Fix**: If content changed but hash didn't (unusual, but can happen with build reproducibility issues), add a cache-busting query param or force-purge the specific file:
```bash
# Purge specific asset URL via wrangler
wrangler pages deployment tail
# Or via API: purge the exact URL of the stale asset
```

## Problem: Redirect Loop After Domain Config

**Symptom**: `ERR_TOO_MANY_REDIRECTS` after setting up a custom domain through Cloudflare.

**Root cause**: Both Cloudflare (SSL mode) and the origin server (HTTPS redirect) are redirecting. HTTP → HTTPS at CF → HTTP at origin → HTTPS redirect → HTTP → ...

**Fix**: In Cloudflare SSL/TLS settings, set to "Full (strict)" not "Flexible". Flexible means CF → origin over HTTP, which causes the loop if the origin also does HTTPS redirect.

For Vercel origins: use "Full" mode. Vercel handles HTTPS natively.

## Problem: Worker Returns 524 (Timeout)

**Symptom**: Worker response returns HTTP 524 (A Timeout Occurred) for some requests.

**Root cause**: Cloudflare waits a maximum of 100 seconds for an origin response, then returns 524. This is a Cloudflare-side timeout, not a worker crash.

For Workers (edge functions), the CPU time limit is:
- Free plan: 10ms CPU time
- Paid plan: 50ms CPU time (with up to 30s wall clock for network I/O)

**Fix for expensive operations**:
1. Move computation to Durable Objects if you need long-running state
2. Use `waitUntil` for work that can complete after the response:
```ts
export default {
  async fetch(request, env, ctx) {
    const response = new Response('OK')
    // This runs after the response is sent — doesn't count against CPU limit
    ctx.waitUntil(doSlowBackgroundWork())
    return response
  }
}
```

## Problem: D1 Query Returns Empty After Insert

**Symptom**: Insert to D1 succeeds, immediately query the same table, get 0 rows.

**Root cause**: D1 uses SQLite journal mode. Within a single Worker invocation, reads after writes are consistent. But if you're querying from a different Worker instance or request, there's a brief replication lag (typically < 100ms, but not zero).

**Fix**: Structure code so the read happens in the same request as the write, or add retry logic with a brief delay for reads after writes in distributed scenarios.
