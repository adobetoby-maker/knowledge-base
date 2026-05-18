# Split View Layout

## When to Use

Use a split view (list on left, detail on right) for:
- Email/messaging interfaces (inbox + message body)
- CRM (customer list + customer detail)
- Admin resource management (invoices list + invoice detail)
- Settings (setting categories + setting panel)

Benefits: context stays visible while navigating; avoids full-page navigation for dense workflows.

## URL-Driven Split View (Recommended)

Keep the selected item in the URL so links work, browser back works, and state is shareable:

```typescript
// URL: /admin/customers         → list only (mobile) or list + empty state (desktop)
// URL: /admin/customers/abc123  → list + detail for abc123

// app/admin/customers/layout.tsx
export default function CustomersLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-[calc(100vh-4rem)]">
      <CustomerList />         {/* always rendered */}
      <main className="flex-1 overflow-y-auto border-l">
        {children}             {/* slot for [id]/page.tsx */}
      </main>
    </div>
  )
}

// app/admin/customers/page.tsx — empty state when no customer selected
export default function CustomersPage() {
  return (
    <div className="h-full flex items-center justify-center text-muted-foreground">
      Select a customer to view details
    </div>
  )
}

// app/admin/customers/[id]/page.tsx
export default async function CustomerDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const customer = await getCustomer(id)
  if (!customer) notFound()
  return <CustomerDetail customer={customer} />
}
```

## List Panel (with Active Highlight)

```typescript
'use client'
function CustomerList() {
  const pathname = usePathname()
  const { data: customers } = useQuery({ queryKey: ['customers'], queryFn: fetchCustomers })
  
  return (
    <nav className="w-64 min-w-64 border-r overflow-y-auto">
      <div className="p-3">
        <Input placeholder="Search customers..." className="h-8" />
      </div>
      <ul>
        {(customers ?? []).map(customer => {
          const isActive = pathname.includes(customer.id)
          return (
            <li key={customer.id}>
              <Link
                href={`/admin/customers/${customer.id}`}
                className={cn(
                  'block px-3 py-2 hover:bg-muted',
                  isActive && 'bg-accent text-accent-foreground font-medium'
                )}
              >
                <p className="truncate text-sm">{customer.name}</p>
                <p className="text-xs text-muted-foreground truncate">{customer.email}</p>
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
```

## Resizable Split (Optional)

For power-user interfaces, allow resizing the panes:

```bash
npm install react-resizable-panels
```

```typescript
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels'

function ResizableSplitView() {
  return (
    <PanelGroup direction="horizontal" className="h-full">
      <Panel defaultSize={30} minSize={20} maxSize={50}>
        <CustomerList />
      </Panel>
      <PanelResizeHandle className="w-1 hover:bg-primary/50 transition-colors" />
      <Panel>
        <CustomerDetail />
      </Panel>
    </PanelGroup>
  )
}
```

## Mobile Behavior

On mobile, show one panel at a time — the list navigates to a full-screen detail view:

```typescript
// Detect mobile and switch layouts:
function CustomersLayout({ children, params }: { children: React.ReactNode; params: { id?: string } }) {
  const hasDetail = !!params.id
  
  return (
    <>
      {/* Mobile: show list OR detail */}
      <div className="md:hidden h-full">
        {hasDetail ? children : <CustomerList />}
      </div>
      
      {/* Desktop: show both */}
      <div className="hidden md:flex h-full">
        <CustomerList />
        <main className="flex-1 border-l overflow-y-auto">{children}</main>
      </div>
    </>
  )
}
```

## Keyboard Navigation

For keyboard-friendly split views:

```typescript
useHotkeys('j', () => selectNextCustomer())
useHotkeys('k', () => selectPrevCustomer())
useHotkeys('enter', () => openDetailPanel())
useHotkeys('esc', () => returnToList())
```
