# URL as State

## The Principle

Shareable, bookmarkable state belongs in the URL. When in doubt about whether something should be in URL params or `useState`, ask: "Would a user want to copy this URL and send it to someone?"

- Filters, search query, sort order, page number → URL
- Selected tab, active modal, open dropdown → URL or component state (depends on shareability)
- Form field values, loading flags, transient UI → component state

## Why URL State Matters

1. **Shareability** — `/invoices?status=overdue&page=2` is a link you can send
2. **Bookmark** — users can bookmark filtered views
3. **Back/forward** — browser navigation works correctly
4. **Direct linking** — deep links work without requiring navigation
5. **Refresh** — state survives F5

## Implementation (Next.js App Router)

```typescript
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback } from 'react'

export function useURLState<T extends Record<string, string | string[] | undefined>>(defaults: T) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  
  function get<K extends keyof T>(key: K): T[K] {
    const value = searchParams.get(String(key))
    return (value ?? defaults[key]) as T[K]
  }
  
  const set = useCallback((updates: Partial<T>) => {
    const params = new URLSearchParams(searchParams.toString())
    
    Object.entries(updates).forEach(([key, value]) => {
      if (value === undefined || value === defaults[key]) {
        params.delete(key)  // clean URL — omit default values
      } else if (Array.isArray(value)) {
        params.delete(key)
        value.forEach(v => params.append(key, v))
      } else {
        params.set(key, String(value))
      }
    })
    
    const query = params.toString()
    router.replace(`${pathname}${query ? `?${query}` : ''}`, { scroll: false })
  }, [router, pathname, searchParams, defaults])
  
  return { get, set }
}

// Usage:
function InvoiceFilters() {
  const { get, set } = useURLState({ status: '', page: '1', sort: 'created_at' })
  
  const status = get('status')
  const page = parseInt(get('page'))
  
  return (
    <div className="flex gap-2">
      <Select value={status} onValueChange={v => set({ status: v, page: '1' })}>
        {/* options */}
      </Select>
      <Input
        placeholder="Search..."
        onChange={e => set({ search: e.target.value, page: '1' })}  // reset page on new search
      />
    </div>
  )
}
```

## Clean URLs (Omit Defaults)

Don't put default values in the URL — it makes URLs longer and less shareable:

```
BAD:  /invoices?status=all&page=1&sort=created_at&dir=desc
GOOD: /invoices?status=overdue
```

When a parameter matches its default, remove it from the URL. When all parameters match defaults, no query string.

## Router Push vs Replace

```typescript
// replace: for filter changes — don't pollute browser history:
router.replace(`${pathname}?${params}`, { scroll: false })

// push: for page navigation — back button should work:
router.push(`/invoices/${id}`)
```

Use `replace` for filter/sort/search changes (doesn't add to history stack).
Use `push` for navigating to a new resource.

Always include `{ scroll: false }` for filter changes — no need to scroll to top when filtering.

## Reading on the Server

Server Components can read URL params directly:

```typescript
// app/admin/invoices/page.tsx
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string }>
}) {
  const { status, page } = await searchParams  // Next.js 15: must await
  const pageNum = parseInt(page ?? '1')
  
  const invoices = await getInvoices({ status, page: pageNum })
  return <InvoiceList invoices={invoices} />
}
```

Server-side reading enables SSR of filtered results — the correct data is in the initial HTML, no client fetch needed on page load.
