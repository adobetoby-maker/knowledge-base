# Next.js — Middleware

**When:** You need to run logic on every request before a page renders: auth redirects, geo-routing, A/B testing, rate limiting.
**Rule:** Middleware is powerful but expensive — keep it fast and narrow. Every millisecond of middleware adds to TTFB.

## What Middleware Can Do
- Redirect or rewrite requests before they hit the page
- Modify request/response headers
- Read cookies (but not write complex state)
- Geo-routing (Vercel provides country/city in headers)
- Auth redirect (check for cookie, redirect to login if missing)

## What Middleware Cannot Do
- Access the filesystem
- Run heavy computation (adds to every request)
- Make slow external API calls (blocks the request)
- Use Node.js-specific APIs (runs on Vercel Fluid Compute, which is edge-compatible)

## File Location
```
middleware.ts   (at project root, same level as app/)
```

## Auth Redirect Pattern (most common use)
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Protect admin routes
  if (pathname.startsWith('/admin') && !pathname.startsWith('/admin/login')) {
    const session = request.cookies.get('admin_session')
    if (!session) {
      return NextResponse.redirect(new URL('/admin/login', request.url))
    }
  }

  return NextResponse.next()
}

// Narrow the matcher — don't run on static files or API routes you don't need
export const config = {
  matcher: ['/admin/:path*', '/portal/:path*']
}
```

## Geo-Routing Pattern (Vercel)
```typescript
import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  const country = request.geo?.country || 'US'

  // Rewrite to country-specific content
  if (country === 'BR') {
    return NextResponse.rewrite(new URL('/pt' + request.nextUrl.pathname, request.url))
  }

  return NextResponse.next()
}
```

## The Matcher — Keep It Narrow
Without a matcher, middleware runs on EVERY request including `_next/static`, images, favicons.
Always define a matcher:
```typescript
export const config = {
  matcher: [
    // Match specific paths
    '/admin/:path*',
    // Exclude static files
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ]
}
```

## Performance Rule
Middleware runs on every matched request. If it does anything slow (DB lookup, API call), users feel it.
For auth: read a cookie (fast) not validate a session (slow).
Do the full session validation in the page/route handler after the redirect check.
