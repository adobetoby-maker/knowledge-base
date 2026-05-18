# Failure: HTTP Cache Poisoning via Unkeyed Inputs

## Overview
Cache poisoning occurs when a CDN or reverse proxy caches a response that was generated using an input that isn't part of the cache key. A classic example: the response varies based on the `Accept-Language` header, but the `Vary: Accept-Language` header is missing. The CDN caches the English version for the first request, then serves that cached English version to French users whose requests would have gotten a French response. This is silent and correctness-breaking.

## How It Happens

```
Request 1: GET /home, Accept-Language: en-US
→ Server responds: <html lang="en">Hello</html>, Cache-Control: max-age=3600
→ CDN caches this response at key: GET /home

Request 2: GET /home, Accept-Language: fr-FR
→ CDN cache HIT! Returns the English version to French user
→ User sees English content (wrong)
```

The fix: `Vary: Accept-Language` tells the CDN to include that header in the cache key.

## Unkeyed Headers That Commonly Cause This

```
Accept-Language  → Serves wrong locale
Accept-Encoding  → Corrupts compressed/uncompressed content mixing
X-Forwarded-Host → Stores wrong absolute URLs with wrong domain
X-Forwarded-Proto→ Stores HTTP links on HTTPS site
Cookie           → Caches authenticated content as public
Origin           → CORS headers include wrong Allow-Origin
```

## Fix 1: Set Vary headers correctly

```ts
// Next.js route handler
export async function GET(req: Request) {
  const lang = req.headers.get('accept-language')?.split(',')[0] ?? 'en'
  const content = await getLocalizedContent(lang)

  return Response.json(content, {
    headers: {
      'Cache-Control': 'public, max-age=3600',
      'Vary': 'Accept-Language',  // CDN now keys on language
    },
  })
}

// If multiple headers affect the response:
'Vary': 'Accept-Language, Accept-Encoding'
```

## Fix 2: Never cache authenticated responses publicly

```ts
// BAD: public cache for authenticated content
export async function GET(req: Request) {
  const user = await getUser(req)  // Uses Cookie header
  const data = await getPersonalizedData(user.id)

  return Response.json(data, {
    headers: {
      'Cache-Control': 'public, max-age=600',  // WRONG: Caches user-specific data publicly!
    },
  })
}

// GOOD: private cache for authenticated content
return Response.json(data, {
  headers: {
    'Cache-Control': 'private, max-age=600',   // Only browser caches, not CDN
    // OR: no-store for truly sensitive data
    'Cache-Control': 'no-store',
  },
})
```

## Fix 3: Surrogate keys for fine-grained CDN invalidation

```ts
// Cloudflare Cache Tags (surrogate keys)
// Tag responses with identifiers so you can invalidate specific sets
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const product = await getProduct(params.id)

  return Response.json(product, {
    headers: {
      'Cache-Control': 'public, max-age=86400',
      'Cache-Tag': `product-${params.id}, category-${product.categoryId}`,
      // Now you can purge all products in a category in one API call
    },
  })
}

// Purge by tag when product data changes:
// curl -X DELETE https://api.cloudflare.com/... -d '{"tags":["product-abc123"]}'
```

## Fix 4: Test with different Accept headers

```bash
# Test that language variation is respected (should get different responses)
curl -H "Accept-Language: en-US" https://example.com/api/content
curl -H "Accept-Language: fr-FR" https://example.com/api/content

# Both should return content-appropriate for the language
# If both return English → missing Vary header

# Verify Vary header is present
curl -I https://example.com/api/content | grep -i vary
```

## Fix 5: Strip dangerous headers before caching

```ts
// Nginx/CDN config: strip headers that shouldn't affect cache keys but could be exploited
// X-Forwarded-Host can be manipulated by attackers to poison cache with wrong domain
map $http_x_forwarded_host $trusted_host {
  default $host;
}
# Or: ignore X-Forwarded-Host for cache key purposes
```

## Key Rules
- `Vary` header must include every request header that affects the response content
- `Cache-Control: private` for any response that uses authentication (Cookie, Authorization)
- Test Vary compliance: send the same URL with different header values and verify distinct responses
- Surrogate keys / cache tags enable targeted cache invalidation without global purges
- Never store authenticated responses in shared caches — shared caches are for public content only
- `X-Forwarded-Proto` and `X-Forwarded-Host` should be normalized before they affect response content
- CDN configurations often have their own caching rules that override your `Cache-Control` headers — verify what the CDN actually caches
