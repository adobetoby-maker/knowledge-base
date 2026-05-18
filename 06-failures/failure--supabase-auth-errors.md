# Supabase Auth Common Failures

## 1. getSession() vs getUser() Security Vulnerability

**Symptom:** Auth check passes for tampered/expired sessions. Users retain access after logout.

**Cause:** `getSession()` reads the session from the cookie without re-validating it against Supabase Auth servers. A modified cookie passes this check.

```typescript
// INSECURE — trusts client-controlled cookie
const { data: { session } } = await supabase.auth.getSession()
if (!session) redirect('/login')
// session could be a modified/expired token that still has the right shape

// SECURE — validates against Supabase Auth servers
const { data: { user } } = await supabase.auth.getUser()
if (!user) redirect('/login')
// user is null if the token is invalid, expired, or tampered
```

**Fix:** Replace ALL `getSession()` auth checks with `getUser()`.

## 2. Auth State Lost After Hard Refresh

**Symptom:** User is logged in, refreshes the page, gets redirected to login.

**Cause 1:** The middleware is not refreshing the session cookie. Sessions expire and need periodic refreshing.

**Cause 2:** Using the browser client (`lib/supabase/client.ts`) in a Server Component — the cookie isn't being forwarded.

**Fix for middleware:**
```typescript
// middleware.ts — must use createServerClient with req/res cookie access
import { createServerClient } from '@supabase/ssr'

export async function middleware(req: NextRequest) {
  const response = NextResponse.next({ request: req })
  
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => req.cookies.getAll(),
      setAll: (cookiesToSet) => {
        cookiesToSet.forEach(({ name, value, options }) => {
          req.cookies.set(name, value)
          response.cookies.set(name, value, options)
        })
      },
    },
  })
  
  // This call refreshes the session — REQUIRED
  await supabase.auth.getUser()
  
  return response
}
```

Without calling `supabase.auth.getUser()` in middleware, sessions expire and don't refresh.

## 3. Redirect Loop After Login

**Symptom:** Logging in redirects back to login page immediately.

**Cause:** The user is being redirected to login because `getUser()` returns null, even though they just logged in. This usually means the session cookie isn't being set on the redirect response.

**Debug steps:**
1. Check the Network tab in browser DevTools — is the `Set-Cookie` header present on the login response?
2. Check if the middleware matcher excludes `/login` (it should)
3. Check if the Supabase client in the login handler is the server client (not the browser client)

## 4. Email Confirmation Not Working

**Symptom:** User signs up, never receives confirmation email. Or: confirmation link leads to "Invalid token" error.

**Cause 1:** Email templates not configured in Supabase Auth settings.
**Cause 2:** `NEXT_PUBLIC_SITE_URL` not set — confirmation links use the wrong domain.
**Cause 3:** Link clicked after 24-hour expiry (default).

**Fix:**
```typescript
// In your auth callback:
// app/auth/callback/route.ts
export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const code = searchParams.get('code')
  
  if (code) {
    const supabase = createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }
  
  return NextResponse.redirect(new URL('/portal/dashboard', req.url))
}
```

Set `NEXT_PUBLIC_SITE_URL` in Vercel environment variables to your production domain. Supabase uses this to build the confirmation link.

## 5. OAuth Callback URL Mismatch

**Symptom:** Google/GitHub login returns "Redirect URI mismatch" error.

**Cause:** The callback URL registered in the OAuth provider (Google Cloud Console, GitHub OAuth app) doesn't match the one Supabase sends.

**Fix:**
1. In Supabase dashboard → Auth → Providers → [Provider] → note the Callback URL
2. Add EXACTLY this URL to the OAuth provider's allowed redirect URIs
3. For Google: `https://[PROJECT_REF].supabase.co/auth/v1/callback`

## 6. Row-Level Security Blocks Authenticated User

**Symptom:** Authenticated user gets empty results or 403 when RLS should allow access.

**Cause:** Using the server Supabase client with correct auth context but the RLS policy uses `auth.uid()` which returns null when the server client doesn't have the user's JWT.

**Debug:**
```sql
-- Check if the policy uses auth.uid() correctly
SELECT auth.uid();  -- run as the authenticated user
-- If this returns null from a server context, the JWT isn't being passed
```

**Fix:** The server client must be initialized with the user's cookie for RLS to work:
```typescript
import { createClient } from '@/lib/supabase/server'
// This version reads cookies and passes the JWT to Supabase
const supabase = createClient()
// NOT createAdminClient() — that bypasses JWT context
```

## 7. Multiple Auth Listeners Leaking

**Symptom:** Auth state changes trigger multiple callbacks. Console shows multiple "user logged in" logs.

**Cause:** `supabase.auth.onAuthStateChange()` listener added in a component without cleanup.

```typescript
// WRONG: leaks listener on component remount
useEffect(() => {
  supabase.auth.onAuthStateChange((event, session) => {
    // ...
  })
}, [])

// CORRECT: unsubscribe on cleanup
useEffect(() => {
  const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
    // ...
  })
  return () => subscription.unsubscribe()
}, [])
```
