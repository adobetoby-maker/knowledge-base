# Admin Panel Layout Pattern

## Structure

Admin panels need: persistent sidebar, breadcrumbs, header with user context, and a content area. The layout is shared across all admin routes.

```
app/
  admin/
    layout.tsx          → Shared admin shell (sidebar + header)
    page.tsx            → Admin dashboard
    invoices/
      page.tsx          → Invoice list
    customers/
      page.tsx          → Customer list
    settings/
      page.tsx          → Settings
```

## Admin Layout Component

```typescript
// app/admin/layout.tsx
import { validateAdminSession } from '@/lib/adminAuth'
import { redirect } from 'next/navigation'
import { AdminSidebar } from '@/components/admin/Sidebar'
import { AdminHeader } from '@/components/admin/Header'

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode
}) {
  // Auth check at layout level — all admin routes protected
  const isAdmin = await validateAdminSession()
  if (!isAdmin) redirect('/admin/login')

  return (
    <div className="flex h-screen bg-background">
      <AdminSidebar />
      <div className="flex flex-col flex-1 overflow-hidden">
        <AdminHeader />
        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

## Sidebar Navigation

```typescript
// components/admin/Sidebar.tsx
'use client'
import { usePathname } from 'next/navigation'
import Link from 'next/link'
import { LayoutDashboard, FileText, Users, Settings, LogOut } from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { href: '/admin', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/admin/invoices', label: 'Invoices', icon: FileText },
  { href: '/admin/customers', label: 'Customers', icon: Users },
  { href: '/admin/settings', label: 'Settings', icon: Settings },
]

export function AdminSidebar() {
  const pathname = usePathname()

  return (
    <aside className="w-64 border-r bg-card flex flex-col">
      {/* Logo */}
      <div className="p-6 border-b">
        <h1 className="font-semibold text-lg">Jr.'s Auto Repair</h1>
        <p className="text-xs text-muted-foreground">Admin Panel</p>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-1">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive = href === '/admin'
            ? pathname === '/admin'
            : pathname.startsWith(href)

          return (
            <Link
              key={href}
              href={href}
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors',
                isActive
                  ? 'bg-primary text-primary-foreground'
                  : 'text-muted-foreground hover:bg-accent hover:text-accent-foreground'
              )}
            >
              <Icon className="h-4 w-4" />
              {label}
            </Link>
          )
        })}
      </nav>

      {/* Logout */}
      <div className="p-4 border-t">
        <form action="/api/admin/logout" method="POST">
          <button
            type="submit"
            className="flex items-center gap-3 px-3 py-2 rounded-md text-sm text-muted-foreground hover:bg-accent w-full"
          >
            <LogOut className="h-4 w-4" />
            Sign out
          </button>
        </form>
      </div>
    </aside>
  )
}
```

## Header with Breadcrumbs

```typescript
// components/admin/Header.tsx
'use client'
import { usePathname } from 'next/navigation'

function buildBreadcrumbs(pathname: string) {
  const parts = pathname.split('/').filter(Boolean)
  return parts.map((part, index) => ({
    label: part.charAt(0).toUpperCase() + part.slice(1),
    href: '/' + parts.slice(0, index + 1).join('/'),
    isLast: index === parts.length - 1,
  }))
}

export function AdminHeader() {
  const pathname = usePathname()
  const breadcrumbs = buildBreadcrumbs(pathname)

  return (
    <header className="h-14 border-b flex items-center px-6 gap-2">
      {breadcrumbs.map((crumb, i) => (
        <span key={crumb.href} className="flex items-center gap-2">
          {i > 0 && <span className="text-muted-foreground">/</span>}
          {crumb.isLast ? (
            <span className="font-medium text-sm">{crumb.label}</span>
          ) : (
            <a href={crumb.href} className="text-sm text-muted-foreground hover:text-foreground">
              {crumb.label}
            </a>
          )}
        </span>
      ))}
    </header>
  )
}
```

## Page Header Pattern

Each admin page uses a consistent header:
```typescript
// Reusable page header component
export function PageHeader({
  title,
  description,
  action,
}: {
  title: string
  description?: string
  action?: React.ReactNode
}) {
  return (
    <div className="flex items-start justify-between mb-6">
      <div>
        <h1 className="text-2xl font-semibold">{title}</h1>
        {description && (
          <p className="text-sm text-muted-foreground mt-1">{description}</p>
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  )
}

// Usage in admin/invoices/page.tsx:
<PageHeader
  title="Invoices"
  description="Manage customer invoices"
  action={<Button asChild><Link href="/admin/invoices/new">New Invoice</Link></Button>}
/>
```

## Mobile Sidebar (Sheet)

For mobile, replace the persistent sidebar with a sheet that opens from a hamburger button:
```typescript
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet'
import { Menu } from 'lucide-react'

// In AdminLayout, wrap sidebar in a responsive container:
<>
  {/* Desktop sidebar */}
  <aside className="hidden md:flex w-64 ...">
    <AdminSidebarContent />
  </aside>
  
  {/* Mobile sheet */}
  <Sheet>
    <SheetTrigger asChild>
      <Button variant="ghost" size="icon" className="md:hidden">
        <Menu className="h-5 w-5" />
      </Button>
    </SheetTrigger>
    <SheetContent side="left" className="p-0 w-64">
      <AdminSidebarContent />
    </SheetContent>
  </Sheet>
</>
```
