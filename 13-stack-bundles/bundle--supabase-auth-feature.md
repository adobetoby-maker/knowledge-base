# Stack Bundle: Supabase Auth Feature Development

**Use when:** Implementing auth flows, fixing auth bugs, or adding auth-protected routes in a Next.js + Supabase app.
**Replaces:** auth--two-system-pattern.md + failure--supabase-auth-cookie.md + security-boundaries.md + supabase--rls-patterns.md

---

## The Two Auth Systems (jrs-auto-repair, silver-creek-logistics)

### System 1 — Admin Auth (cookie-based)
```
Users: data/admins.json
Entry: /admin routes
Logic: lib/adminAuth.ts
Cookie: admin_session (HMAC-SHA256 signed with ADMIN_SECRET)
Check: verifyAdmin(request) → returns admin object or null
```
```typescript
// In Route Handler or Server Component
const admin = await verifyAdmin(request)
if (!admin) redirect('/admin/login')
```

### System 2 — Portal Auth (Supabase JWT)
```
Users: Supabase auth.users table
Entry: /portal routes
Logic: lib/supabase/server.ts
Cookie: Supabase manages auth cookies automatically
Check: supabase.auth.getUser() → returns { user, error }
```
```typescript
// In Route Handler or Server Component
const supabase = await createClient()  // lib/supabase/server.ts
const { data: { user }, error } = await supabase.auth.getUser()
if (!user) redirect('/login')
```

NEVER mix these: never use Supabase JWT to check admin status. Never use admin cookie for portal users.

## The Three Supabase Clients

```typescript
// lib/supabase/client.ts — BROWSER ONLY
// Use in Client Components ('use client')
import { createBrowserClient } from '@supabase/ssr'
export const supabase = createBrowserClient(url, anonKey)

// lib/supabase/server.ts — SERVER ONLY
// Use in Server Components, Route Handlers, Server Actions
// Reads cookies from Next.js request
export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient(url, anonKey, { cookies: { ... } })
}

// lib/supabase/admin.ts — SERVER ONLY, BYPASSES RLS
// Use for admin operations only — never import client-side
import { createClient } from '@supabase/supabase-js'
export const adminSupabase = createClient(url, serviceRoleKey)
```

## getUser() vs getSession()
```typescript
// WRONG — trusts client-controlled cookie, can be spoofed
const { data: { session } } = await supabase.auth.getSession()

// RIGHT — re-validates with Supabase servers
const { data: { user }, error } = await supabase.auth.getUser()
```
Always use `getUser()` for security checks.

## Middleware — Token Refresh
Without this, sessions expire silently:
```typescript
// middleware.ts
import { createServerClient } from '@supabase/ssr'
export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request })
  const supabase = createServerClient(url, anonKey, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll: (cookies) => cookies.forEach(({ name, value, options }) => {
        request.cookies.set({ name, value })
        response.cookies.set({ name, value, ...options })
      })
    }
  })
  await supabase.auth.getUser()  // refreshes token
  return response
}
```

## RLS Policy Templates

### User Owns Their Rows
```sql
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "select_own" ON public.posts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "insert_own" ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "update_own" ON public.posts FOR UPDATE 
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "delete_own" ON public.posts FOR DELETE USING (auth.uid() = user_id);
```

### Public Read
```sql
CREATE POLICY "public_read" ON public.products FOR SELECT USING (true);
```

## Auth Debugging
```sql
-- Check if RLS is blocking
SELECT relrowsecurity FROM pg_class WHERE relname = 'your_table';
-- true = enabled

-- What is auth.uid() resolving to?
SELECT auth.uid();

-- Test query as specific user (SQL editor)
SET LOCAL "request.jwt.claims" = '{"sub": "user-uuid"}';
SELECT * FROM your_table;
```

## Security Rules
- NEXT_PUBLIC_* is visible in browser source — never put secrets there
- SUPABASE_SERVICE_ROLE_KEY = server only, never NEXT_PUBLIC_
- admin.ts client bypasses ALL RLS — never expose to client bundle
- httpOnly + secure + sameSite:strict on all auth cookies
