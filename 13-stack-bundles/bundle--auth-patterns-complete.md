# Bundle: Auth Patterns Complete

## Context

Complete auth implementation reference for projects using Supabase Auth. Covers: signup, login, OAuth, magic link, session management, protected routes, and admin auth. Cross-references all auth-related files.

## Auth Architecture Decision

Choose your auth model first:

**Option A: Supabase Auth only** (most projects)
- All users authenticated via Supabase JWT
- RLS handles data access automatically
- Single client type: `supabase.auth.getUser()`
- Use when: SaaS, portals, apps with user accounts

**Option B: Dual auth** (jrs-auto-repair, silver-creek pattern)
- Supabase JWT for customer-facing portal
- Cookie-based for internal admin
- Two completely separate middleware paths
- Use when: internal admin needs different access than public users

**Never mix the two systems** — different session types are checked differently. Admin cookie checked with `validateAdminSession()`, portal JWT checked with `supabase.auth.getUser()`.

## Server Client Configuration

```ts
// lib/supabase/server.ts — Server Components, Route Handlers
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export function createClient() {
  const cookieStore = cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cookiesToSet) => {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {
            // Server Component — cookies set in middleware
          }
        },
      },
    }
  )
}

// lib/supabase/admin.ts — Service role, server-only
import { createClient } from '@supabase/supabase-js'
import 'server-only'

export const adminSupabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,  // Never NEXT_PUBLIC
  { auth: { persistSession: false } }
)
```

## Middleware

```ts
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          response = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  // Always refresh session — required for Supabase SSR
  const { data: { user } } = await supabase.auth.getUser()

  // Protect routes
  if (request.nextUrl.pathname.startsWith('/portal') && !user) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api/auth).*)'],
}
```

## Login Page

```tsx
// app/login/page.tsx
'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const supabase = createClient()
  const router = useRouter()

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError('')

    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setLoading(false)

    if (error) {
      setError(error.message)
      return
    }

    router.push('/portal/dashboard')
    router.refresh()  // Refresh Server Components to pick up new session
  }

  return (
    <form onSubmit={handleLogin} className="space-y-4 max-w-sm mx-auto mt-20">
      <h1 className="text-2xl font-bold">Sign In</h1>
      <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required
        className="w-full px-3 py-2 border rounded-lg" placeholder="Email" />
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required
        className="w-full px-3 py-2 border rounded-lg" placeholder="Password" />
      {error && <p className="text-red-600 text-sm">{error}</p>}
      <button type="submit" disabled={loading}
        className="w-full py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
        {loading ? 'Signing in...' : 'Sign In'}
      </button>
    </form>
  )
}
```

## OAuth Login

```tsx
async function loginWithGoogle() {
  const supabase = createClient()
  await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: `${window.location.origin}/auth/callback`,
    },
  })
}

// app/auth/callback/route.ts
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  const next = searchParams.get('next') ?? '/portal/dashboard'

  if (code) {
    const supabase = createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }

  return NextResponse.redirect(`${origin}${next}`)
}
```

## Getting the Current User

```ts
// In Server Components and Route Handlers — always use getUser()
const { data: { user }, error } = await supabase.auth.getUser()

// NEVER use getSession() for auth checks — it trusts client-side cookie without server validation
// getSession() is only for reading session metadata after you've already validated the user
```

## Signup with Profile Creation

```ts
// app/api/signup/route.ts
export async function POST(req: Request) {
  const { email, password, name } = await req.json()
  const supabase = createClient()

  const { data, error } = await supabase.auth.signUp({
    email, password,
    options: { data: { name } },  // Stored in user_metadata
  })

  if (error) return Response.json({ error: error.message }, { status: 400 })

  // Profile row created via database trigger:
  // CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  // FOR EACH ROW EXECUTE FUNCTION handle_new_user();

  return Response.json({ success: true })
}
```

## Sign Out

```ts
// Client Component
const supabase = createClient()
await supabase.auth.signOut()
router.push('/login')
router.refresh()

// Server Action
'use server'
export async function signOut() {
  const supabase = createClient()
  await supabase.auth.signOut()
  redirect('/login')
}
```

## Related Files

- `skill--protected-routes.md` — Route-level auth guards
- `skill--social-login.md` — Multi-provider OAuth
- `skill--magic-link-auth.md` — Passwordless login
- `skill--two-factor-auth.md` — TOTP 2FA
- `skill--role-permissions.md` — Role-based access control
- `failure--auth-bypass-patterns.md` — Common auth security mistakes
- `patterns--auth--two-system-pattern.md` — Dual auth system (admin + portal)
