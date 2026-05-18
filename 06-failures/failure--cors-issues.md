# Failure Pattern: CORS Issues

## Overview

CORS (Cross-Origin Resource Sharing) blocks browser-initiated requests to a different origin. The browser enforces it, not the server — the server still receives and processes the request. CORS blocks the browser from reading the response.

## Understanding What CORS Is and Isn't

```
Browser in origin A makes request to origin B:
  1. Browser sends request (+ Origin header)
  2. Server receives and processes request
  3. Server sends response (+ or - CORS headers)
  4. Browser checks CORS headers
  5. If headers allow origin A → JavaScript gets response
  6. If headers don't allow origin A → JavaScript gets blocked
```

**Key insight**: The request happens. Only the response is blocked. This means CORS doesn't prevent a mutating request (POST/DELETE) from executing — it only prevents you from reading the result. This is why CSRF protection is separate from CORS.

## Cause 1: Missing CORS Headers on API

```ts
// Next.js Route Handler without CORS headers
export async function GET(req: Request) {
  return Response.json({ data: 'hello' })
  // No CORS headers → blocked if called from different origin
}

// Fix: add CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.FRONTEND_URL ?? '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders })
}

export async function GET(req: Request) {
  return Response.json({ data: 'hello' }, { headers: corsHeaders })
}
```

Always handle `OPTIONS` (preflight) requests. Browsers send an OPTIONS request before POST/PUT/DELETE with custom headers.

## Cause 2: Wildcard Origin with Credentials

```ts
// Wrong: credentials can't be used with wildcard origin
headers: {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Credentials': 'true',  // Rejected by browser
}

// Fix: specify exact origin
headers: {
  'Access-Control-Allow-Origin': 'https://myapp.com',
  'Access-Control-Allow-Credentials': 'true',
}

// For multiple allowed origins:
function getCorsOrigin(requestOrigin: string | null): string {
  const allowed = ['https://myapp.com', 'https://app.myapp.com', 'http://localhost:3000']
  return allowed.includes(requestOrigin ?? '') ? requestOrigin! : allowed[0]
}
```

## Cause 3: Missing Authorization Header in Allow-Headers

```ts
// Wrong: Authorization header not allowed → preflight rejected
headers: {
  'Access-Control-Allow-Headers': 'Content-Type',
}

// Fix
headers: {
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Request-ID',
}
```

Any custom header you send from the frontend must be in `Allow-Headers`. Common ones: `Authorization`, `Content-Type`, `X-Api-Key`, `X-Request-ID`.

## Cause 4: Supabase Client Called From Wrong Origin

Supabase handles CORS at the service level — the client library sends requests to `https://[project].supabase.co`. If this returns CORS errors:

1. Check that `NEXT_PUBLIC_SUPABASE_URL` is correct
2. Verify the Supabase project is not in maintenance mode
3. Check network tab — is it hitting the right URL?

Supabase does not require custom CORS configuration for most use cases.

## Cause 5: Development vs Production Origin Mismatch

```ts
// Backend allows production but not localhost in dev
const ALLOWED_ORIGINS = ['https://myapp.com']

// Fix: include dev origins in dev environment
const ALLOWED_ORIGINS = process.env.NODE_ENV === 'development'
  ? ['https://myapp.com', 'http://localhost:3000', 'http://localhost:3001']
  : ['https://myapp.com']
```

## Diagnosing CORS Errors

```
Network tab → failed request → Response headers tab:
  - If Access-Control-Allow-Origin is missing → server not setting CORS headers
  - If Access-Control-Allow-Origin is present but wrong origin → origin not in allowlist
  - If preflight OPTIONS returns 404 → OPTIONS route not handled

Console error patterns:
  "has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header"
  → Server not returning CORS headers

  "has been blocked by CORS policy: The 'Access-Control-Allow-Origin' header...is not equal to the supplied origin"
  → Origin not in allowlist

  "has been blocked by CORS policy: Request header field authorization is not allowed"
  → Authorization not in Allow-Headers
```

## CORS in Next.js (App Router)

Centralize CORS in middleware:

```ts
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'

const ALLOWED_ORIGINS = ['https://myapp.com', 'http://localhost:3000']

export function middleware(req: NextRequest) {
  const origin = req.headers.get('origin')
  const isAllowed = origin && ALLOWED_ORIGINS.includes(origin)
  
  // Handle preflight
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, {
      status: 204,
      headers: {
        'Access-Control-Allow-Origin': isAllowed ? origin : ALLOWED_ORIGINS[0],
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Max-Age': '86400',
      },
    })
  }

  const response = NextResponse.next()
  if (isAllowed) {
    response.headers.set('Access-Control-Allow-Origin', origin)
  }
  return response
}

export const config = { matcher: '/api/:path*' }
```
