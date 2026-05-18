# Skill: component-library

**Trigger:** Building reusable React components, organizing component hierarchy, or establishing component patterns.
**Returns:** Component organization patterns, composition strategies, prop design principles.

## Component Hierarchy

```
app/
  components/           → page-specific components
  components/ui/        → shadcn/ui base components (auto-generated, don't edit)
  components/shared/    → shared across multiple pages
  components/[feature]/ → feature-specific components
lib/
  components/           → components tied to lib logic (if used across pages)
```

## Component File Structure

```typescript
// components/InvoiceCard.tsx

// 1. Imports (external → internal → types)
import { useState } from 'react'
import Link from 'next/link'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import type { Invoice } from '@/lib/types'

// 2. Type definitions (local to this file)
interface InvoiceCardProps {
  invoice: Invoice
  onStatusChange?: (id: string, status: Invoice['status']) => void
}

// 3. Component (one per file, same name as file)
export function InvoiceCard({ invoice, onStatusChange }: InvoiceCardProps) {
  const [isExpanded, setIsExpanded] = useState(false)
  
  return (
    <Card>
      <CardContent>
        {/* ... */}
      </CardContent>
    </Card>
  )
}
```

## Prop Design Principles

**Minimal surface area:** Expose only what callers need. Avoid `className` passthrough on every component (creates invisible coupling).

**Prefer composition over configuration:**
```typescript
// Configuration-heavy (hard to extend)
<Table
  showHeader={true}
  sortable={true}
  paginated={true}
  headerColor="blue"
  rowHeight="compact"
/>

// Composition (easy to extend)
<Table>
  <TableHeader />
  <TableBody rows={data} />
  <TablePagination />
</Table>
```

**Use children for content slots:**
```typescript
// Flexible — caller controls content
<Card header={<InvoiceHeader />} footer={<InvoiceActions />}>
  <InvoiceDetails invoice={invoice} />
</Card>
```

## Server vs Client Component Decision

Server Component (default, no directive):
- Fetches its own data
- Has no user interaction
- Uses no browser APIs
- Can be async

Client Component (`'use client'`):
- Has useState, useEffect, or any React hook
- Has event handlers (onClick, onChange)
- Uses browser APIs (localStorage, window, document)
- Has animations or transitions

Push `'use client'` as deep as possible — only the interactive part needs to be a client component.

```typescript
// Good pattern: Server Component wraps Client Component
async function InvoicePage() {  // Server Component (no 'use client')
  const invoice = await fetchInvoice()  // Server-side data fetch
  
  return (
    <InvoiceLayout invoice={invoice}>
      <InvoiceStatusDropdown  // Client Component ('use client')
        currentStatus={invoice.status}
        invoiceId={invoice.id}
      />
    </InvoiceLayout>
  )
}
```

## Loading States

```typescript
// Loading skeleton — prevents layout shift during data load
function InvoiceCardSkeleton() {
  return (
    <Card>
      <CardContent>
        <div className="animate-pulse space-y-3">
          <div className="h-4 bg-gray-200 rounded w-3/4" />
          <div className="h-4 bg-gray-200 rounded w-1/2" />
        </div>
      </CardContent>
    </Card>
  )
}

// Use in Suspense
<Suspense fallback={<InvoiceCardSkeleton />}>
  <InvoiceCard id={id} />
</Suspense>
```

## Error Boundaries

For sections that can fail independently:
```typescript
import { ErrorBoundary } from 'react-error-boundary'

function InvoiceSection() {
  return (
    <ErrorBoundary
      fallback={<div className="text-red-500">Failed to load invoices</div>}
    >
      <InvoiceList />
    </ErrorBoundary>
  )
}
```

## Naming Conventions

- Component files: `PascalCase.tsx` (matches component name)
- Hook files: `use-hook-name.ts` (kebab with `use` prefix)
- Utility files: `kebab-case.ts`
- Page files: `page.tsx` (Next.js convention, fixed)
- Export: named exports for components (allows tree-shaking and refactoring tools)

```typescript
// Named export (preferred)
export function InvoiceCard() { }

// Default export (only for Next.js pages/layouts — required by framework)
export default function Page() { }
```
