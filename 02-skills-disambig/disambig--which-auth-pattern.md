# Disambiguation: Which Auth Pattern to Use

## The Two Auth Systems (jrs-auto-repair, silver-creek-logistics)

These projects use TWO separate auth systems that serve different audiences. Mixing them causes session failures and security gaps.

### System 1: Admin Cookie Auth (`/admin/*`)
- **Who**: Internal staff only (Pablo, admins configured in `data/admins.json`)
- **How**: HTTP-only cookie `admin_session`, signed with `ADMIN_SECRET`
- **Validate with**: `validateAdminSession(req)` from `lib/adminAuth.ts`
- **Client**: No Supabase client needed for auth — cookie-only
- **Session creation**: `POST /api/admin/login` sets the cookie

```typescript
// Route Handler in /admin/* routes
import { validateAdminSession } from '@/lib/adminAuth'

export async function GET(req: NextRequest) {
  const isAdmin = await validateAdminSession(req)
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  // ...
}
```

### System 2: Supabase JWT (`/portal/*`)
- **Who**: Customers (Pablo's clients)
- **How**: Supabase JWT in cookies, managed by Supabase Auth
- **Validate with**: `supabase.auth.getUser()` using the server client
- **Client**: Always use `lib/supabase/server.ts` for Server Components, `lib/supabase/client.ts` for Client Components

```typescript
// Server Component in /portal/* routes
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function PortalPage() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  // ...
}
```

## Decision Matrix: Which System for This Route?

| Route Pattern | Auth System | Reason |
|---|---|---|
| `/admin/*` | Cookie auth | Internal tool for business owner |
| `/portal/*` | Supabase JWT | Customer-facing, handles real user accounts |
| `/api/admin/*` | Cookie auth | Admin API endpoints |
| `/api/*` (public) | None | Public data, webhooks |
| `/blog/*`, `/services/*` | None | Public marketing content |

## The ONE Exception: Service Role for Admin Data Access

After validating with cookie auth, use the admin Supabase client for data access:
```typescript
export async function GET(req: NextRequest) {
  const isAdmin = await validateAdminSession(req)  // cookie auth
  if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  const supabase = createAdminClient()  // bypass RLS for admin view
  const { data } = await supabase.from('invoices').select('*')
  // ...
}
```

The admin Supabase client is for DATA ACCESS only — not for auth validation. Auth validation is ALWAYS cookie-based for admin routes.

## manage-worker-bee: Single Auth System

`manage-worker-bee` has only one auth system: direct Supabase service role in `lib/supabase.ts`. Auth is disabled (open internal tool). There is no admin cookie, no portal, no JWT validation.

## language-lens-elite: Supabase Auth Only

`language-lens-elite` uses only Supabase Auth via `src/integrations/supabase/client.ts`. No admin cookie system. Protected routes check `auth.uid()` in Supabase RLS policies.

## orthobiologic-pathways and tobyandertonmd

No auth system. Public sites only. No protected routes, no sessions, no Supabase Auth.

## Quick Check Before Writing Auth Code

1. Which project am I working in?
2. Is this an `/admin/` route, `/portal/` route, or public route?
3. For admin: use `validateAdminSession()` — NEVER `supabase.auth.getUser()`
4. For portal: use `supabase.auth.getUser()` — NEVER cookie auth
5. Never call `supabase.auth.getSession()` for auth checks — use `getUser()` always

## Common Mistakes

**Mistake**: Using `supabase.auth.getUser()` in an `/admin/` route handler
```typescript
// WRONG for admin routes
const { data: { user } } = await supabase.auth.getUser()
if (!user) return unauthorized
// This checks Supabase Auth but admin routes use COOKIE auth
// An admin without a Supabase session would be rejected
```

**Mistake**: Using admin client in a `/portal/` route for auth
```typescript
// WRONG for portal routes
const isAdmin = await validateAdminSession(req)
// Portal auth is Supabase JWT — cookie auth checks will fail
```

**Mistake**: Using `getSession()` instead of `getUser()`
```typescript
// WRONG anywhere
const { data: { session } } = await supabase.auth.getSession()
// getSession() trusts the client-controlled cookie without server re-validation
// A tampered cookie passes this check

// CORRECT
const { data: { user } } = await supabase.auth.getUser()
// getUser() re-validates against Supabase Auth servers
```
