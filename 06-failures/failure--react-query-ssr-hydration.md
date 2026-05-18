# Failure: React Query SSR Hydration Mismatch

## Overview
React Query's server-side rendering pattern requires explicitly dehydrating the query cache on the server and rehydrating it on the client. When this wiring is missing or mismatched, you get hydration errors (server HTML doesn't match client render) or unnecessary refetches immediately after page load (flickering). The common mistake: prefetching data on the server but forgetting to pass it to the client via `HydrationBoundary`.

## The Full SSR Pattern

```tsx
// app/invoices/page.tsx — Server Component
import { dehydrate, HydrationBoundary, QueryClient } from '@tanstack/react-query'
import { InvoiceList } from './invoice-list'

export default async function InvoicesPage() {
  const queryClient = new QueryClient()

  // Prefetch on server — populates the server-side cache
  await queryClient.prefetchQuery({
    queryKey: ['invoices'],
    queryFn: fetchInvoices,  // runs server-side
  })

  return (
    // Pass dehydrated state to client
    <HydrationBoundary state={dehydrate(queryClient)}>
      <InvoiceList />
    </HydrationBoundary>
  )
}
```

```tsx
// app/invoices/invoice-list.tsx — Client Component
'use client'
import { useQuery } from '@tanstack/react-query'

export function InvoiceList() {
  // On first render: reads from hydrated cache (no network request)
  const { data } = useQuery({
    queryKey: ['invoices'],  // must match prefetchQuery key exactly
    queryFn: fetchInvoices,
    staleTime: 60 * 1000,    // 1 minute before refetch
  })

  return <ul>{data?.map(inv => <li key={inv.id}>{inv.total}</li>)}</ul>
}
```

## The `staleTime` Issue

Without `staleTime`, data prefetched on the server is considered immediately stale, triggering a refetch on hydration:

```tsx
// BAD — data considered stale immediately, triggers refetch → flicker
const { data } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
  // staleTime defaults to 0 → immediate refetch
})

// GOOD — give the data time before it's considered stale
const { data } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
  staleTime: 60 * 1000,   // data fresh for 1 minute after fetch
})

// For data that shouldn't auto-refetch at all (static content)
const { data } = useQuery({
  queryKey: ['categories'],
  queryFn: fetchCategories,
  staleTime: Infinity,    // never considered stale
})
```

## QueryKey Must Match Exactly

```tsx
// Server prefetch
await queryClient.prefetchQuery({
  queryKey: ['invoices', { status: 'pending' }],  // has filter
  queryFn: () => fetchInvoices({ status: 'pending' }),
})

// Client query — must match EXACTLY
const { data } = useQuery({
  queryKey: ['invoices', { status: 'pending' }],  // matches — uses cache
  queryFn: () => fetchInvoices({ status: 'pending' }),
})

// This would NOT match and cause a new fetch:
const { data } = useQuery({
  queryKey: ['invoices'],  // missing filter — different cache entry
  queryFn: fetchInvoices,
})
```

React Query uses deep equality on query keys. Order of object properties matters.

## QueryClient Per Request

```tsx
// BAD — shared QueryClient across requests leaks data between users
const queryClient = new QueryClient()  // module-level = shared

// GOOD — new QueryClient per server request
export default async function Page() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60 * 1000 },
    },
  })
  // ...
}
```

## Provider Setup

```tsx
// app/providers.tsx — wrap the whole app
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  // useState ensures each client instance has its own QueryClient
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: { staleTime: 60 * 1000 },
    },
  }))

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  )
}
```

## Key Rules
- Create a new `QueryClient` per SSR request — never share at module scope
- `HydrationBoundary state={dehydrate(queryClient)}` must wrap the component that uses the data
- Query keys on server (`prefetchQuery`) and client (`useQuery`) must match byte-for-byte
- Set `staleTime > 0` for prefetched data — otherwise it refetches immediately on mount
- `dehydrate()` serializes the cache; `HydrationBoundary` injects it into the client `QueryClient`
- For mutations: don't prefetch mutation results — only use this pattern for queries
