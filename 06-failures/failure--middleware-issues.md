# Next.js Middleware Common Failures

## What Middleware Does

`middleware.ts` at the project root runs on EVERY matched request BEFORE the page or route handler renders. It's used for:
- Auth redirects (redirect unauthenticated users to login)
- Locale routing
- Security headers
- Rate limiting (with Edge-compatible libraries like Upstash)

## 1. Infinite Redirect Loop

**Symptom:** Browser shows "too many redirects" error, or Chrome's "ERR_TOO_MANY_REDIRECTS".

**Cause:** Middleware redirects to a page that itself is matched by the middleware, which redirects again.

```typescript
// CAUSES INFINITE LOOP
export async function middleware(req: NextRequest) {
  const session = await getSession(req)
  if (!session) {
    return NextResponse.redirect(new URL('/login', req.url))
  }
}

// No matcher config → runs on /login too → /login redirects to /login → infinite loop
```

**Fix:** Exclude public routes from the matcher:
```typescript
export const config = {
  matcher: [
    // Exclude: api routes, static files, _next, login, register
    '/((?!api|_next/static|_next/image|favicon.ico|login|register|public).*)',
  ],
}
```

Or check inside middleware:
```typescript
export async function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl
  
  // Don't run auth check on public routes
  if (pathname.startsWith('/login') || pathname.startsWith('/api/auth')) {
    return NextResponse.next()
  }
  
  // ... rest of auth logic
}
```

## 2. Middleware Not Running on Expected Routes

**Symptom:** Auth check in middleware isn't running, unauthenticated users can access protected pages.

**Cause 1:** Matcher pattern doesn't include the route.
**Cause 2:** Middleware.ts is in the wrong location (must be at project root, not in `/app/`).
**Cause 3:** Multiple middleware files (only one is allowed).

**Check:**
```bash
# Middleware must be at project root (same level as app/, not inside it)
ls middleware.ts     # correct
ls app/middleware.ts # wrong
```

**Debug the matcher:**
```typescript
export async function middleware(req: NextRequest) {
  console.log('Middleware running on:', req.nextUrl.pathname)  // check this in logs
  // ...
}
```

## 3. Session Not Available in Middleware (Supabase)

**Symptom:** `supabase.auth.getUser()` returns null even for logged-in users.

**Cause:** The Supabase server client in middleware must use the middleware-specific `createServerClient` with `req/res` cookie access pattern.

```typescript
// WRONG in middleware.ts
import { createClient } from '@/lib/supabase/server'  // this uses `cookies()` from next/headers
// cookies() doesn't work in middleware!

// CORRECT in middleware.ts
import { createServerClient } from '@supabase/ssr'

export async function middleware(req: NextRequest) {
  const response = NextResponse.next({ request: req })
  
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => req.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            req.cookies.set(name, value)
            response.cookies.set(name, value, options)
          })
        },
      },
    }
  )
  
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user && req.nextUrl.pathname.startsWith('/portal')) {
    return NextResponse.redirect(new URL('/login', req.url))
  }
  
  return response
}
```

## 4. Edge Runtime Limitations

Middleware runs in the Edge Runtime by default. Some Node.js APIs aren't available.

**Not available in middleware:**
- `fs` (filesystem)
- `path` (path.join with OS-specific separators)
- Most Node.js built-ins
- Some npm packages that depend on Node.js

**Available:**
- `fetch` (native)
- `Response`, `Request`, `Headers`, `URL`
- `crypto.subtle`
- Web APIs (TextEncoder, Blob, etc.)

If you need Node.js APIs in middleware, you'd need to use a Route Handler instead of middleware for that logic.

## 5. Rate Limiting in Middleware

Use Upstash Redis (Edge-compatible) for rate limiting in middleware:

```typescript
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(100, '1 m'),
})

export async function middleware(req: NextRequest) {
  const ip = req.headers.get('x-forwarded-for') ?? '127.0.0.1'
  const { success } = await ratelimit.limit(ip)
  
  if (!success) {
    return new NextResponse('Too Many Requests', { status: 429 })
  }
  
  return NextResponse.next()
}
```

Note: `@upstash/ratelimit` and `@upstash/redis` are Edge-compatible. Many other Redis clients (ioredis) are NOT.
