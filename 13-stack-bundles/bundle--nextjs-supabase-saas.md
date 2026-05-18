# Stack Bundle: Next.js + Supabase SaaS

## Overview

The canonical full-stack SaaS stack. Next.js App Router handles the web app, Supabase provides auth + database + storage + realtime. This bundle documents the integration patterns, common gotchas, and project structure for a multi-tenant SaaS built on this stack.

## Project Structure

```
src/
  app/
    (auth)/                    # Auth pages (no shared layout)
      login/page.tsx
      signup/page.tsx
    (app)/                     # App pages (with sidebar layout)
      layout.tsx               # Auth gate + sidebar
      dashboard/page.tsx
      settings/page.tsx
    api/                       # Route handlers
      webhooks/stripe/route.ts
  lib/
    supabase/
      client.ts                # Browser Supabase client
      server.ts                # Server Supabase client (cookies)
      admin.ts                 # Service role client (server only)
    auth.ts                    # getServerSession helper
    db/
      schema.ts                # Drizzle schema
      index.ts                 # Drizzle instance
  components/
    ui/                        # shadcn components
    [feature]/                 # Feature-specific components
middleware.ts                  # Auth redirect + session refresh
```

## Auth Gate in Layout

```tsx
// app/(app)/layout.tsx
import { redirect } from 'next/navigation'
import { createServerClient } from '@/lib/supabase/server'

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createServerClient()
  const { data: { user }, error } = await supabase.auth.getUser()

  if (error || !user) {
    redirect('/login')
  }

  return (
    <div className="flex h-screen">
      <Sidebar user={user} />
      <main className="flex-1 overflow-y-auto">
        {children}
      </main>
    </div>
  )
}
```

`getUser()` (not `getSession()`) validates the JWT against Supabase's server — `getSession()` trusts the client cookie and can be spoofed.

## Supabase Clients

```ts
// lib/supabase/client.ts — browser only
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}

// lib/supabase/server.ts — server only (cookies)
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createServerClient() {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cs) => cs.forEach(c => cookieStore.set(c)),
      },
    }
  )
}

// lib/supabase/admin.ts — service role (NEVER import client-side)
import { createClient } from '@supabase/supabase-js'

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  { auth: { autoRefreshToken: false, persistSession: false } }
)
```

## Middleware (Session Refresh)

```ts
// middleware.ts
import { createServerClient } from '@supabase/ssr'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  const response = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cs) => cs.forEach(c => response.cookies.set(c)),
      },
    }
  )

  // Refresh session — must be called in middleware for session to stay alive
  await supabase.auth.getUser()

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
```

## Row-Level Security Pattern

```sql
-- RLS for multi-tenant: user can only see their own data
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users see own projects" ON projects
  USING (auth.uid() = user_id);

CREATE POLICY "users insert own projects" ON projects
  WITH CHECK (auth.uid() = user_id);

-- Workspace-scoped: user can see workspace members' data
CREATE POLICY "workspace members see posts" ON posts
  USING (
    workspace_id IN (
      SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()
    )
  );
```

## Stripe Integration Pattern

```ts
// On signup: create Stripe customer and store ID
export async function POST(req: Request) {
  const { email, userId } = await req.json()

  const customer = await stripe.customers.create({ email, metadata: { userId } })

  await supabaseAdmin.from('users').update({
    stripe_customer_id: customer.id,
  }).eq('id', userId)

  return Response.json({ customerId: customer.id })
}
```

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=           # Supabase project URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=      # Anon key (client-safe)
SUPABASE_SERVICE_ROLE_KEY=          # Service role (server only, NEVER NEXT_PUBLIC_)
STRIPE_SECRET_KEY=                  # Server only
STRIPE_WEBHOOK_SECRET=              # Server only
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY= # Client-safe (for Stripe.js)
```

## Key Rules

- Always `getUser()` in layout/middleware — `getSession()` doesn't validate against Supabase's server.
- `supabaseAdmin` (service role) MUST only be imported in server files — it bypasses ALL RLS policies.
- Refresh session in middleware — without it, the session cookie expires and users get logged out.
- Enable RLS on every table and test with `anon` key queries — a missing RLS policy is a data exposure bug.
- Keep Stripe/billing logic server-side — never expose the Stripe secret key to the browser.
