# Supabase Auth — Common Failures

## Infinite Redirect Loop

**Symptom:** Browser cycles between /login and protected route infinitely

**Cause:** Middleware `matcher` includes the login route itself, or the auth check throws an error that causes all routes to redirect.

**Fix:**
```typescript
// middleware.ts
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|login|api/auth).*)',
  ]
}
```

Always exclude: static files, image optimization routes, the login page, and auth callback routes.

## Session Not Persisting on Refresh

**Symptom:** User appears logged in, refreshes page, session is gone

**Cause 1:** Using the browser client where the server client should be used. Browser client persists in localStorage; server client reads from cookies. If they get out of sync, the server thinks the user is logged out.

**Cause 2:** Missing session refresh in middleware.

**Fix:** Middleware must refresh the session on every request:
```typescript
import { createServerClient } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request: { headers: request.headers } })
  
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get: name => request.cookies.get(name)?.value,
        set: (name, value, options) => {
          request.cookies.set({ name, value, ...options })
          response.cookies.set({ name, value, ...options })
        },
        remove: (name, options) => {
          request.cookies.set({ name, value: '', ...options })
          response.cookies.set({ name, value: '', ...options })
        },
      },
    }
  )
  
  // This refresh call is mandatory
  await supabase.auth.getUser()
  
  return response
}
```

## getSession() Returns null After Signup

**Symptom:** User signs up successfully, but `getSession()` returns null immediately after

**Cause:** Email confirmation is enabled in Supabase dashboard. User must confirm email before session is established.

**Fix:** Either disable email confirmation (development only) in Supabase dashboard → Auth → Email → Enable email confirmations, OR redirect to a "check your email" page after signup.

## OAuth Callback Fails

**Symptom:** After OAuth login, user is redirected to the callback URL but session is not created; redirected to login again

**Cause:** The callback route handler is not completing the code exchange:

```typescript
// app/auth/callback/route.ts
import { createServerClient } from '@supabase/ssr'

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  
  if (code) {
    const supabase = createServerClient(/* ... */)
    await supabase.auth.exchangeCodeForSession(code)  // this step must happen
  }
  
  return NextResponse.redirect(new URL('/dashboard', request.url))
}
```

**Also check:** The callback URL in your OAuth provider settings matches exactly (including trailing slash, protocol) to what Supabase expects.

## Row Level Security Returning Empty

**Symptom:** Query returns `{ data: [], error: null }` — no error, just no data

**Cause:** RLS policy does not allow the current user to see these rows. The policy is working correctly — the symptom means the query succeeded but matched zero rows per the policy.

**Diagnosis:**
```sql
-- In Supabase SQL editor:
SELECT * FROM pg_policies WHERE tablename = 'your_table';

-- Test with the user's ID:
SET request.jwt.claims = '{"sub": "user-uuid-here"}';
SELECT * FROM your_table;
```

**Fix:** Either update the RLS policy to allow the access, or check that the user is authenticated when the query runs.

## JWT Expired Mid-Session

**Symptom:** API route returns 401 after user has been active for a while

**Cause:** JWT expired (default: 1 hour). If middleware is not refreshing, the token becomes stale.

**Fix:** The middleware session refresh (see above) handles token refresh automatically. If you're not using middleware, manually refresh:
```typescript
const { data: { session } } = await supabase.auth.getSession()
// This auto-refreshes if expired
```

## getSession() vs getUser() — Security Issue

`getSession()` trusts the JWT stored in the cookie without server-side verification.
`getUser()` verifies the JWT with Supabase Auth servers.

In middleware and Route Handlers: use `getUser()`. An attacker with a modified cookie can fool `getSession()` but not `getUser()`.

```typescript
// Wrong — can be spoofed
const { data: { session } } = await supabase.auth.getSession()
if (!session) redirect('/login')

// Correct — verified server-side
const { data: { user } } = await supabase.auth.getUser()
if (!user) redirect('/login')
```
