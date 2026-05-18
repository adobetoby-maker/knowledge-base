# Next.js Loading States

## The Three Loading Mechanisms

1. **`loading.tsx`** — automatic Suspense boundary for page-level loading
2. **`<Suspense>`** — component-level streaming for partial page loading
3. **`useFormStatus` / `useTransition`** — client-side action loading states

## loading.tsx (Instant Page Shell)

`loading.tsx` next to a `page.tsx` creates a Suspense boundary. The loading UI appears instantly while the page's async data fetches.

```typescript
// app/portal/invoices/loading.tsx
export default function InvoicesLoading() {
  return (
    <div className="space-y-4">
      <div className="h-8 w-48 rounded bg-muted animate-pulse" />
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="h-16 rounded-lg border bg-card animate-pulse" />
      ))}
    </div>
  )
}
```

The loading UI shows immediately on navigation — no blank screen. Next.js handles the Suspense wrapping automatically.

## Suspense for Partial Loading

Use `<Suspense>` to show a page shell while a slow section loads:

```typescript
// app/portal/dashboard/page.tsx
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div className="grid gap-6 md:grid-cols-2">
      {/* Fast — shows immediately */}
      <QuickStats />
      
      {/* Slow — streams in independently */}
      <Suspense fallback={<InvoiceSummaryLoading />}>
        <InvoiceSummary />
      </Suspense>
      
      <Suspense fallback={<RecentActivityLoading />}>
        <RecentActivity />
      </Suspense>
    </div>
  )
}
```

`InvoiceSummary` and `RecentActivity` are async Server Components that fetch data. They stream in independently as each one completes.

## Skeleton Components

Skeletons mimic the shape of the real content:

```typescript
// components/ui/skeleton.tsx
export function Skeleton({ className }: { className?: string }) {
  return <div className={`animate-pulse rounded-md bg-muted ${className ?? ''}`} />
}

// components/invoice/invoice-card-skeleton.tsx
export function InvoiceCardSkeleton() {
  return (
    <div className="rounded-lg border p-4 space-y-3">
      <div className="flex items-center justify-between">
        <Skeleton className="h-4 w-24" />
        <Skeleton className="h-6 w-16 rounded-full" />
      </div>
      <Skeleton className="h-4 w-32" />
      <Skeleton className="h-4 w-20" />
    </div>
  )
}

// Loading state for a list
export function InvoiceListSkeleton({ count = 5 }: { count?: number }) {
  return (
    <div className="space-y-3">
      {Array.from({ length: count }).map((_, i) => (
        <InvoiceCardSkeleton key={i} />
      ))}
    </div>
  )
}
```

## Form Loading with useFormStatus

```typescript
// components/submit-button.tsx
'use client'
import { useFormStatus } from 'react-dom'
import { Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button'

export function SubmitButton({ children }: { children: React.ReactNode }) {
  const { pending } = useFormStatus()
  
  return (
    <Button type="submit" disabled={pending}>
      {pending && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
      {children}
    </Button>
  )
}

// Usage — must be inside a <form> that uses Server Action
<form action={createInvoice}>
  <input name="customer_name" />
  <SubmitButton>Create Invoice</SubmitButton>  {/* automatically shows loading */}
</form>
```

`useFormStatus` only works inside a component that is a child of a `<form>` — it cannot be in the same component as the form.

## useTransition for Non-Form Actions

```typescript
'use client'
import { useTransition } from 'react'
import { deleteInvoice } from '@/app/actions/invoices'
import { Loader2, Trash2 } from 'lucide-react'

export function DeleteButton({ invoiceId }: { invoiceId: string }) {
  const [isPending, startTransition] = useTransition()
  
  function handleDelete() {
    startTransition(async () => {
      await deleteInvoice(invoiceId)
    })
  }
  
  return (
    <button onClick={handleDelete} disabled={isPending}>
      {isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Trash2 className="h-4 w-4" />}
    </button>
  )
}
```

## Error State alongside Loading

Always design both loading and error states:

```typescript
// app/portal/invoices/page.tsx
export default async function InvoicesPage() {
  const supabase = await createClient()
  const { data: invoices, error } = await supabase.from('invoices').select('*')
  
  if (error) {
    return (
      <div className="text-center py-12">
        <AlertCircle className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
        <p>Failed to load invoices. Please refresh.</p>
      </div>
    )
  }
  
  if (!invoices?.length) {
    return (
      <div className="text-center py-12">
        <FileText className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
        <p>No invoices yet.</p>
      </div>
    )
  }
  
  return <InvoiceList invoices={invoices} />
}
```

## Progressive Loading Hierarchy

Layer loading states from coarsest to finest:
1. `loading.tsx` — page-level skeleton (appears in ~50ms)
2. `<Suspense>` — section-level skeletons (stream in as data loads)
3. Component-level spinners — for user-triggered actions (button clicks, mutations)

Don't add loading states at every level — that creates "loading inception" where users see 3+ spinners simultaneously. Load the page shell, then stream in the sections.
