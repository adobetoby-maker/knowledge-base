# Plugin: TanStack Query (React Query)

## What It Does

TanStack Query is a server state management library for React. It handles fetching, caching, synchronizing, and updating remote data. It replaces the `useState + useEffect + fetch` pattern with a declarative data model.

The core insight: server state (data from APIs) has fundamentally different requirements from client state (UI state). Server state is async, potentially stale, owned by a remote source, and shared across the app. TanStack Query manages all of this automatically.

## Setup

```typescript
// app/providers.tsx
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,  // 1 minute before considering data stale
      retry: 1,
    }
  }
})

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}
```

## useQuery — Fetching Data

```typescript
import { useQuery } from '@tanstack/react-query'

function InvoiceList() {
  const { data: invoices, isLoading, error, refetch } = useQuery({
    queryKey: ['invoices'],
    queryFn: async () => {
      const response = await fetch('/api/invoices')
      if (!response.ok) throw new Error('Failed to fetch')
      return response.json() as Promise<Invoice[]>
    },
    staleTime: 5 * 60 * 1000,  // 5 minutes
  })
  
  if (isLoading) return <Spinner />
  if (error) return <ErrorMessage error={error} />
  
  return <ul>{invoices?.map(inv => <InvoiceRow key={inv.id} invoice={inv} />)}</ul>
}
```

## Query Key Design

Query keys are how TanStack Query identifies and invalidates cached data. Design them hierarchically:

```typescript
// Collection
queryKey: ['invoices']

// Item
queryKey: ['invoices', invoiceId]

// Filtered collection
queryKey: ['invoices', { status: 'pending', userId }]

// Nested resource
queryKey: ['invoices', invoiceId, 'line-items']
```

Invalidate by partial key match:
```typescript
// Invalidate all invoice queries
queryClient.invalidateQueries({ queryKey: ['invoices'] })

// Invalidate only queries for this specific invoice
queryClient.invalidateQueries({ queryKey: ['invoices', invoiceId] })
```

## useMutation — Modifying Data

```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query'

function CreateInvoiceButton() {
  const queryClient = useQueryClient()
  
  const mutation = useMutation({
    mutationFn: async (data: CreateInvoiceInput) => {
      const response = await fetch('/api/invoices', {
        method: 'POST',
        body: JSON.stringify(data),
        headers: { 'Content-Type': 'application/json' }
      })
      if (!response.ok) throw new Error('Failed to create')
      return response.json()
    },
    onSuccess: () => {
      // Invalidate and refetch invoice list
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
    },
    onError: (error) => {
      toast({ title: 'Error', description: error.message, variant: 'destructive' })
    }
  })
  
  return (
    <Button
      onClick={() => mutation.mutate({ amount: 150, description: 'Oil change' })}
      disabled={mutation.isPending}
    >
      {mutation.isPending ? 'Creating...' : 'Create Invoice'}
    </Button>
  )
}
```

## Optimistic Updates

For fast UI (show change immediately, roll back if it fails):

```typescript
const mutation = useMutation({
  mutationFn: updateInvoiceStatus,
  onMutate: async (newStatus) => {
    // Cancel any refetches
    await queryClient.cancelQueries({ queryKey: ['invoices', invoiceId] })
    
    // Snapshot current value
    const previousInvoice = queryClient.getQueryData(['invoices', invoiceId])
    
    // Optimistically update
    queryClient.setQueryData(['invoices', invoiceId], old => ({
      ...old, status: newStatus
    }))
    
    return { previousInvoice }
  },
  onError: (err, newStatus, context) => {
    // Roll back on error
    queryClient.setQueryData(['invoices', invoiceId], context?.previousInvoice)
  },
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['invoices', invoiceId] })
  }
})
```

## prefetchQuery — SSR Integration

In Next.js App Router, prefetch data in Server Components and hydrate on the client:

```typescript
// app/invoices/page.tsx (Server Component)
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'

export default async function InvoicesPage() {
  const queryClient = new QueryClient()
  
  await queryClient.prefetchQuery({
    queryKey: ['invoices'],
    queryFn: getInvoicesFromDB,
  })
  
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <InvoiceList />
    </HydrationBoundary>
  )
}
```

The client `InvoiceList` receives pre-populated cache — no loading state on first render.

## Dependent Queries

```typescript
// Only runs after userId is available
const { data: profile } = useQuery({
  queryKey: ['profile', userId],
  queryFn: () => fetchProfile(userId),
  enabled: !!userId,  // disabled until userId is truthy
})
```
