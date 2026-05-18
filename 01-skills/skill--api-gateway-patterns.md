# Skill: API Gateway Patterns

## Overview
An API gateway is the single entry point for all client traffic. By centralizing cross-cutting concerns (auth, rate limiting, CORS, routing) at the gateway, each downstream service stays focused on business logic rather than infrastructure. The key insight: every service reimplementing auth is duplicated surface area for bugs and security holes.

## Implementation

### 1. Authentication at the gateway
```ts
// gateway/middleware/auth.ts
import { verifyJWT } from '../lib/jwt';

export async function authMiddleware(req: Request, next: Handler): Promise<Response> {
  // Public paths bypass auth — explicit allowlist is safer than denylist
  const PUBLIC_PATHS = ['/health', '/auth/login', '/auth/register', '/webhooks/'];
  const isPublic = PUBLIC_PATHS.some(p => req.url.includes(p));
  
  if (isPublic) return next(req);

  const token = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!token) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const claims = await verifyJWT(token);
    
    // Add user context as headers — services trust these without re-validating
    const enrichedReq = new Request(req, {
      headers: {
        ...Object.fromEntries(req.headers),
        'x-user-id': claims.sub,
        'x-user-role': claims.role,
        'x-tenant-id': claims.tenantId,
      },
    });
    return next(enrichedReq);
  } catch {
    return new Response('Invalid token', { status: 401 });
  }
}
```

### 2. Rate limiting by API key
```ts
// gateway/middleware/rate-limit.ts
import { Redis } from '@upstash/redis';

const redis = new Redis({ url: process.env.REDIS_URL!, token: process.env.REDIS_TOKEN! });

const LIMITS = {
  free: { requests: 100, windowSec: 60 },
  pro: { requests: 1000, windowSec: 60 },
  enterprise: { requests: 10_000, windowSec: 60 },
};

export async function rateLimitMiddleware(req: Request, next: Handler): Promise<Response> {
  const apiKey = req.headers.get('x-api-key');
  const tier = await getTierForKey(apiKey);   // lookup tier from DB/cache
  const { requests, windowSec } = LIMITS[tier ?? 'free'];
  
  const key = `rate:${apiKey ?? req.headers.get('cf-connecting-ip')}`;
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, windowSec);  // set expiry on first request
  }

  // Set rate limit headers (standard — used by clients to self-throttle)
  const headers = {
    'X-RateLimit-Limit': String(requests),
    'X-RateLimit-Remaining': String(Math.max(0, requests - current)),
    'X-RateLimit-Reset': String(Date.now() + windowSec * 1000),
  };

  if (current > requests) {
    return new Response('Too Many Requests', { status: 429, headers });
  }

  const response = await next(req);
  // Add rate limit headers to all responses
  for (const [k, v] of Object.entries(headers)) {
    response.headers.set(k, v);
  }
  return response;
}
```

### 3. CORS at the gateway (not in services)
```ts
const ALLOWED_ORIGINS = new Set([
  'https://app.example.com',
  'https://admin.example.com',
]);

export function corsMiddleware(req: Request, next: Handler): Promise<Response> | Response {
  const origin = req.headers.get('Origin') ?? '';
  const allowed = ALLOWED_ORIGINS.has(origin) ? origin : '';

  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': allowed,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-key',
        'Access-Control-Max-Age': '86400',
      },
    });
  }

  return next(req).then(res => {
    if (allowed) res.headers.set('Access-Control-Allow-Origin', allowed);
    return res;
  });
}
```

### 4. Request routing and upstream circuit breaker
```ts
const ROUTES: Array<{ pattern: RegExp; upstream: string }> = [
  { pattern: /^\/api\/orders/, upstream: process.env.ORDER_SERVICE_URL! },
  { pattern: /^\/api\/users/,  upstream: process.env.USER_SERVICE_URL! },
  { pattern: /^\/api\/inventory/, upstream: process.env.INVENTORY_SERVICE_URL! },
];

export async function routeRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const route = ROUTES.find(r => r.pattern.test(url.pathname));
  
  if (!route) return new Response('Not Found', { status: 404 });

  // Propagate request ID for distributed tracing
  const requestId = req.headers.get('x-request-id') ?? crypto.randomUUID();
  
  try {
    return await fetch(`${route.upstream}${url.pathname}${url.search}`, {
      method: req.method,
      headers: { ...Object.fromEntries(req.headers), 'x-request-id': requestId },
      body: req.body,
      signal: AbortSignal.timeout(10_000),  // 10s max per upstream
    });
  } catch (err) {
    console.error(`Upstream ${route.upstream} failed:`, err);
    return new Response('Service Unavailable', { status: 503 });
  }
}
```

### 5. Response caching for idempotent endpoints
```ts
export async function cacheMiddleware(req: Request, next: Handler): Promise<Response> {
  // Only cache GET requests
  if (req.method !== 'GET') return next(req);
  
  const cacheKey = `cache:${req.url}:${req.headers.get('x-tenant-id')}`;
  const cached = await redis.get(cacheKey);
  if (cached) {
    return new Response(cached as string, {
      headers: { 'Content-Type': 'application/json', 'X-Cache': 'HIT' },
    });
  }

  const response = await next(req);
  const body = await response.text();
  
  // Cache successful responses for 60s
  if (response.ok) await redis.set(cacheKey, body, { ex: 60 });
  
  return new Response(body, { status: response.status, headers: response.headers });
}
```

## Key Rules
- **Authenticate at gateway, not each service** — downstream services trust `x-user-id` headers forwarded from the gateway; they never revalidate the token.
- **CORS must be at the gateway** — if CORS lives in individual services, adding a new service means updating CORS in multiple places.
- Set rate limit headers (`X-RateLimit-*`) on every response — clients need them to implement self-throttling and back off gracefully.
- **Services must reject requests without gateway headers** — if `x-user-id` is absent, the request bypassed auth; return 401.
- Timeout every upstream call — a slow service must not block the gateway thread pool.
- Log `x-request-id` in the gateway and propagate it downstream — this makes distributed traces joinable.
- Route matching should be explicit patterns, not dynamic proxying — dynamic proxying to arbitrary upstreams is a SSRF vulnerability.
