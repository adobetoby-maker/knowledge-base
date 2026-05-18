# React Query / TanStack Query Common Failures

## 1. queryKey Mismatch Between Query and Invalidation

**Symptom:** `queryClient.invalidateQueries()` doesn't trigger a refetch.

**Cause:** The key passed to `invalidateQueries` doesn't match the `queryKey` in the query.

```typescript
// Query registered with:
useQuery({ queryKey: ['invoices', customerId] })

// WRONG: doesn't match
queryClient.invalidateQueries({ queryKey: ['invoice'] })
queryClient.invalidateQueries({ queryKey: ['invoices'] })  // partial match depends on exact: false

// CORRECT: matches with prefix (invalidateQueries uses partial matching by default)
queryClient.invalidateQueries({ queryKey: ['invoices', customerId] })

// To invalidate ALL invoice queries regardless of customerId:
queryClient.invalidateQueries({ queryKey: ['invoices'] })
// This works because invalidateQueries matches by prefix (not exact) by default
```

## 2. Stale Time Not Set — Constant Refetching

**Symptom:** Query refetches on every component mount, causing flickering and unnecessary API calls.

**Cause:** Default `staleTime` is 0 — data is considered stale immediately and refetched on focus/remount.

```typescript
// BAD: default staleTime=0 causes constant refetching
const { data } = useQuery({ queryKey: ['invoices'], queryFn: fetchInvoices })

// GOOD: set staleTime appropriate to the data
const { data } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
  staleTime: 5 * 60 * 1000,   // 5 minutes — invoices don't change frequently
  gcTime: 10 * 60 * 1000,     // keep in cache for 10 minutes after last use
})
```

## 3. QueryClient Not Provided

**Symptom:** Error: "No QueryClient set, use QueryClientProvider..."

**Cause:** A component using `useQuery` or `useMutation` is outside the `QueryClientProvider`.

```typescript
// FIX: wrap your layout or page with QueryClientProvider
// In Next.js App Router, this must be in a Client Component:

'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,
        retry: 1,
      },
    },
  }))

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}
```

Don't create `new QueryClient()` outside the component — it's shared across all server renders in SSR.

## 4. Mutation Doesn't Update UI

**Symptom:** Mutation succeeds (data saved to DB) but UI still shows old data.

**Cause:** Mutation doesn't invalidate or update the query cache after success.

```typescript
// BAD: no cache update after mutation
const mutation = useMutation({
  mutationFn: updateInvoiceStatus,
  // UI still shows old status ← missing invalidation
})

// GOOD: invalidate after mutation
const mutation = useMutation({
  mutationFn: updateInvoiceStatus,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  },
})

// BETTER (no refetch needed): update cache directly
const mutation = useMutation({
  mutationFn: updateInvoiceStatus,
  onSuccess: (_, { invoiceId, status }) => {
    queryClient.setQueryData(['invoices'], (old: Invoice[] = []) =>
      old.map(inv => inv.id === invoiceId ? { ...inv, status } : inv)
    )
  },
})
```

## 5. useQuery in Server Component

**Symptom:** Error: "hooks can only be called in a Client Component."

**Cause:** `useQuery` is a React hook — it requires a Client Component (`'use client'`).

```typescript
// BAD: useQuery in Server Component
// app/(portal)/invoices/page.tsx (Server Component by default)
export default async function InvoicesPage() {
  const { data } = useQuery(...)  // Error!
}

// GOOD: fetch directly in Server Component
export default async function InvoicesPage() {
  const supabase = createClient()
  const { data: invoices } = await supabase.from('invoices').select('*')
  return <InvoiceList initialInvoices={invoices} />
}

// Then useQuery for client-side updates in the Client Component
```

## 6. Optimistic Update Rollback Not Working

**Symptom:** On mutation error, UI doesn't roll back to previous state.

**Cause:** Optimistic update pattern requires saving the previous state in `onMutate` and restoring it in `onError`.

```typescript
const mutation = useMutation({
  mutationFn: deleteInvoice,
  onMutate: async (invoiceId) => {
    await queryClient.cancelQueries({ queryKey: ['invoices'] })
    
    // Save current state BEFORE optimistic update
    const previousInvoices = queryClient.getQueryData(['invoices'])
    
    // Apply optimistic update
    queryClient.setQueryData(['invoices'], (old: Invoice[] = []) =>
      old.filter(inv => inv.id !== invoiceId)
    )
    
    // Return context with previous state
    return { previousInvoices }
  },
  onError: (err, invoiceId, context) => {
    // Restore previous state on error
    if (context?.previousInvoices) {
      queryClient.setQueryData(['invoices'], context.previousInvoices)
    }
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  },
})
```
