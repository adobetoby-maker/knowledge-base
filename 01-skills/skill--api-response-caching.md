# Skill: API Response Caching Strategy

## Overview
Caching API responses at the right layer (browser, CDN, or application) reduces latency and server load. The mistake is over-caching authenticated or sensitive data, or under-caching public data that changes rarely. The `Cache-Control` header is the contract between your server, CDN, and client — getting it wrong causes stale data or missed cache opportunities.

## Implementation

### Cache-Control Decision Tree

**Does the response contain user-specific data?**
- Yes: `Cache-Control: private, max-age=60` (browser only, not CDN)
- Yes + sensitive (account details, payment info): `Cache-Control: no-store`
- No (public data): `Cache-Control: public, s-maxage=300, stale-while-revalidate=600`

**Is the data real-time critical?**
- Yes (stock prices, live inventory): `Cache-Control: no-cache` (always revalidate)
- No: `stale-while-revalidate` allows serving stale while refreshing

### ETags for Conditional Requests
```typescript
// Route handler
import { createHash } from "crypto";

export async function GET(request: Request) {
  const data = await fetchProducts();
  const etag = `"${createHash("sha1").update(JSON.stringify(data)).digest("hex").slice(0, 8)}"`;

  // Client sends If-None-Match: "abc123" on subsequent requests
  const ifNoneMatch = request.headers.get("If-None-Match");
  if (ifNoneMatch === etag) {
    return new Response(null, {
      status: 304,  // Not Modified — client uses cached version
      headers: { ETag: etag },
    });
  }

  return Response.json(data, {
    headers: {
      "Cache-Control": "public, s-maxage=300, stale-while-revalidate=600",
      "ETag": etag,
    },
  });
}
```

### Next.js fetch() Caching (App Router)
```typescript
// Server Component or server function

// Cache indefinitely (ISR-style, revalidate on demand)
const data = await fetch("https://api.example.com/products", {
  next: { revalidate: 300 }  // revalidate every 5 minutes
});

// No caching — always fresh
const userData = await fetch(`/api/user/${id}`, {
  cache: "no-store"
});

// Cache with tag for targeted invalidation
const posts = await fetch("/api/posts", {
  next: { tags: ["posts"] }
});

// Then in a Server Action or Route Handler:
import { revalidateTag } from "next/cache";
revalidateTag("posts");  // invalidates all fetches tagged "posts"
```

### Application-Level Cache (Redis)
```typescript
// lib/cache.ts
export async function getCached<T>(
  key: string,
  ttlSeconds: number,
  fetcher: () => Promise<T>,
): Promise<T> {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached) as T;

  const fresh = await fetcher();
  await redis.setex(key, ttlSeconds, JSON.stringify(fresh));
  return fresh;
}

// Usage
const products = await getCached(
  "products:all",
  300,
  () => db.select().from(productsTable)
);
```

### No-Store for Sensitive Data
```typescript
// Account details, billing info, tokens — never cache
return Response.json(accountDetails, {
  headers: {
    "Cache-Control": "no-store",
    "Pragma": "no-cache",  // legacy HTTP/1.0 clients
  },
});
```

## Key Rules
- Use `no-store` for any response containing PII, payment data, session tokens, or admin data — not `no-cache`, not `private`
- `private` means browser can cache but CDN cannot — use for per-user data that's safe to store on the device
- ETags enable 304 responses that save bandwidth without a full roundtrip — implement for any resource that clients fetch repeatedly
- `stale-while-revalidate` is the best tradeoff for non-critical public data — zero latency for users, eventual freshness
- Redis application cache is the right layer for: DB query results, expensive computations, third-party API responses
- Invalidate Redis cache on write — don't wait for TTL expiry when you know the data changed
- Test cache headers with `curl -I` — browsers apply their own caching heuristics that can mask server header bugs
