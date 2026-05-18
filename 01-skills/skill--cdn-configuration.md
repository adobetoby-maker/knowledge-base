# Skill: CDN Configuration

## Overview
A CDN (Content Delivery Network) serves assets from edge nodes close to users. The leverage comes from cache headers: static assets with hashed filenames can be cached forever at the edge, eliminating origin load. HTML and API responses need shorter TTLs with stale-while-revalidate to balance freshness and performance. Getting this wrong means either stale content that doesn't update, or cache misses that defeat the CDN entirely.

## Implementation

### Cache-Control Strategy by Asset Type

**Static assets with hashed filenames** (JS, CSS, images in `/dist/`, Next.js `/_next/static/`):
```
Cache-Control: public, max-age=31536000, immutable
```
`immutable` tells browsers the content won't change for `max-age` duration — skips conditional requests.

**HTML pages** (need to reflect content updates):
```
Cache-Control: public, max-age=0, s-maxage=300, stale-while-revalidate=3600
```
- `max-age=0`: browser always revalidates
- `s-maxage=300`: CDN caches for 5 minutes
- `stale-while-revalidate=3600`: serve stale from CDN while revalidating in background (users see 5-minute-old max, but no latency spike)

**API responses (authenticated):**
```
Cache-Control: private, no-store
```
`private` tells CDN not to cache; `no-store` tells browser not to cache sensitive data.

**API responses (public, shared):**
```
Cache-Control: public, s-maxage=60, stale-while-revalidate=300
```

### Next.js Configuration
```typescript
// next.config.ts
async headers() {
  return [
    {
      source: "/_next/static/(.*)",
      headers: [
        { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
      ],
    },
    {
      source: "/api/(.*)",
      headers: [
        { key: "Cache-Control", value: "private, no-store" },
      ],
    },
  ];
}
```

### Surrogate-Control vs Cache-Control
Some CDNs (Cloudflare, Fastly) support `Surrogate-Control` which overrides `Cache-Control` for edge only:
```
Surrogate-Control: max-age=3600
Cache-Control: no-store
```
This lets CDN cache while telling browsers not to — useful for sensitive content that's safe to cache at the edge but not on user devices.

### Cache Purging
Purge by URL for targeted invalidation:
```bash
# Cloudflare — purge specific URL
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -d '{"files":["https://example.com/page"]}'

# Purge by cache tag (requires Cloudflare Enterprise or Cache Rules)
# Tag assets: Surrogate-Key: product-123
# Purge all tagged: {"tags":["product-123"]}
```

### Vary Header for CDN Correctness
```
Vary: Accept-Encoding          # always — for gzip/br compressed responses
Vary: Accept-Language          # for locale-specific HTML
Vary: Origin                   # when reflecting CORS origins (see CORS guide)
```
Without `Vary: Accept-Encoding`, a CDN may serve a gzip-compressed response to a client that can't decompress it.

## Key Rules
- Hash filenames for all static assets and set `max-age=31536000, immutable` — this is the highest leverage CDN optimization
- Never cache authenticated API responses at the CDN — set `Cache-Control: private` for anything behind auth
- Use `stale-while-revalidate` for HTML pages — users get instant loads while the CDN refreshes in background
- Set `Vary: Accept-Encoding` on all compressed responses — without it, CDN may serve wrong encoding
- Design for cache invalidation from day one — passive TTL expiry is for static content; dynamic content needs purge-by-URL or purge-by-tag
- `s-maxage` overrides `max-age` for CDN; `max-age` applies to browsers — use both to control each layer independently
- Test cache behavior with `curl -I` to inspect response headers — browser DevTools caches are unreliable for testing CDN behavior
