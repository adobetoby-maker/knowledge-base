# Stack Bundle: Next.js + Supabase Auth Full Setup

## When to Load This Bundle

Load this bundle when: implementing auth from scratch, debugging auth issues, or adding auth to a new route. This replaces reading 5-8 separate files.

---

## 1. Package Setup

```bash
npm install @supabase/supabase-js @supabase/ssr
```

## 2. Three Client Files (Copy These Exactly)

### lib/supabase/client.ts (Browser)
```typescript
import { createBrowserClient } from '@supabase/ssr'
export const createClient = () =>
  createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!)
```

### lib/supabase/server.ts (Server)
```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
export const createClient = async () => {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: (cs) => cs.forEach(({ name, value, options }) => cookieStore.set(name, value, options)) } }
  )
}
```

### lib/supabase/admin.ts (Service Role — SERVER ONLY)
```typescript
import { createClient } from '@supabase/supabase-js'
export const supabaseAdmin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)
```

**NEVER import admin.ts in a client component. NEVER use NEXT_PUBLIC_ prefix for SUPABASE_SERVICE_ROLE_KEY.**

## 3. Middleware (Session Refresh)

```typescript
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextRequest, NextResponse } from 'next/server'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cs) => cs.forEach(({ name, value, options }) => {
          request.cookies.set(name, value)
          supabaseResponse.cookies.set(name, value, options)
        })
      }
    }
  )
  
  // CRITICAL: must call getUser() to refresh session
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user && request.nextUrl.pathname.startsWith('/portal')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }
  
  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|login|api/auth).*)']
}
```

## 4. Login Page

```typescript
// app/login/page.tsx
'use client'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  const supabase = createClient()
  
  const handleLogin = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (!error) window.location.href = '/portal/dashboard'
  }
  
  // ... form JSX
}
```

## 5. Auth Callback Route

```typescript
// app/auth/callback/route.ts
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const url = new URL(request.url)
  const code = url.searchParams.get('code')
  
  if (code) {
    const supabase = await createClient()
    await supabase.auth.exchangeCodeForSession(code)
  }
  
  return NextResponse.redirect(new URL('/portal/dashboard', request.url))
}
```

## 6. Protected Route Pattern

```typescript
// app/portal/layout.tsx
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function PortalLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()  // getUser(), NOT getSession()
  
  if (!user) redirect('/login')
  
  return <div>{children}</div>
}
```

## 7. The Four Critical Rules

1. **getUser() not getSession()** — getSession() trusts a client-controlled cookie; getUser() verifies with the server.
2. **middleware must call getUser()** — without it, sessions expire and users get logged out randomly.
3. **Three separate client files** — never use the admin client where a user client should be used.
4. **Two auth systems in jrs-auto-repair and silver-creek** — admin cookie for /admin, Supabase JWT for /portal. Never cross.

## 8. Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY     ← never NEXT_PUBLIC_
```
