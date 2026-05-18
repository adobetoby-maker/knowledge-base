# Breadcrumbs Pattern

## When to Use

Breadcrumbs help users understand where they are in a hierarchy and navigate up. Essential for:
- Deep route structures (`/admin/customers/123/invoices/456`)
- Blog category → article navigation
- Multi-level settings pages

Skip breadcrumbs for: flat sites, single-level navigation, or when the page context is already obvious from the layout.

## Static Breadcrumbs

```typescript
// components/Breadcrumbs.tsx
import Link from 'next/link'
import { ChevronRight } from 'lucide-react'

interface BreadcrumbItem {
  label: string
  href?: string  // no href = current page (not a link)
}

export function Breadcrumbs({ items }: { items: BreadcrumbItem[] }) {
  return (
    <nav aria-label="Breadcrumb">
      <ol className="flex items-center gap-1 text-sm text-muted-foreground">
        {items.map((item, index) => (
          <li key={item.href ?? item.label} className="flex items-center gap-1">
            {index > 0 && <ChevronRight className="h-3.5 w-3.5" />}
            {item.href ? (
              <Link href={item.href} className="hover:text-foreground transition-colors">
                {item.label}
              </Link>
            ) : (
              <span className="text-foreground font-medium" aria-current="page">
                {item.label}
              </span>
            )}
          </li>
        ))}
      </ol>
    </nav>
  )
}

// Usage:
<Breadcrumbs items={[
  { label: 'Dashboard', href: '/admin' },
  { label: 'Customers', href: '/admin/customers' },
  { label: 'Smith, John' },
]} />
```

## Dynamic Breadcrumbs from URL

Auto-generate from pathname:

```typescript
// hooks/useBreadcrumbs.ts
'use client'
import { usePathname } from 'next/navigation'

const SEGMENT_LABELS: Record<string, string> = {
  admin: 'Dashboard',
  portal: 'My Account',
  customers: 'Customers',
  invoices: 'Invoices',
  services: 'Services',
  settings: 'Settings',
}

export function useBreadcrumbs() {
  const pathname = usePathname()
  const segments = pathname.split('/').filter(Boolean)
  
  return segments.map((segment, index) => {
    const href = '/' + segments.slice(0, index + 1).join('/')
    const isLast = index === segments.length - 1
    const label = SEGMENT_LABELS[segment] ?? segment.replace(/-/g, ' ')
    
    return {
      label,
      href: isLast ? undefined : href,
    }
  })
}
```

## Breadcrumbs with Dynamic Data

For routes like `/admin/customers/123` where the ID needs a name:

```typescript
// app/(admin)/customers/[id]/page.tsx
export default async function CustomerPage({ params }) {
  const { id } = await params
  const customer = await fetchCustomer(id)
  if (!customer) notFound()
  
  return (
    <>
      <Breadcrumbs items={[
        { label: 'Customers', href: '/admin/customers' },
        { label: customer.name },  // dynamic — loaded from DB
      ]} />
      <CustomerDetails customer={customer} />
    </>
  )
}
```

## BreadcrumbList Schema for SEO

JSON-LD for breadcrumb schema must use only static, trusted content (not user-generated):

```typescript
// components/BreadcrumbSchema.tsx
// Note: Only use with trusted content (never user-supplied text without sanitization)
export function BreadcrumbSchema({ items }: { items: BreadcrumbItem[] }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.label,
      ...(item.href ? { item: `https://jrsautorepair.com${item.href}` } : {}),
    })),
  }
  
  const safeJson = JSON.stringify(schema)
  
  return (
    <script
      type="application/ld+json"
      // Content is application-generated structured data, not user input
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: safeJson }}
    />
  )
}
```

Only use this pattern for application-generated JSON-LD, never for user-supplied content.

## Mobile Considerations

On mobile, long breadcrumb trails overflow. Show only the last 2 items:

```typescript
function ResponsiveBreadcrumbs({ items }: { items: BreadcrumbItem[] }) {
  const mobileItems = items.slice(-2)
  
  return (
    <>
      <div className="sm:hidden">
        <Breadcrumbs items={mobileItems} />
      </div>
      <div className="hidden sm:block">
        <Breadcrumbs items={items} />
      </div>
    </>
  )
}
```
