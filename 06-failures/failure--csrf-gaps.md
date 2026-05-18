# Failure: CSRF Gaps

## Overview

CSRF (Cross-Site Request Forgery) tricks an authenticated user's browser into making requests to your app from a malicious site. The browser automatically sends cookies, so session cookies offer no protection. Defense: SameSite cookies, CSRF tokens, and origin verification. Modern frameworks (Next.js) help but don't fully eliminate the risk.

## Why SameSite Lax Isn't Enough

`SameSite=Lax` (the default) blocks cross-site POST requests but allows cross-site GET requests (top-level navigations). This means:

```
GET /api/admin/delete-everything  — vulnerable if this has side effects
POST /api/transfer-funds           — protected by SameSite=Lax
```

Never use GET requests for state-changing operations.

## CSRF Token Pattern

```ts
// lib/csrf.ts
import { createHmac, timingSafeEqual } from 'crypto'

const CSRF_SECRET = process.env.CSRF_SECRET!

export function generateCsrfToken(sessionId: string): string {
  const timestamp = Date.now().toString()
  const sig = createHmac('sha256', CSRF_SECRET)
    .update(`${sessionId}:${timestamp}`)
    .digest('hex')
  return `${timestamp}.${sig}`
}

export function verifyCsrfToken(token: string, sessionId: string): boolean {
  const [timestamp, sig] = token.split('.')
  if (!timestamp || !sig) return false

  // Expire tokens after 1 hour
  if (Date.now() - Number(timestamp) > 60 * 60 * 1000) return false

  const expected = createHmac('sha256', CSRF_SECRET)
    .update(`${sessionId}:${timestamp}`)
    .digest('hex')

  return timingSafeEqual(Buffer.from(sig, 'hex'), Buffer.from(expected, 'hex'))
}
```

## Server Action Pattern (Next.js App Router)

In Next.js App Router, Server Actions automatically check that the request comes from the same origin. But for API routes, check manually:

```ts
// middleware.ts or in route handlers
function verifyOrigin(req: Request): boolean {
  const origin = req.headers.get('origin')
  const host = req.headers.get('host')
  const referer = req.headers.get('referer')

  const allowed = process.env.NEXT_PUBLIC_SITE_URL ?? `https://${host}`

  if (origin) {
    return origin === allowed
  }

  if (referer) {
    return referer.startsWith(allowed)
  }

  // No origin/referer — could be same-site or old browser
  // Allow for simple GET; block for state-changing methods
  return req.method === 'GET'
}

// In a route handler
export async function POST(req: Request) {
  if (!verifyOrigin(req)) {
    return new Response('CSRF check failed', { status: 403 })
  }
  // ...
}
```

## Double Submit Cookie Pattern

```ts
// Set CSRF token cookie + send in header
// Client reads cookie and sends as custom header
// Attacker can't read the cookie (SameSite) so can't set the header

// Server: set csrf token
res.cookies.set('csrf-token', generateToken(), {
  sameSite: 'strict',
  secure: true,
  httpOnly: false,  // Must be readable by JS to include in header
})

// Client: include in every mutating request
async function apiPost(url: string, body: object) {
  const csrfToken = getCookie('csrf-token')
  return fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken ?? '',
    },
    body: JSON.stringify(body),
  })
}

// Server: verify header matches cookie
function verifyCsrfHeader(req: Request): boolean {
  const headerToken = req.headers.get('x-csrf-token')
  const cookieToken = getCookieFromRequest(req, 'csrf-token')
  if (!headerToken || !cookieToken) return false
  return timingSafeEqual(Buffer.from(headerToken), Buffer.from(cookieToken))
}
```

## Supabase Auth + CSRF

Supabase uses JWTs in Authorization headers, not cookies. Headers require JavaScript to set — cross-site forms can't set custom headers. This makes JWT-in-header apps naturally CSRF-resistant, but:

```ts
// If using Supabase with cookie-based SSR (next/supabase), add origin checks
export async function middleware(req: NextRequest) {
  if (req.method !== 'GET' && !verifyOrigin(req)) {
    return new Response('Forbidden', { status: 403 })
  }
}
```

## Key Rules

- Never implement state-changing actions as GET requests — GET is allowed by SameSite=Lax and bookmark/prefetch-safe.
- Origin header check is simpler than CSRF tokens and sufficient for most cases — verify `Origin === siteUrl` on all POST/PUT/DELETE.
- `SameSite=Strict` on session cookies blocks CSRF entirely but breaks OAuth redirect flows — `SameSite=Lax` + origin check is the right balance.
- Server Actions in Next.js App Router include implicit same-origin validation for action URLs — but API routes (`app/api/`) do not.
- Never disable CSRF protection "just for tests" — the habit carries to production.
