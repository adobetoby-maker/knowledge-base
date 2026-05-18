# Failure: Cloudflare Caching Stale API Responses

## Why This Catches Developers Off Guard

In local development there is no CDN layer — responses are served fresh from the origin every time. In production behind Cloudflare, the default cache behavior caches responses based on file extension and response headers. A JSON API response with no `Cache-Control` header may get cached for hours on Cloudflare's edge because Cloudflare infers cachability from the content type and status code.

The symptom: an API endpoint returns correct data in development, but in production returns stale data for users in cached edge regions. Particularly common after data updates — the write succeeds but subsequent reads return the pre-update response.

## Default Cloudflare Caching Behavior

Cloudflare's default cache tier (without Page Rules or Cache Rules) respects `Cache-Control` headers when present. When absent, it applies its own heuristics — and for some configurations it caches `200` responses from static-looking URLs. Dynamic API routes under `/api/` are often excluded by Cloudflare's defaults, but custom domains, Page Rules, and Cloudflare for Teams configurations change this.

The only safe guarantee for dynamic API responses: set an explicit `Cache-Control: no-store` header.

## Setting Cache-Control on API Routes

```ts
// Next.js Route Handler
export async function GET() {
  const data = await fetchData();
  return Response.json(data, {
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}
```

`no-store` means: do not cache this response anywhere, ever — not Cloudflare, not the browser, not intermediate proxies. Use this for any endpoint where correctness matters more than performance.

For responses that can tolerate brief staleness (e.g., a public leaderboard):

```
Cache-Control: public, max-age=60, s-maxage=300, stale-while-revalidate=60
```

`s-maxage` controls the CDN TTL specifically. `max-age` controls the browser. Setting `s-maxage=0` with `max-age=60` lets the browser cache but forces Cloudflare to revalidate.

## Cloudflare Page Rules and Cache Rules

If a Cloudflare Page Rule or Cache Rule is set to "Cache Everything" for `*.yourdomain.com/*`, it overrides `Cache-Control` headers and caches all responses including dynamic API routes. Check the Cloudflare dashboard under **Rules > Page Rules** and **Caching > Cache Rules** for any rule that matches your API URL pattern.

To exclude API routes from a "Cache Everything" rule, add a more specific rule that matches `/api/*` with Cache Level = Bypass. More specific URL patterns take precedence over broader ones.

## Purging Stale Caches

When a stale response is already cached and must be invalidated:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"files": ["https://yourdomain.com/api/data"]}'
```

Cache purge propagates to all edge nodes within seconds. For bulk purges, use tag-based purging with `Cache-Tag` response headers (Enterprise plan required for tag purging).

## Distinguishing Cloudflare Cache From Application Cache

Cloudflare adds a `CF-Cache-Status` response header to indicate cache state:
- `HIT` — response served from Cloudflare cache
- `MISS` — response fetched from origin
- `BYPASS` — caching was bypassed by rule or header
- `DYNAMIC` — Cloudflare determined the response is not cacheable

If `CF-Cache-Status: HIT` is present on an API response that should be dynamic, the cache is the problem.

## Key Rules

- Set `Cache-Control: no-store` on every API route that returns user-specific or frequently-updated data
- Check `CF-Cache-Status` response header before debugging the application layer
- Audit Cloudflare Page Rules and Cache Rules for any "Cache Everything" rule that might match API paths
- Use `s-maxage` to control CDN TTL separately from browser TTL on cacheable public endpoints
- Add a specific Bypass rule for `/api/*` if a broad "Cache Everything" rule is needed for static assets
- Never rely on absence of a `Cache-Control` header meaning "not cached" — explicit is required
