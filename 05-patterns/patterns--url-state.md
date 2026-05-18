# URL State Management Pattern

## When to Use URL State

URL state is the right tool when the state should be:
- **Shareable** — paste the URL and another person sees the same thing
- **Bookmarkable** — user can bookmark a filtered/sorted view
- **Navigatable** — back button restores previous state
- **SEO-relevant** — search engines can index filtered views

Common use cases:
- Search queries (`?q=invoice`)
- Filter state (`?status=pending&year=2026`)
- Pagination (`?page=3`)
- Sort order (`?sort=amount&dir=desc`)
- Selected tab (`?tab=invoices`)
- Modal open state (simple dialogs)

## Reading Search Params

```typescript
// Server Component (async)
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: string; page?: string }>
}) {
  const { q = '', status = 'all', page = '1' } = await searchParams
  const currentPage = parseInt(page)
  
  // Use params in data fetching
  const invoices = await fetchInvoices({ q, status, page: currentPage })
  
  return (
    <div>
      <InvoiceFilters currentQ={q} currentStatus={status} />
      <InvoiceList invoices={invoices} />
      <Pagination currentPage={currentPage} />
    </div>
  )
}
```

```typescript
// Client Component
'use client'
import { useSearchParams } from 'next/navigation'

export function InvoiceFilters() {
  const searchParams = useSearchParams()
  const currentStatus = searchParams.get('status') ?? 'all'
  
  return (
    <div>
      {['all', 'pending', 'paid', 'overdue'].map(status => (
        <StatusButton key={status} status={status} isActive={currentStatus === status} />
      ))}
    </div>
  )
}
```

## Updating Search Params

```typescript
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback } from 'react'

export function useURLState() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()

  const setParam = useCallback((key: string, value: string | null) => {
    const params = new URLSearchParams(searchParams.toString())
    
    if (value === null || value === '') {
      params.delete(key)
    } else {
      params.set(key, value)
    }
    
    // Reset page when filter changes
    if (key !== 'page') params.delete('page')
    
    router.push(`${pathname}?${params.toString()}`, { scroll: false })
  }, [router, pathname, searchParams])

  const setParams = useCallback((updates: Record<string, string | null>) => {
    const params = new URLSearchParams(searchParams.toString())
    
    Object.entries(updates).forEach(([key, value]) => {
      if (value === null || value === '') params.delete(key)
      else params.set(key, value)
    })
    
    router.push(`${pathname}?${params.toString()}`, { scroll: false })
  }, [router, pathname, searchParams])

  return { setParam, setParams }
}
```

## Filter Bar Component

```typescript
'use client'
import { useURLState } from '@/hooks/use-url-state'
import { useSearchParams } from 'next/navigation'
import { Input } from '@/components/ui/input'
import { useRef, useEffect } from 'react'
import { useDebounce } from '@/hooks/use-debounce'

export function InvoiceFilterBar() {
  const searchParams = useSearchParams()
  const { setParam, setParams } = useURLState()
  
  const currentQ = searchParams.get('q') ?? ''
  const currentStatus = searchParams.get('status') ?? 'all'

  return (
    <div className="flex gap-3 items-center">
      <SearchInput
        defaultValue={currentQ}
        onSearch={(q) => setParam('q', q)}
      />
      <StatusFilter
        value={currentStatus}
        onChange={(status) => setParam('status', status === 'all' ? null : status)}
      />
      {(currentQ || currentStatus !== 'all') && (
        <button onClick={() => setParams({ q: null, status: null })}>
          Clear filters
        </button>
      )}
    </div>
  )
}

// Debounced search input that updates URL
function SearchInput({ defaultValue, onSearch }: { defaultValue: string; onSearch: (q: string) => void }) {
  const [value, setValue] = useState(defaultValue)
  const debouncedValue = useDebounce(value, 300)
  
  useEffect(() => {
    onSearch(debouncedValue)
  }, [debouncedValue])
  
  return (
    <Input
      value={value}
      onChange={e => setValue(e.target.value)}
      placeholder="Search..."
    />
  )
}
```

## Shallow vs Deep Navigation

```typescript
// Shallow: updates URL without full page navigation
// Good for: filters on the same page
router.push(`${pathname}?${params}`, { scroll: false })

// Replace instead of push (no browser history entry)
// Good for: paginating (don't pollute history with every page change)
router.replace(`${pathname}?${params}`, { scroll: false })
```

Use `replace` for pagination so the back button goes back to the previous page, not to page 2 of the same list.

## SEO Consideration

URL state that changes the content should be crawlable. Avoid:
- Blocking crawlers from paginated pages (pagination should be crawlable)
- Hash-based state (`#tab=invoices`) — Google doesn't index hash fragments

Use `<link rel="canonical">` to consolidate filtered views if needed.
