# Auth Pattern — Two-System Architecture (Cookie Admin + Supabase JWT)

**When:** A site needs both an admin panel (internal) and a customer portal (external).
**Rule:** Keep the two auth systems completely separate. Different cookies, different validation paths, different redirects. Never use one to check the other.

## Why Two Systems
- **Admin panel** — internal tool, you control who has access via a static JSON file. Cookie-based, lightweight.
- **Customer portal** — external users, needs account creation, password reset, OAuth. Supabase handles this.
- Mixing them creates security holes: if admin cookie is compromised, does it affect customer data? It shouldn't.

## System 1: Cookie Admin Auth

### The Cookie
```typescript
// Name: admin_session
// Value: HMAC-signed JSON with expiry, signed by ADMIN_SECRET env var
// Flags: httpOnly, secure, sameSite: strict
```

### Checking Admin Auth (lib/adminAuth.ts pattern)
```typescript
import { cookies } from 'next/headers'
import crypto from 'crypto'

export async function verifyAdmin(): Promise<AdminUser | null> {
  const cookieStore = await cookies()
  const session = cookieStore.get('admin_session')
  if (!session) return null

  try {
    // Verify HMAC signature
    const [payload, sig] = session.value.split('.')
    const expected = crypto
      .createHmac('sha256', process.env.ADMIN_SECRET!)
      .update(payload)
      .digest('base64url')
    if (sig !== expected) return null

    const data = JSON.parse(Buffer.from(payload, 'base64url').toString())
    if (data.expires < Date.now()) return null

    return data.user
  } catch {
    return null
  }
}
```

### Admin File (data/admins.json)
```json
[
  { "username": "admin", "passwordHash": "bcrypt-hash-here" }
]
```

## System 2: Supabase JWT Portal Auth

### Checking Portal Auth
```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function getPortalUser() {
  const cookieStore = await cookies()
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: (c) => c.forEach(({ name, value, options }) => cookieStore.set(name, value, options)) } }
  )
  const { data: { user } } = await supabase.auth.getUser()
  return user
}
```

## Never Mix
```typescript
// WRONG — using Supabase session to check admin status
const { data: { user } } = await supabase.auth.getUser()
if (user?.email === 'admin@example.com') { /* admin logic */ }
// This ties admin access to Supabase being up and to email being correct in their db

// RIGHT — completely separate check
const admin = await verifyAdmin()  // checks admin_session cookie only
if (!admin) redirect('/admin/login')
```

## Route Structure
```
/admin/*     → always check admin cookie via verifyAdmin()
/portal/*    → always check Supabase JWT via getPortalUser()
/(site)/*    → public, no auth check
```

## The Redirect Pattern
```typescript
// In every admin page (or in middleware)
const admin = await verifyAdmin()
if (!admin) redirect('/admin/login')

// In every portal page
const user = await getPortalUser()
if (!user) redirect('/portal/login')
```
