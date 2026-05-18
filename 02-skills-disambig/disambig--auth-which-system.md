# Disambiguation: Which Auth System?

## The Core Question

Before writing any auth-related code, answer: which of the two auth systems does this route use?

The answer comes from the URL prefix:
- Routes under `/admin/*` → Admin cookie auth
- Routes under `/portal/*` → Supabase JWT auth
- Public routes → No auth

This is not a choice to be made — it is an established pattern that must be followed.

## System 1: Admin Cookie Auth

**Used for:** Internal admin interface (`/admin/*`)
**User base:** Pablo (the shop owner) and explicitly authorized admins
**Token:** Cookie `admin_session` signed with `ADMIN_SECRET`
**User records:** `data/admins.json`
**Guard function:** `verifyAdmin(request)` in `lib/adminAuth.ts`

```typescript
// Correct admin route protection
import { verifyAdmin } from '@/lib/adminAuth'

export default async function AdminPage() {
  const admin = await verifyAdmin()
  if (!admin) redirect('/login')
  // ...
}
```

**Cannot use:** Supabase auth, JWT, any Supabase client methods for authentication

## System 2: Supabase JWT Auth

**Used for:** Customer portal (`/portal/*`)
**User base:** Customers (vehicle owners)
**Token:** Supabase JWT in cookie, managed by `@supabase/ssr`
**User records:** Supabase `auth.users` table
**Guard function:** `supabase.auth.getUser()` from the server client

```typescript
// Correct portal route protection
import { createServerClient } from '@supabase/ssr'

export default async function PortalPage() {
  const supabase = createServerClient(/* ... */)
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  // ...
}
```

**Cannot use:** `verifyAdmin`, admin cookie, `data/admins.json`

## The Mixing Anti-Pattern

These are wrong and break the system:

```typescript
// WRONG — verifyAdmin on a portal route
// /portal/invoices/page.tsx
const admin = await verifyAdmin()

// WRONG — Supabase auth on an admin route  
// /admin/dashboard/page.tsx
const { data: { user } } = await supabase.auth.getUser()
```

The mixing failure mode: admin can access portal routes (security escalation), or customers can access admin routes (unauthorized access).

## Identifying Which System a File Should Use

Look at the file path:
```
app/admin/          → admin cookie
app/portal/         → Supabase JWT
app/api/admin/      → admin cookie  
app/api/portal/     → Supabase JWT
app/api/[anything]/ → depends — check what data it accesses
```

For API routes without a clear prefix, check: does it write to admin data (admins.json, admin settings) or customer data (Supabase tables with RLS)?

## Auth Middleware

The middleware must handle both auth systems correctly:

```typescript
// middleware.ts
export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  
  if (pathname.startsWith('/admin')) {
    // Admin cookie check
    const session = request.cookies.get('admin_session')
    if (!session) return NextResponse.redirect(new URL('/admin/login', request.url))
    // verify the cookie value
  }
  
  if (pathname.startsWith('/portal')) {
    // Supabase JWT refresh
    // ... supabase session refresh ...
  }
  
  return NextResponse.next()
}
```

Never use one system's check for the other's prefix.

## Projects Where This Applies

- `jrs-auto-repair` — both systems present
- `silver-creek-logistics` — both systems present

Projects that don't use both:
- `manage-worker-bee` — admin only (no customer portal)
- `language-lens-elite` — Supabase auth only
- `orthobiologic-pathways` — custom auth (not Supabase)
