# Failure: Supabase Auth Cookie Not Working

**Symptom:** User is logged in (can see it in Supabase dashboard), but `getUser()` returns null on the server. Or: auth works on first load but breaks after refresh. Or: middleware redirects even after successful login.

## Why Auth Cookies Break

### Problem 1 — Wrong Supabase Client for SSR
```typescript
// WRONG in Server Component or Route Handler
import { createClient } from '@/lib/supabase/client'  // browser client, can't read cookies

// RIGHT in Server Component / Route Handler / Server Action
import { createClient } from '@/lib/supabase/server'  // cookie-based SSR client
```

### Problem 2 — Not Awaiting Cookies
In Next.js 15+, `cookies()` returns a Promise:
```typescript
// WRONG (Next.js 15+)
import { cookies } from 'next/headers'
const cookieStore = cookies()  // not awaited

// RIGHT
const cookieStore = await cookies()
```

### Problem 3 — getSession() vs getUser()
```typescript
// WRONG for security checks — getSession() trusts the client-controlled cookie
const { data: { session } } = await supabase.auth.getSession()
if (!session) redirect('/login')  // can be spoofed

// RIGHT — getUser() re-validates with Supabase servers
const { data: { user }, error } = await supabase.auth.getUser()
if (!user) redirect('/login')  // cryptographically verified
```

### Problem 4 — SSR Client Not Configured to Read/Write Cookies
The server client needs explicit cookie config:
```typescript
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()
  
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch { /* middleware handles refresh */ }
        }
      }
    }
  )
}
```

### Problem 5 — Middleware Not Refreshing Session
Without middleware refreshing the Supabase token, sessions expire silently:
```typescript
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse } from 'next/server'

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (cookies) => cookies.forEach(({ name, value, options }) => {
        request.cookies.set({ name, value })
        response.cookies.set({ name, value, ...options })
      })
    }
  })
  
  await supabase.auth.getUser()  // refreshes token if needed
  return response
}
```

## Diagnostic Steps
1. Log `cookieStore.getAll()` — do auth cookies exist?
2. Call `supabase.auth.getUser()` and log the error — is it an expired token or missing cookie?
3. Check which client is being used — server or browser?
4. Check middleware is running on the route (middleware.ts matcher config)
