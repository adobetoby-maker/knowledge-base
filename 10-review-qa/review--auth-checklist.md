# Auth Review Checklist

## Supabase Auth

- [ ] `getUser()` used for auth checks (not `getSession()`)
  - `getSession()` trusts a client-controlled cookie and can be spoofed
  - `getUser()` validates the JWT against Supabase on every call
  
- [ ] Server Components use `supabaseServer()` (reads cookies from request context)
- [ ] Client Components use `supabaseBrowser()` (browser singleton)
- [ ] Admin client (`supabaseAdmin()` / `admin.ts`) is NEVER imported from:
  - Client Components
  - Page components
  - Any file with `'use client'`
  - Any file that could be bundled into the browser

## JWT and Session Handling

- [ ] Protected routes have auth check at the route/page level, not just in a component
- [ ] Auth check in Server Components uses `getUser()` from `@supabase/ssr`, not directly from `@supabase/supabase-js`
- [ ] Session refresh handled — `@supabase/ssr` handles this via `supabaseServer()`
- [ ] `cookies()` imported from `next/headers` in Server Components (not from supabase client)

```typescript
// CORRECT server-side auth check:
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

async function getAuthenticatedUser() {
  const cookieStore = await cookies()  // Next.js 15: must await
  const supabase = createServerClient(...)
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) redirect('/login')
  return user
}
```

## Two-Auth-System Projects (jrs-auto-repair, silver-creek)

- [ ] Admin auth (`/admin/*`) uses cookie-based `validateAdminSession()` — never Supabase JWT
- [ ] Portal auth (`/portal/*`) uses Supabase JWT — never admin cookie check
- [ ] No route is protected by both admin and portal auth simultaneously
- [ ] `validateAdminSession()` returns early with redirect to `/admin/login` if not authenticated

```typescript
// Admin auth check — cookie-based:
export async function validateAdminSession() {
  const cookieStore = await cookies()
  const session = cookieStore.get('admin_session')?.value
  if (!session) redirect('/admin/login')
  // verify signature
  return verifiedSession
}

// Portal auth check — Supabase JWT:
const { data: { user } } = await supabase.auth.getUser()
if (!user) redirect('/login')
```

## RLS Policy Coverage

- [ ] Every table with sensitive data has RLS enabled
- [ ] Each RLS policy uses `auth.uid()` — not `auth.email()` (easier to spoof)
- [ ] SELECT policies don't expose rows the user doesn't own
- [ ] INSERT policies include `WITH CHECK (auth.uid() = user_id)` — not just `USING`
- [ ] UPDATE policies have BOTH `USING` (which rows) AND `WITH CHECK` (resulting state)
- [ ] Soft-delete tables add `AND deleted_at IS NULL` to SELECT policies

## Route Protection

- [ ] Protected page routes check auth before rendering (not relying solely on middleware)
- [ ] API routes that mutate data verify auth before the mutation
- [ ] Middleware (if used) set to protect route groups, not individual routes
- [ ] `notFound()` not called inside try/catch (throws in Next.js, caught by catch block)

## Password and Credential Handling

- [ ] No passwords stored — using Supabase Auth (OAuth or magic link)
- [ ] If using custom admin password: stored hashed (bcrypt), not as plaintext in env var or JSON
- [ ] `ADMIN_SECRET` env var used only for signing cookies, never exposed to client

## Common Mistakes

Missing auth on a specific route:
```typescript
// WRONG — page renders before auth check, race condition:
export default async function Page() {
  const data = await fetchData()  // happens before user is verified
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  return <Dashboard data={data} />
}

// CORRECT — auth check first:
export default async function Page() {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  const data = await fetchData()  // only runs if authenticated
  return <Dashboard data={data} />
}
```
