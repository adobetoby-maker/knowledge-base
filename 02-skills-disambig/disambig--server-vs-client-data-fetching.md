# Disambiguation: Server vs Client Data Fetching

## The Short Answer

Fetch in Server Components by default. Add client-side fetching only when you need real-time updates, client-dependent state (user preferences), or post-interaction refetching.

## Server Component Fetching (Default)

```typescript
// app/(admin)/invoices/page.tsx
// Server Component — fetch directly, no useEffect or useQuery

export default async function InvoicesPage() {
  // Direct DB call — runs on server, not sent to browser
  const { data: invoices } = await supabase
    .from('invoices')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(20)
  
  return <InvoiceTable data={invoices ?? []} />
}
```

**When this is the right choice:**
- Data for the initial page render
- Data that doesn't change after load
- Auth-required data (avoid waterfall)
- SEO-important content (server renders full HTML)

## Client Fetching with TanStack Query

```typescript
// 'use client'
// For data that changes based on user interaction

export function InvoiceTable() {
  const { data: invoices = [], isLoading } = useQuery({
    queryKey: ['invoices', filters],
    queryFn: () => fetchInvoices(filters),
  })
  
  if (isLoading) return <TableSkeleton />
  return <DataTable data={invoices} columns={columns} />
}
```

**When this is the right choice:**
- Data that updates based on client state (current filter, selected tab)
- Data you want to refetch after mutations (invalidateQueries)
- Real-time poll (refetchInterval)
- Data shared between components that would otherwise re-fetch

## Hybrid: Server Initial + Client Sync

Best for admin tables — fast initial load, live updates after mutations:

```typescript
// Server Component passes initial data:
export default async function InvoicesPage() {
  const invoices = await fetchInvoices()
  return <InvoiceTable initialData={invoices} />
}

// Client Component receives initialData, then manages updates:
'use client'
export function InvoiceTable({ initialData }: { initialData: Invoice[] }) {
  const { data: invoices = initialData } = useQuery({
    queryKey: ['invoices'],
    queryFn: fetchInvoices,
    initialData,  // show server data immediately, hydrate seamlessly
    staleTime: 30_000,  // 30s before considering stale
  })
}
```

## The Waterfall Problem

Avoid sequential server fetches in the same component:

```typescript
// SLOW — serial waterfall:
const user = await fetchUser(userId)
const invoices = await fetchUserInvoices(user.id)  // waits for user first

// FAST — parallel:
const [user, invoices] = await Promise.all([
  fetchUser(userId),
  fetchUserInvoices(userId),  // use the ID directly
])
```

## Streaming with Suspense

For independent sections, fetch in parallel at the component level:

```typescript
// page.tsx:
export default function Dashboard() {
  return (
    <div className="grid grid-cols-3 gap-4">
      <Suspense fallback={<StatsSkeleton />}>
        <DashboardStats />  {/* fetches independently */}
      </Suspense>
      <Suspense fallback={<ListSkeleton />}>
        <RecentActivity />  {/* fetches independently */}
      </Suspense>
    </div>
  )
}
```

Each Server Component fetches its own data. They run concurrently — the page isn't blocked waiting for the slowest one.

## Decision Matrix

| Scenario | Where to Fetch |
|---|---|
| Initial page data | Server Component |
| Admin table with filters (URL state) | Server Component with `searchParams` |
| Client-side filter changes | TanStack Query |
| Post-mutation data sync | TanStack Query `invalidateQueries` |
| Real-time updates | Supabase realtime subscription (client) |
| User preferences affecting content | Client (preferences are client state) |
| Large tables with client-side sort | TanStack Query with `keepPreviousData` |
| Public pages for SEO | Server Component (fully rendered HTML) |
