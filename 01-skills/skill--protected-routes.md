# Protected Routes

## Pattern Overview

Protected routes prevent unauthenticated access. In Next.js App Router, protection happens in:
1. **Middleware** — fast check before any rendering
2. **Page/Layout Server Component** — reliable auth check (recommended for complex auth)
3. **Both** — middleware for performance, component for correctness

## Server Component Auth Check (Recommended)

The safest pattern — auth check runs on the server, no client exposure:

```typescript
// app/admin/layout.tsx
import { validateAdminSession } from '@/lib/adminAuth'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const admin = await validateAdminSession()  // redirects to /admin/login if invalid
  
  return (
    <div>
      <AdminNav admin={admin} />
      <main>{children}</main>
    </div>
  )
}
```

Every route under `/admin/*` inherits this check from the layout.

## Route Groups for Auth Zones

Use route groups to organize protected vs public routes:

```
app/
  (public)/
    page.tsx          → /  (no auth)
    about/page.tsx    → /about (no auth)
  (portal)/
    layout.tsx        → portal auth check
    dashboard/page.tsx → /dashboard (portal auth required)
    invoices/page.tsx → /invoices (portal auth required)
  admin/
    layout.tsx        → admin cookie auth check
    invoices/page.tsx → /admin/invoices (admin auth required)
```

## Middleware (Edge Auth Check)

Use middleware for fast rejection at the CDN level. It runs before Server Components:

```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  
  // Portal routes: check Supabase session
  if (pathname.startsWith('/portal')) {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll: () => request.cookies.getAll(),
          setAll: () => {},  // can't set cookies in middleware response directly
        },
      }
    )
    
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return NextResponse.redirect(new URL('/login', request.url))
  }
  
  // Admin routes: check admin session cookie
  if (pathname.startsWith('/admin') && !pathname.startsWith('/admin/login')) {
    const sessionCookie = request.cookies.get('admin_session')
    if (!sessionCookie) return NextResponse.redirect(new URL('/admin/login', request.url))
    // Full signature verification happens in the layout/page
  }
  
  return NextResponse.next()
}

export const config = {
  matcher: ['/portal/:path*', '/admin/:path*'],
}
```

Middleware cookie checks are fast but shallow (no DB call). Always do the full auth check in the Server Component too.

## Login Redirect with Return URL

Preserve where the user was trying to go:

```typescript
// On redirect to login:
redirect(`/login?next=${encodeURIComponent(pathname)}`)

// On login success:
const next = searchParams.get('next') ?? '/dashboard'
// Security: only allow internal redirects:
const safeNext = next.startsWith('/') ? next : '/dashboard'
redirect(safeNext)
```

## Auth on API Routes

Route Handlers need their own auth check — middleware doesn't automatically protect them from direct fetch calls:

```typescript
// app/api/invoices/route.ts
export async function GET(request: Request) {
  // Admin API:
  const admin = await validateAdminSession()  // redirects if not admin
  
  const invoices = await getInvoices()
  return Response.json({ invoices })
}
```

## Auth in Server Actions

```typescript
// lib/actions/invoice.ts
'use server'

export async function deleteInvoice(invoiceId: string) {
  // Auth first — before ANY other logic:
  const admin = await validateAdminSession()
  
  // Now safe to proceed:
  await supabase.from('invoices').delete().eq('id', invoiceId)
  revalidatePath('/admin/invoices')
}
```

Never check auth after starting the work — it creates a TOCTOU (time-of-check-time-of-use) vulnerability.
