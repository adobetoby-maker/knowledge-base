# Portal Layout Pattern (Customer-Facing)

## Purpose

Portal layouts serve authenticated customers — different from admin panels:
- Simpler navigation (fewer routes)
- Customer context (their name, account info)
- Limited to data they own (RLS handles this at DB level)
- Mobile-first (customers use phones)

## Portal Route Structure (jrs-auto-repair)

```
app/
  (portal)/           → Route group — shares portal layout
    layout.tsx        → Auth check + portal shell
    dashboard/
      page.tsx
    invoices/
      page.tsx
      [id]/
        page.tsx
  login/
    page.tsx          → Public — NOT in (portal) group
```

## Portal Layout with Auth

```typescript
// app/(portal)/layout.tsx
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { PortalNav } from '@/components/portal/Nav'

export default async function PortalLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()  // NEVER getSession()
  if (!user) redirect('/login')

  // Fetch customer profile for header
  const { data: customer } = await supabase
    .from('customers')
    .select('name')
    .eq('id', user.id)
    .single()

  return (
    <div className="min-h-screen flex flex-col">
      <PortalNav customerName={customer?.name ?? user.email ?? ''} />
      <main className="flex-1 container mx-auto px-4 py-6 max-w-4xl">
        {children}
      </main>
    </div>
  )
}
```

## Portal Navigation

Simpler than admin — usually just a top nav bar on mobile:
```typescript
// components/portal/Nav.tsx
'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'

const links = [
  { href: '/portal/dashboard', label: 'Dashboard' },
  { href: '/portal/invoices', label: 'Invoices' },
]

export function PortalNav({ customerName }: { customerName: string }) {
  const pathname = usePathname()

  return (
    <header className="border-b bg-card">
      <div className="container mx-auto px-4 h-14 flex items-center justify-between">
        {/* Brand */}
        <span className="font-semibold">Jr.'s Auto Repair</span>

        {/* Nav links */}
        <nav className="flex items-center gap-1">
          {links.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className={cn(
                'px-3 py-1.5 rounded-md text-sm',
                pathname.startsWith(href)
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              {label}
            </Link>
          ))}
        </nav>

        {/* User context + logout */}
        <div className="flex items-center gap-3 text-sm">
          <span className="text-muted-foreground hidden sm:block">{customerName}</span>
          <form action="/api/auth/logout" method="POST">
            <button type="submit" className="text-sm text-muted-foreground hover:text-foreground">
              Sign out
            </button>
          </form>
        </div>
      </div>
    </header>
  )
}
```

## Customer Dashboard Page

```typescript
// app/(portal)/dashboard/page.tsx
import { createClient } from '@/lib/supabase/server'

export default async function CustomerDashboard() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  // user is guaranteed non-null here (layout checked)

  // RLS ensures customer only sees their own data
  const { data: recentInvoices } = await supabase
    .from('invoices')
    .select('id, number, status, total, created_at')
    .order('created_at', { ascending: false })
    .limit(5)

  const { data: stats } = await supabase
    .from('invoices')
    .select('status')

  const pendingCount = stats?.filter(i => i.status === 'pending').length ?? 0
  const totalPaid = stats?.filter(i => i.status === 'paid').length ?? 0

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid grid-cols-2 gap-4">
        <div className="p-4 border rounded-lg">
          <p className="text-sm text-muted-foreground">Pending</p>
          <p className="text-2xl font-semibold">{pendingCount}</p>
        </div>
        <div className="p-4 border rounded-lg">
          <p className="text-sm text-muted-foreground">Paid</p>
          <p className="text-2xl font-semibold">{totalPaid}</p>
        </div>
      </div>

      {/* Recent invoices */}
      <div>
        <h2 className="font-medium mb-3">Recent Invoices</h2>
        <div className="space-y-2">
          {recentInvoices?.map(invoice => (
            <a
              key={invoice.id}
              href={`/portal/invoices/${invoice.id}`}
              className="flex items-center justify-between p-3 border rounded-md hover:bg-accent"
            >
              <span className="text-sm font-medium">{invoice.number}</span>
              <span className={`text-xs px-2 py-1 rounded-full ${
                invoice.status === 'paid' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'
              }`}>
                {invoice.status}
              </span>
            </a>
          ))}
        </div>
      </div>
    </div>
  )
}
```

## Auth Separation Reminder

The portal layout uses Supabase `getUser()` — NEVER the admin cookie auth. The admin layout uses cookie auth — NEVER Supabase JWT. These two auth systems are completely separate and must not be mixed.
