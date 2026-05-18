# Failure: Infinite Redirect Loop in Next.js Middleware

## What Causes a Redirect Loop

Middleware runs on every matched request. A redirect loop happens when the middleware redirects to a URL that the middleware also matches — sending the browser through the same redirect again. The browser hits the redirect limit (usually 20 hops) and shows an error: "Too many redirects" or "ERR_TOO_MANY_REDIRECTS."

The most common cause: authentication middleware that redirects unauthenticated users to `/login`, but the middleware matcher also matches `/login`. The unauthenticated request hits `/login`, the middleware sees no session, redirects to `/login`... forever.

```typescript
// middleware.ts — BROKEN
export function middleware(request: NextRequest) {
  const session = request.cookies.get("session");
  if (!session) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
}

// matcher matches everything including /login
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

## How to Exclude Auth Routes From the Matcher

The matcher is the first line of defense. Exclude public routes at the pattern level so middleware doesn't run on them at all:

```typescript
// middleware.ts — FIXED via matcher
export const config = {
  matcher: [
    /*
     * Match all request paths EXCEPT:
     * - /login, /signup, /forgot-password (auth pages)
     * - /_next/* (Next.js internals)
     * - /api/auth/* (auth API routes)
     * - static files (favicon, images)
     */
    "/((?!login|signup|forgot-password|_next/static|_next/image|favicon.ico|api/auth).*)",
  ],
};
```

Alternatively, check the path inside middleware before redirecting:

```typescript
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Explicitly skip auth pages
  const publicPaths = ["/login", "/signup", "/forgot-password", "/api/auth"];
  if (publicPaths.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  const session = request.cookies.get("session");
  if (!session) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
}
```

Both approaches work; using the matcher is more performant (middleware doesn't run at all) but the inline check is more explicit and easier to audit.

## Other Loop Causes

**Role-based redirect loops** — user is authenticated but doesn't have the right role. Middleware redirects to `/unauthorized`. The `/unauthorized` route is protected. Loop.

**Redirect target itself protected** — middleware redirects to `/onboarding` to force profile completion. `/onboarding` is matched by the middleware. If the onboarding check also runs on `/onboarding`, you loop.

**Mismatched session cookie domain** — middleware sets/reads a cookie with a domain mismatch. Cookies never persist. Every request looks unauthenticated. Every request redirects.

## Debugging With Console Logs in Middleware

Middleware runs on the server (Edge runtime). Its `console.log` output appears in the terminal running `next dev` (or Vercel's function logs, not the browser console).

```typescript
export function middleware(request: NextRequest) {
  console.log("[middleware] path:", request.nextUrl.pathname);
  console.log("[middleware] session cookie:", request.cookies.get("session")?.value);

  const session = request.cookies.get("session");
  if (!session) {
    console.log("[middleware] no session, redirecting to /login");
    return NextResponse.redirect(new URL("/login", request.url));
  }

  console.log("[middleware] session found, passing through");
  return NextResponse.next();
}
```

Watch the terminal while loading the page. If you see the same path logged repeatedly, that's your loop. If the session shows `undefined` when it should exist, that's a cookie issue.

## Key Rules

- **Always exclude the login/signup pages from the auth middleware matcher** — this is the most common loop cause.
- **Exclude your redirect target from the middleware that triggers the redirect** — redirecting to a protected page causes an immediate loop.
- **Use `console.log` in middleware during debugging** — the browser devtools show the redirect chain, but the terminal shows the middleware perspective.
- **Check cookie domain and path** when sessions appear to not persist — `localhost` vs `127.0.0.1` can cause cookies to not match.
- **Test middleware in isolation** — a middleware unit test with mock requests is faster than debugging live browser loops.
- **Be explicit about public routes** — an allowlist of public paths is safer than a blocklist of private paths.
