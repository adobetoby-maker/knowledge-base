# Failure: Auth Bypass Patterns

## Why This Matters

Authentication bugs are silent — broken auth doesn't throw errors, it just lets the wrong people in. Every auth bypass pattern below has been seen in production codebases.

## Bypass 1: Trusting `getSession()` Instead of `getUser()`

```ts
// WRONG — getSession() reads from cookie without server validation
const { data: { session } } = await supabase.auth.getSession()
const userId = session?.user?.id  // Can be spoofed by modifying cookie client-side

// CORRECT — getUser() validates the JWT against Supabase servers
const { data: { user }, error } = await supabase.auth.getUser()
if (!user || error) return unauthorized()
```

`getSession()` trusts whatever is in the session cookie without calling Supabase. A user can modify their cookie to put any `user.id` they want. Always use `getUser()` for security-critical checks.

## Bypass 2: Missing Auth Check in Route Handler

```ts
// WRONG — no auth check
export async function DELETE(req: NextRequest, { params }) {
  const { id } = await params
  await supabase.from('invoices').delete().eq('id', id)
  return NextResponse.json({ ok: true })
}

// CORRECT
export async function DELETE(req: NextRequest, { params }) {
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { id } = await params
  await supabase.from('invoices').delete().eq('id', id).eq('user_id', user.id)
  return NextResponse.json({ ok: true })
}
```

The `.eq('user_id', user.id)` filter is defense-in-depth — RLS should also enforce this, but explicit filters prevent accidental deletion if RLS is misconfigured.

## Bypass 3: Client-Side Only Auth Check

```tsx
// WRONG — only checked in the component; URL can be typed directly
function AdminPanel() {
  if (!isAdmin) return <div>Access denied</div>
  return <AdminContent />
}

// CORRECT — Server Component redirects before any content renders
export default async function AdminPage() {
  const isAdmin = await validateAdminSession()
  if (!isAdmin) redirect('/login')
  return <AdminContent />
}
```

Client-side checks are cosmetic. Any user can open DevTools and bypass them. Server-side redirect happens before the page renders.

## Bypass 4: Mixing Admin and Portal Auth

```ts
// WRONG — using Supabase JWT to protect admin routes
const session = await supabase.auth.getSession()
if (!session) redirect('/login')

// CORRECT — admin routes use cookie-based admin session
const isAdmin = await validateAdminSession()  // Checks admin_session cookie
if (!isAdmin) redirect('/admin/login')
```

The project has two separate auth systems. Admin routes use `validateAdminSession()` from `lib/adminAuth.ts`. Portal routes use Supabase JWT. Using the wrong one means any authenticated portal user can access admin.

## Bypass 5: Service Role Key in Client Code

```ts
// WRONG — service role bypasses all RLS
// If this ends up in browser bundle, anyone can read all data
const supabase = createClient(url, process.env.SUPABASE_SERVICE_ROLE_KEY!)

// CORRECT — service role only in server-side code
// File uses: import 'server-only'
import 'server-only'
import { createClient } from '@supabase/supabase-js'

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)
```

`SUPABASE_SERVICE_ROLE_KEY` has no `NEXT_PUBLIC_` prefix — it must never reach the browser. Add `import 'server-only'` to the admin client file.

## Bypass 6: IDOR (Insecure Direct Object Reference)

```ts
// WRONG — fetches any invoice by ID, no ownership check
const { data } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', invoiceId)

// CORRECT — scoped to current user (RLS + explicit filter)
const { data } = await supabase
  .from('invoices')
  .select('*')
  .eq('id', invoiceId)
  .eq('user_id', user.id)  // Explicit — don't rely only on RLS
```

Even with RLS, always add explicit user scoping in queries. RLS is a safety net, not the primary line of defense.

## Bypass 7: JWT Not Validated in Supabase Edge Function

```ts
// WRONG — no auth check; any request can call this function
serve(async (req) => {
  const { invoice_id } = await req.json()
  // ... process invoice
})

// CORRECT
serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return new Response('Unauthorized', { status: 401 })

  // Now safe to proceed
})
```

Edge functions deployed with `verify_jwt: false` accept all requests. Always validate manually when JWT verification is disabled, or enable `verify_jwt: true`.

## Quick Audit Checklist

Before shipping any authenticated feature:
- [ ] Does every Route Handler call `getUser()` not `getSession()`?
- [ ] Do all write operations scope to `user_id`?
- [ ] Are admin routes using `validateAdminSession()` not Supabase auth?
- [ ] Is `SUPABASE_SERVICE_ROLE_KEY` only in server files with `import 'server-only'`?
- [ ] Do all Supabase tables have RLS enabled (`ENABLE ROW LEVEL SECURITY`)?
- [ ] Do public-token invoice pages validate the token, not just the invoice ID?
