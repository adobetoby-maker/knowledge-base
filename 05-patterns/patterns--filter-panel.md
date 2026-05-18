# Filter Panel Pattern

## URL-Based State (Always Preferred)

Filters belong in the URL. This makes them bookmarkable, shareable, and works on page reload.

```typescript
// app/(admin)/invoices/page.tsx
interface SearchParams {
  status?: string
  customer?: string
  from?: string
  to?: string
  page?: string
}

export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const params = await searchParams
  
  const invoices = await fetchInvoices({
    status: params.status,
    customer: params.customer,
    from: params.from,
    to: params.to,
    page: Number(params.page) || 1,
  })
  
  return (
    <div className="space-y-4">
      <FilterBar />          {/* client component */}
      <InvoiceTable data={invoices} />
    </div>
  )
}
```

## Filter Bar Component

```typescript
// components/FilterBar.tsx
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useTransition } from 'react'

export function FilterBar() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [isPending, startTransition] = useTransition()
  
  function setFilter(key: string, value: string) {
    const params = new URLSearchParams(searchParams.toString())
    if (value) {
      params.set(key, value)
    } else {
      params.delete(key)
    }
    params.delete('page')  // reset to page 1 on filter change
    startTransition(() => {
      router.push(`${pathname}?${params.toString()}`)
    })
  }
  
  return (
    <div className="flex gap-2 flex-wrap">
      <Select
        value={searchParams.get('status') ?? ''}
        onValueChange={(v) => setFilter('status', v)}
      >
        <SelectTrigger className="w-[140px]">
          <SelectValue placeholder="All statuses" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="">All</SelectItem>
          <SelectItem value="paid">Paid</SelectItem>
          <SelectItem value="pending">Pending</SelectItem>
          <SelectItem value="overdue">Overdue</SelectItem>
        </SelectContent>
      </Select>
      
      <DateRangePicker
        from={searchParams.get('from') ?? undefined}
        to={searchParams.get('to') ?? undefined}
        onChange={(from, to) => {
          const params = new URLSearchParams(searchParams.toString())
          if (from) params.set('from', from); else params.delete('from')
          if (to) params.set('to', to); else params.delete('to')
          params.delete('page')
          startTransition(() => router.push(`${pathname}?${params.toString()}`))
        }}
      />
      
      {isPending && <Loader2 className="h-4 w-4 animate-spin" />}
      
      {/* Show clear button only when filters are active */}
      {(searchParams.get('status') || searchParams.get('from')) && (
        <Button
          variant="ghost"
          size="sm"
          onClick={() => router.push(pathname)}
        >
          Clear filters
        </Button>
      )}
    </div>
  )
}
```

## Active Filter Chips

Show what's currently filtered so users can remove individual filters:

```typescript
function ActiveFilters() {
  const searchParams = useSearchParams()
  const router = useRouter()
  const pathname = usePathname()
  
  const active = [
    searchParams.get('status') && { key: 'status', label: `Status: ${searchParams.get('status')}` },
    searchParams.get('customer') && { key: 'customer', label: `Customer: ${searchParams.get('customer')}` },
  ].filter(Boolean)
  
  if (active.length === 0) return null
  
  return (
    <div className="flex gap-2 flex-wrap">
      {active.map(filter => (
        <Badge key={filter.key} variant="secondary" className="gap-1">
          {filter.label}
          <button
            onClick={() => {
              const params = new URLSearchParams(searchParams.toString())
              params.delete(filter.key)
              router.push(`${pathname}?${params.toString()}`)
            }}
          >
            <X className="h-3 w-3" />
          </button>
        </Badge>
      ))}
    </div>
  )
}
```

## Search Input with Debounce

Avoid pushing a URL on every keystroke — debounce to 300ms:

```typescript
function SearchInput() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [value, setValue] = useState(searchParams.get('q') ?? '')
  
  const debouncedSearch = useMemo(
    () => debounce((q: string) => {
      const params = new URLSearchParams(searchParams.toString())
      if (q) params.set('q', q); else params.delete('q')
      params.delete('page')
      router.push(`${pathname}?${params.toString()}`)
    }, 300),
    [router, pathname, searchParams]
  )
  
  return (
    <Input
      value={value}
      onChange={(e) => {
        setValue(e.target.value)
        debouncedSearch(e.target.value)
      }}
      placeholder="Search invoices..."
    />
  )
}
```

## Database Query from Filters

```typescript
async function fetchInvoices({ status, customer, from, to, page }) {
  let query = supabase
    .from('invoices')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * 20, page * 20 - 1)
  
  if (status) query = query.eq('status', status)
  if (customer) query = query.ilike('customer_name', `%${customer}%`)
  if (from) query = query.gte('created_at', from)
  if (to) query = query.lte('created_at', to + 'T23:59:59')
  
  const { data, count } = await query
  return { data, count, totalPages: Math.ceil((count ?? 0) / 20) }
}
```

## Anti-Pattern: State-Based Filters

Client state (`useState`) for filters breaks: back button, bookmarks, sharing URLs, and page refresh. The URL IS the state for filters.
