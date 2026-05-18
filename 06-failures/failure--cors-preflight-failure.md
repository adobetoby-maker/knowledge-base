# Failure: CORS Preflight Failure

## Overview
CORS preflight failures are among the most confusing errors in web development because the error appears on the wrong request. The browser first sends an `OPTIONS` preflight request — which the server must also handle with the correct headers — before the actual `POST` or `PUT` ever fires. If the preflight fails, the real request never happens, and the error message ("blocked by CORS policy") appears to come from nowhere.

## What a Preflight Is

For "non-simple" requests (any request with custom headers, `Content-Type: application/json`, or methods other than GET/HEAD/POST), browsers automatically send an `OPTIONS` request first:

```
Browser → Server:
OPTIONS /api/orders HTTP/1.1
Origin: https://app.example.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type, authorization

Server → Browser:
HTTP/1.1 204 No Content
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE
Access-Control-Allow-Headers: content-type, authorization
Access-Control-Max-Age: 86400
```

If the server returns anything other than the correct CORS headers on this `OPTIONS` response, the browser aborts and the actual POST never fires.

## The Most Common Mistake: CORS Headers on POST Only

```typescript
// WRONG: adds CORS headers to the handler but not OPTIONS
export async function POST(req: Request) {
  return Response.json({ success: true }, {
    headers: { 'Access-Control-Allow-Origin': '*' }  // too late — preflight already failed
  });
}

// CORRECT: handle OPTIONS explicitly
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': 'https://app.example.com',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'content-type, authorization',
      'Access-Control-Max-Age': '86400',
    },
  });
}

export async function POST(req: Request) {
  return Response.json({ success: true }, {
    headers: { 'Access-Control-Allow-Origin': 'https://app.example.com' }
  });
}
```

## Wildcard Origin Blocks Credentials

```
Access-Control-Allow-Origin: *
```
This does NOT work when the request includes credentials (`credentials: 'include'`, cookies, or `Authorization` headers). The browser requires a specific origin, not a wildcard, when credentials are sent.

```typescript
// With credentials: must specify exact origin, not *
const origin = req.headers.get('origin');
const allowedOrigins = ['https://app.example.com', 'https://staging.example.com'];

if (origin && allowedOrigins.includes(origin)) {
  headers.set('Access-Control-Allow-Origin', origin);
  headers.set('Access-Control-Allow-Credentials', 'true');
}
// If origin not in allowlist: omit the header entirely (browser will block)
```

## Next.js Middleware CORS

In Next.js, handle CORS in middleware so it applies globally:

```typescript
// middleware.ts
export function middleware(req: NextRequest) {
  const origin = req.headers.get('origin') ?? '';

  if (req.method === 'OPTIONS') {
    return new NextResponse(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'content-type, authorization',
      },
    });
  }

  const res = NextResponse.next();
  res.headers.set('Access-Control-Allow-Origin', origin);
  return res;
}

export const config = {
  matcher: '/api/:path*',
};
```

## Order of Middleware Matters

If authentication middleware runs before CORS middleware, an `OPTIONS` preflight might receive a `401 Unauthorized` (because it has no auth token) before CORS headers are added. CORS middleware must run first.

## When Credentials Are Needed

Add `credentials: 'include'` to fetch only when:
1. Sending authentication cookies cross-origin
2. The server is on a different domain than the app

For same-domain requests (app and API on the same domain or subdomain), credentials are unnecessary and CORS typically doesn't apply.

## Key Rules
- CORS headers must be on `OPTIONS` responses, not just `POST`/`PUT` responses
- Wildcard `*` origin is incompatible with `credentials: 'include'` — use the specific allowed origin
- CORS middleware must execute before authentication middleware
- `Access-Control-Max-Age` caches preflight responses — set to 86400 (1 day) to reduce preflight traffic
- Same-origin requests don't trigger CORS; cross-origin = different protocol, domain, or port
- When debugging, check the `OPTIONS` request in DevTools Network tab, not the failing POST
