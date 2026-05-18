# Tabs Navigation Pattern

## Two Distinct Tab Use Cases

1. **Routed tabs** — each tab is a separate URL (`/settings/profile`, `/settings/billing`). Back button works, direct linking works.
2. **State tabs** — switching tabs doesn't change the URL. Used within a single page section.

Use routed tabs for primary navigation. Use state tabs for panels within a page.

## Routed Tabs (URL-Driven)

```typescript
// app/(admin)/settings/layout.tsx
import Link from 'next/link'
import { usePathname } from 'next/navigation'  // client needed for active state

const tabs = [
  { href: '/settings/profile', label: 'Profile' },
  { href: '/settings/billing', label: 'Billing' },
  { href: '/settings/notifications', label: 'Notifications' },
  { href: '/settings/security', label: 'Security' },
]

// Server Component layout — pass active state via pathname comparison
export default function SettingsLayout({ children }) {
  return (
    <div>
      <SettingsTabs />   {/* client component for active highlighting */}
      {children}
    </div>
  )
}

// components/SettingsTabs.tsx
'use client'
export function SettingsTabs() {
  const pathname = usePathname()
  
  return (
    <nav className="flex border-b mb-6">
      {tabs.map(tab => (
        <Link
          key={tab.href}
          href={tab.href}
          className={cn(
            "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
            pathname === tab.href
              ? "border-primary text-foreground"
              : "border-transparent text-muted-foreground hover:text-foreground hover:border-muted-foreground"
          )}
        >
          {tab.label}
        </Link>
      ))}
    </nav>
  )
}
```

## State Tabs (shadcn Tabs Component)

```typescript
// Inside a page — doesn't change URL
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

export function InvoiceDetailTabs({ invoice }) {
  return (
    <Tabs defaultValue="details">
      <TabsList>
        <TabsTrigger value="details">Details</TabsTrigger>
        <TabsTrigger value="timeline">Timeline</TabsTrigger>
        <TabsTrigger value="documents">Documents</TabsTrigger>
      </TabsList>
      
      <TabsContent value="details">
        <InvoiceDetails invoice={invoice} />
      </TabsContent>
      
      <TabsContent value="timeline">
        <InvoiceTimeline invoiceId={invoice.id} />
      </TabsContent>
      
      <TabsContent value="documents">
        <InvoiceDocuments invoiceId={invoice.id} />
      </TabsContent>
    </Tabs>
  )
}
```

## State Tabs with URL Sync (Hybrid)

When you want bookmarkable state tabs but they're within a page (not separate routes):

```typescript
'use client'
export function InvoiceTabs() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const tab = searchParams.get('tab') ?? 'details'
  
  function setTab(value: string) {
    const params = new URLSearchParams(searchParams.toString())
    params.set('tab', value)
    router.replace(`?${params.toString()}`, { scroll: false })
  }
  
  return (
    <Tabs value={tab} onValueChange={setTab}>
      <TabsList>
        <TabsTrigger value="details">Details</TabsTrigger>
        <TabsTrigger value="timeline">Timeline</TabsTrigger>
      </TabsList>
      {/* TabsContent here */}
    </Tabs>
  )
}
```

`{ scroll: false }` prevents the page from scrolling to top on tab change.

## Tabs with Counts / Badges

```typescript
<TabsTrigger value="pending" className="gap-2">
  Pending
  {pendingCount > 0 && (
    <Badge variant="secondary" className="h-5 min-w-5 text-xs">
      {pendingCount}
    </Badge>
  )}
</TabsTrigger>
```

## Mobile Tabs Pattern

On mobile, wide tab bars overflow. Use a `Select` as the mobile variant:

```typescript
// Show tabs on desktop, select on mobile
<div className="hidden sm:block">
  <TabsList>...</TabsList>
</div>
<div className="sm:hidden">
  <Select value={tab} onValueChange={setTab}>
    <SelectTrigger>
      <SelectValue />
    </SelectTrigger>
    <SelectContent>
      {tabs.map(t => (
        <SelectItem key={t.value} value={t.value}>{t.label}</SelectItem>
      ))}
    </SelectContent>
  </Select>
</div>
```

## Decision: Routed vs State Tabs

Use **routed tabs** when:
- Each tab is a major section with its own data
- Direct link sharing matters (send someone to the Billing tab)
- Tab content needs its own loading state

Use **state tabs** when:
- Tabs show different views of the same data
- The parent page already handles the data fetching
- All tab content is small enough to render at once
