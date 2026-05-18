# Stack Bundle: Supabase Auth Context

This bundle provides the complete auth pattern used across jrs-auto-repair and silver-creek-logistics. Load this before working on any auth-related code.

## Auth System Selection

Two completely separate auth systems — NEVER mix them:

| Area | System | Cookie/Token | Validation Function |
|---|---|---|---|
| `/admin/*` routes | Cookie-based admin auth | `admin_session` cookie | `validateAdminSession()` |
| `/portal/*` routes | Supabase JWT | Supabase cookie | `supabase.auth.getUser()` |

## Admin Auth (Cookie-Based)

```typescript
// lib/adminAuth.ts
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import crypto from 'crypto'

interface AdminSession {
  id: string
  email: string
  name: string
}

function signSession(data: AdminSession, secret: string): string {
  const json = JSON.stringify(data)
  const encoded = Buffer.from(json).toString('base64')
  const sig = crypto.createHmac('sha256', secret).update(encoded).digest('hex')
  return `${encoded}.${sig}`
}

function verifySession(token: string, secret: string): AdminSession | null {
  const [encoded, sig] = token.split('.')
  if (!encoded || !sig) return null
  
  const expectedSig = crypto.createHmac('sha256', secret).update(encoded).digest('hex')
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expectedSig))) return null
  
  try {
    return JSON.parse(Buffer.from(encoded, 'base64').toString())
  } catch {
    return null
  }
}

export async function validateAdminSession(): Promise<AdminSession> {
  const cookieStore = await cookies()
  const token = cookieStore.get('admin_session')?.value
  
  if (!token) redirect('/admin/login')
  
  const session = verifySession(token, process.env.ADMIN_SECRET!)
  if (!session) redirect('/admin/login')
  
  return session
}

export async function createAdminSession(session: AdminSession): Promise<void> {
  const cookieStore = await cookies()
  const token = signSession(session, process.env.ADMIN_SECRET!)
  
  cookieStore.set('admin_session', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 8 * 60 * 60,  // 8 hours
    path: '/',
  })
}
```

## Portal Auth (Supabase JWT)

```typescript
// lib/supabase/server.ts
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export function supabaseServer() {
  const cookieStore = cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: (cs) => cs.forEach(({ name, value, options }) => cookieStore.set(name, value, options)) } }
  )
}

// In a protected Server Component:
export async function getPortalUser() {
  const supabase = supabaseServer()
  const { data: { user }, error } = await supabase.auth.getUser()  // NOT getSession()
  if (error || !user) redirect('/login')
  return user
}
```

## Three Supabase Clients

```typescript
// BROWSER CLIENT (src/lib/supabase/client.ts):
// - Use in Client Components
// - Auth handled by browser cookies
import { createBrowserClient } from '@supabase/ssr'
export const supabaseBrowser = () => createBrowserClient(url, anonKey)

// SERVER CLIENT (src/lib/supabase/server.ts):
// - Use in Server Components, Route Handlers, Server Actions
// - Reads auth from request cookies
export const supabaseServer = () => createServerClient(url, anonKey, { cookies })

// ADMIN CLIENT (src/lib/supabase/admin.ts):
// - NEVER import from any client-accessible file
// - Uses service role key — bypasses ALL RLS
// - Only for admin operations and server functions that need elevated access
import { createClient } from '@supabase/supabase-js'
export const supabaseAdmin = () => createClient(url, serviceRoleKey)
```

## Auth Decision Tree

```
Is this route /admin/*?
  → Use validateAdminSession() — admin cookie auth
  
Is this route /portal/*?
  → Use supabase.auth.getUser() — Supabase JWT

Is this a Server Action modifying user data?
  → Use supabaseServer() to get user
  → Use supabaseAdmin() to perform the actual operation (if RLS would block it)
  
Never:
  → import supabaseAdmin from a page component
  → call getSession() instead of getUser() for security checks
  → mix admin cookie auth with Supabase JWT in the same route
```

## getUser() vs getSession()

Always `getUser()`:
```typescript
// CORRECT — validates JWT against Supabase server:
const { data: { user } } = await supabase.auth.getUser()

// WRONG — trusts client-controlled cookie, can be spoofed:
const { data: { session } } = await supabase.auth.getSession()
```

`getSession()` reads the session from the cookie without re-validating against the Supabase server. A tampered cookie would pass `getSession()` but fail `getUser()`.
