# Failure: Next.js Middleware Running Where It Shouldn't

## Why Middleware Matching Matters

Next.js middleware runs on every matched request at the edge before any route handler, RSC render, or static file response. If the matcher is too broad, middleware executes on `_next/static` asset requests, image optimization requests, and API routes — adding latency, running auth checks on public assets, and potentially breaking static delivery. On Vercel's edge network, every unnecessary middleware invocation costs compute time and can exhaust request budgets.

The default (no `matcher` config) matches every route including static assets. This is almost never what you want.

## The Negative Lookahead Pattern

The most reliable way to exclude Next.js internals and static files from auth middleware:

```ts
export const config = {
  matcher: [
    /*
     * Match all request paths EXCEPT:
     * - _next/static  (static files)
     * - _next/image   (image optimization)
     * - favicon.ico   (browser default favicon request)
     * - Files with extensions (js, css, png, etc.)
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|css|js)$).*)',
  ],
};
```

The negative lookahead `(?!...)` inside the capturing group excludes those paths while matching everything else. The trailing `.*\\.ext$` pattern catches any static file by extension.

Why not just list protected paths explicitly? Because you'd have to remember to add every new authenticated route to the list. Blocklist (exclude known public paths) is safer than allowlist (include known private paths) — a forgotten route on a blocklist is slightly exposed; a forgotten route on an allowlist is entirely blocked.

## Excluding API Routes From Auth Middleware

Some API routes handle webhooks (Stripe, GitHub) that come without auth tokens. Middleware that intercepts these and redirects to login breaks the webhook:

```ts
matcher: [
  '/((?!_next/static|_next/image|favicon.ico|api/webhooks|api/health).*)',
],
```

Or use matcher with multiple entries — each entry is OR'd:

```ts
matcher: [
  '/dashboard/:path*',
  '/account/:path*',
  '/admin/:path*',
],
```

Explicit route prefixes work well when the protected surface is bounded and stable.

## Checking Auth vs. Redirecting in Middleware

Middleware should check auth state cheaply and redirect — it should not fetch database records. The edge runtime has limited Node.js API surface; avoid Prisma, heavy ORMs, or file system reads. For Supabase or JWT auth, verify the session cookie/token at the edge.

```ts
export async function middleware(request: NextRequest) {
  const token = request.cookies.get('session')?.value;
  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  // Verify JWT signature only — no DB call
  const valid = await verifyJWT(token, process.env.JWT_SECRET!);
  if (!valid) {
    return NextResponse.redirect(new URL('/login', request.url));
  }
  return NextResponse.next();
}
```

## Common Mistakes

- **Matching `api/` routes with auth middleware** — breaks public endpoints and webhooks
- **No file extension exclusion** — middleware runs on every `.js` chunk load, adding hundreds of edge invocations per page
- **Using `matcher: ['/']` and expecting it to match sub-paths** — `/` only matches the root. Use `'/:path*'` or `'/(.*)'`
- **Redirecting to an absolute URL without the origin** — causes redirect loop if middleware matches the redirect target

## Key Rules

- Always configure `config.matcher` — never rely on the default catch-all
- Exclude `_next/static`, `_next/image`, and file extensions as a baseline
- Exclude webhook and public API routes explicitly
- Do no database work in middleware — validate tokens cryptographically only
- Test middleware behavior with `curl` against static asset URLs to confirm they are not intercepted
- Use negative lookahead blocklist over explicit allowlist for auth-protected sections
