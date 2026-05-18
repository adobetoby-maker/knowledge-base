# Side Navigation

## Structure

Admin dashboards use a persistent left sidebar for navigation. The sidebar contains:
1. Logo/brand
2. Primary nav links (top section)
3. Secondary nav links (middle section)  
4. User profile + logout (bottom, pinned)

## Sidebar Component

```typescript
// components/admin/Sidebar.tsx
const NAV_ITEMS = [
  { href: '/admin', label: 'Dashboard', icon: LayoutDashboard, exact: true },
  { href: '/admin/invoices', label: 'Invoices', icon: FileText },
  { href: '/admin/customers', label: 'Customers', icon: Users },
  { href: '/admin/payments', label: 'Payments', icon: CreditCard },
]

const SECONDARY_ITEMS = [
  { href: '/admin/settings', label: 'Settings', icon: Settings },
]

export function Sidebar() {
  const pathname = usePathname()
  
  function isActive(href: string, exact = false) {
    return exact ? pathname === href : pathname.startsWith(href)
  }
  
  return (
    <aside className="flex flex-col h-full w-60 border-r bg-card">
      {/* Logo */}
      <div className="p-4 border-b">
        <Link href="/admin" className="flex items-center gap-2">
          <img src="/logo.svg" alt="Jr.'s Auto Repair" className="h-8 w-8" />
          <span className="font-semibold text-sm">Jr.'s Auto Repair</span>
        </Link>
      </div>
      
      {/* Primary nav */}
      <nav className="flex-1 overflow-y-auto p-2">
        <ul className="space-y-0.5">
          {NAV_ITEMS.map(item => (
            <li key={item.href}>
              <Link
                href={item.href}
                className={cn(
                  'flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors',
                  isActive(item.href, item.exact)
                    ? 'bg-accent text-accent-foreground font-medium'
                    : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                )}
              >
                <item.icon className="h-4 w-4 flex-shrink-0" />
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
        
        <div className="mt-auto pt-2 border-t">
          <ul className="space-y-0.5">
            {SECONDARY_ITEMS.map(item => (
              <li key={item.href}>
                <Link href={item.href} className={cn('flex items-center gap-2 px-3 py-2 rounded-md text-sm text-muted-foreground hover:text-foreground hover:bg-muted', isActive(item.href) && 'bg-accent text-accent-foreground')}>
                  <item.icon className="h-4 w-4" />
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </nav>
      
      {/* User footer */}
      <div className="p-3 border-t">
        <UserMenu />
      </div>
    </aside>
  )
}
```

## Mobile: Sheet Sidebar

On mobile, the sidebar slides in as a Sheet:

```typescript
export function MobileSidebar() {
  const [open, setOpen] = useState(false)
  const pathname = usePathname()
  
  // Close on navigation:
  useEffect(() => { setOpen(false) }, [pathname])
  
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="md:hidden">
          <Menu className="h-5 w-5" />
        </Button>
      </SheetTrigger>
      <SheetContent side="left" className="p-0 w-60">
        <Sidebar />
      </SheetContent>
    </Sheet>
  )
}
```

## Admin Layout

```typescript
// app/admin/layout.tsx
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen">
      {/* Desktop sidebar */}
      <div className="hidden md:flex md:flex-col">
        <Sidebar />
      </div>
      
      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Mobile header */}
        <header className="md:hidden flex items-center gap-3 px-4 h-14 border-b">
          <MobileSidebar />
          <span className="font-semibold">Jr.'s Auto Repair</span>
        </header>
        
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

## Collapsible Sidebar

For dashboards where screen space matters:

```typescript
const [collapsed, setCollapsed] = useState(false)

<aside className={cn('transition-all duration-200', collapsed ? 'w-14' : 'w-60')}>
  {/* Show icons only when collapsed */}
  <NavItem icon={FileText} label="Invoices" href="/admin/invoices" showLabel={!collapsed} />
</aside>

<Button onClick={() => setCollapsed(prev => !prev)} variant="ghost" size="icon">
  <PanelLeftClose className="h-4 w-4" />
</Button>
```
