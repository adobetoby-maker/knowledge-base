# Failure Patterns: TanStack Query Issues

## Stale Data After Mutation

After a mutation, the query cache still has old data. The page doesn't update.

```typescript
// WRONG — mutation succeeds but UI doesn't update:
const mutation = useMutation({
  mutationFn: deleteInvoice,
  // No cache invalidation
})

// CORRECT — invalidate the relevant queries:
const queryClient = useQueryClient()

const mutation = useMutation({
  mutationFn: deleteInvoice,
  onSuccess: () => {
    // Invalidate all queries that might have invoice data:
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
    queryClient.invalidateQueries({ queryKey: ['invoice-stats'] })
  },
})
```

`invalidateQueries` marks queries stale and refetches them. Use it after every mutation.

## Wrong Query Key Invalidation

```typescript
// Query defined as:
useQuery({ queryKey: ['invoices', customerId] })

// WRONG — invalidation doesn't match:
queryClient.invalidateQueries({ queryKey: ['invoices'] })
// This DOES match — ['invoices', customerId] starts with ['invoices']
// TanStack Query uses prefix matching by default

// If you only want exact match:
queryClient.invalidateQueries({ queryKey: ['invoices', customerId], exact: true })
```

Prefix matching is usually what you want. `['invoices']` invalidates `['invoices']`, `['invoices', 'abc']`, `['invoices', 'abc', { page: 1 }]`.

## Infinite Refetch Loop

Cause: query key contains a new object reference on every render:

```typescript
// WRONG — filters object recreated each render:
function InvoiceList({ status }: { status: string }) {
  const filters = { status, page: 1 }  // new object each render
  
  useQuery({
    queryKey: ['invoices', filters],  // new key each render → infinite refetch
    queryFn: () => fetchInvoices(filters),
  })
}

// CORRECT — use primitive values or stable references:
useQuery({
  queryKey: ['invoices', status, 1],  // primitives are stable
  queryFn: () => fetchInvoices({ status, page: 1 }),
})
```

## Query Runs Before Authentication

```typescript
// WRONG — query fires even when user isn't loaded yet:
const { data: invoices } = useQuery({
  queryKey: ['invoices'],
  queryFn: fetchInvoices,
})

// CORRECT — enable only when user exists:
const { user } = useAuth()

const { data: invoices } = useQuery({
  queryKey: ['invoices', user?.id],
  queryFn: fetchInvoices,
  enabled: !!user,  // don't run until user is available
})
```

## Missing Error Boundary for Query Errors

By default, TanStack Query doesn't throw errors to React boundaries — it returns them in the `error` field. You have to handle it:

```typescript
// WRONG — error silently not shown:
function InvoiceList() {
  const { data } = useQuery({ queryKey: ['invoices'], queryFn: fetchInvoices })
  return <Table data={data ?? []} />  // shows empty table on error
}

// CORRECT — handle the error state:
function InvoiceList() {
  const { data, error, isError } = useQuery({ queryKey: ['invoices'], queryFn: fetchInvoices })
  
  if (isError) return <Alert>Failed to load invoices: {error.message}</Alert>
  
  return <Table data={data ?? []} />
}
```

## Optimistic Updates Out of Sync

```typescript
// Optimistic update pattern — update UI immediately, rollback on failure:
const mutation = useMutation({
  mutationFn: updateInvoiceStatus,
  
  onMutate: async ({ invoiceId, status }) => {
    // Cancel in-flight queries to prevent overwriting optimistic update:
    await queryClient.cancelQueries({ queryKey: ['invoices'] })
    
    // Snapshot current data for rollback:
    const previousData = queryClient.getQueryData(['invoices'])
    
    // Optimistically update:
    queryClient.setQueryData(['invoices'], (old: Invoice[]) =>
      old.map(inv => inv.id === invoiceId ? { ...inv, status } : inv)
    )
    
    return { previousData }  // passed to onError
  },
  
  onError: (error, variables, context) => {
    // Rollback on failure:
    queryClient.setQueryData(['invoices'], context?.previousData)
  },
  
  onSettled: () => {
    // Always refetch to get server truth:
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  },
})
```

## Subscriptions Not Cleaned Up

When combining TanStack Query with Supabase realtime, the subscription must be cleaned up:

```typescript
useEffect(() => {
  const channel = supabase
    .channel('invoices-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, () => {
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
    })
    .subscribe()
  
  return () => {
    supabase.removeChannel(channel)  // MUST cleanup — memory leak otherwise
  }
}, [queryClient])
```

React StrictMode in development calls effects twice — if cleanup isn't implemented, you'll have duplicate subscriptions.
