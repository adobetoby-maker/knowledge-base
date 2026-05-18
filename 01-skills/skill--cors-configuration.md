# Skill: CORS Configuration

## Overview
CORS (Cross-Origin Resource Sharing) controls which origins can make requests to your API from the browser. The critical mistake: setting `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` — this is invalid and browsers reject it, but it also signals that your CORS configuration wasn't thought through. Credentials require an explicit, specific origin.

## Implementation

### Origin Allowlist Pattern
```typescript
// lib/cors.ts
const ALLOWED_ORIGINS = new Set([
  "https://app.example.com",
  "https://staging.example.com",
  process.env.NODE_ENV === "development" ? "http://localhost:3000" : "",
].filter(Boolean));

export function getCorsHeaders(requestOrigin: string | null): HeadersInit {
  const origin = requestOrigin && ALLOWED_ORIGINS.has(requestOrigin)
    ? requestOrigin      // reflect back the exact request origin
    : null;              // no CORS header = browser blocks the request

  if (!origin) return {};

  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Credentials": "true",
    "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",   // preflight cached for 24h
    "Vary": "Origin",                     // tells CDN: cached response varies by Origin header
  };
}
```

### Handle OPTIONS Before Auth Middleware
```typescript
// api route handler
export async function OPTIONS(request: Request) {
  const origin = request.headers.get("Origin");
  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(origin),
  });
}

export async function POST(request: Request) {
  const origin = request.headers.get("Origin");
  const corsHeaders = getCorsHeaders(origin);

  // Auth check after CORS — preflight OPTIONS must succeed without auth
  const user = await getUser(request);
  if (!user) {
    return new Response("Unauthorized", { status: 401, headers: corsHeaders });
  }

  const result = await handleRequest(request);
  return Response.json(result, { headers: corsHeaders });
}
```

### Preflight Request Flow
1. Browser sends `OPTIONS` with `Origin`, `Access-Control-Request-Method`, `Access-Control-Request-Headers`
2. Server responds with `Access-Control-Allow-*` headers
3. Browser caches the preflight result for `Access-Control-Max-Age` seconds
4. Browser sends the actual request with `Origin` header
5. Server responds with `Access-Control-Allow-Origin` matching the request Origin

### Public API (no credentials)
```typescript
// For public APIs that don't use cookies/auth headers
return {
  "Access-Control-Allow-Origin": "*",    // wildcard OK when no credentials
  "Access-Control-Allow-Methods": "GET",
  "Access-Control-Max-Age": "3600",
  // No "Vary: Origin" needed — response is the same for all origins
};
```

## Key Rules
- Never combine `Access-Control-Allow-Origin: *` with `Access-Control-Allow-Credentials: true` — browsers reject this combination; credentials require a specific reflected origin
- Reflect the request's `Origin` header back only if it's in your allowlist — do not blindly echo `Origin` without checking
- Set `Vary: Origin` when reflecting origins — CDNs cache responses and will serve wrong CORS headers to other origins without this
- Handle `OPTIONS` before authentication — preflight requests don't carry credentials and must succeed without auth
- Set `Access-Control-Max-Age` to reduce preflight overhead — 86400 (24h) is the browser maximum
- Include only the headers your API actually uses in `Access-Control-Allow-Headers` — listing everything is a security signal
- Keep the allowed origins list in an environment variable or config, not hardcoded in handler files
