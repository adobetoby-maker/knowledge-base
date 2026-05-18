# Search Pattern

## Three Search Approaches

**1. Client-side filter** — filter an in-memory array. Fast, no server round-trip. Only works when all data is loaded.

**2. URL-driven search** — search term in URL query param, fetched server-side. Works with SSR, shareable URLs, works without JS.

**3. Debounced client search** — type-as-you-go with debounce, server fetches. Best UX for large datasets.

## URL-Driven Search (Recommended for Admin Tables)

```typescript
// app/admin/invoices/page.tsx
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string }>
}) {
  const { q = '', page = '1' } = await searchParams
  const currentPage = parseInt(page)
  const pageSize = 20
  const from = (currentPage - 1) * pageSize

  const supabase = createAdminClient()
  let query = supabase
    .from('invoices')
    .select('*, customers!inner(name)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + pageSize - 1)

  if (q) {
    query = query.ilike('customers.name', `%${q}%`)
  }

  const { data: invoices, count } = await query

  return (
    <div>
      <SearchForm defaultValue={q} />
      <InvoiceTable invoices={invoices ?? []} />
      <Pagination currentPage={currentPage} totalPages={Math.ceil((count ?? 0) / pageSize)} />
    </div>
  )
}
```

```typescript
// components/search-form.tsx
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { Input } from '@/components/ui/input'

export function SearchForm({ defaultValue }: { defaultValue: string }) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()

  function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const term = new FormData(e.currentTarget).get('q') as string
    const params = new URLSearchParams(searchParams)
    params.set('q', term)
    params.set('page', '1')  // reset page on new search
    router.push(`${pathname}?${params.toString()}`)
  }

  return (
    <form onSubmit={handleSubmit}>
      <Input name="q" defaultValue={defaultValue} placeholder="Search customers..." />
    </form>
  )
}
```

## Debounced Search (Type-as-You-Go)

```typescript
// hooks/use-debounce.ts
import { useEffect, useState } from 'react'

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value)
  
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])
  
  return debouncedValue
}
```

```typescript
// components/search-box.tsx
'use client'
import { useState } from 'react'
import { useDebounce } from '@/hooks/use-debounce'
import { useQuery } from '@tanstack/react-query'

export function SearchBox() {
  const [query, setQuery] = useState('')
  const debouncedQuery = useDebounce(query, 300)

  const { data: results, isLoading } = useQuery({
    queryKey: ['search', debouncedQuery],
    queryFn: () => fetch(`/api/search?q=${encodeURIComponent(debouncedQuery)}`).then(r => r.json()),
    enabled: debouncedQuery.length >= 2,  // don't search for 1 char
  })

  return (
    <div className="relative">
      <input
        value={query}
        onChange={e => setQuery(e.target.value)}
        placeholder="Search..."
        className="w-full px-4 py-2 border rounded-lg"
      />
      {isLoading && <Spinner className="absolute right-3 top-3" />}
      {results && results.length > 0 && (
        <ul className="absolute top-full mt-1 w-full bg-white border rounded-lg shadow-lg z-50">
          {results.map(result => (
            <li key={result.id} className="px-4 py-2 hover:bg-gray-50 cursor-pointer">
              {result.name}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
```

## Supabase Full-Text Search

For more sophisticated search, use Supabase's built-in full-text search:

```sql
-- Create a tsvector column for full-text search
ALTER TABLE invoices ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (to_tsvector('english', coalesce(description, '') || ' ' || coalesce(customer_name, ''))) STORED;

CREATE INDEX invoices_search_idx ON invoices USING gin(search_vector);
```

```typescript
// Use in query
const { data } = await supabase
  .from('invoices')
  .select('*')
  .textSearch('search_vector', query, { type: 'websearch' })
```

## Search API Route

```typescript
// app/api/search/route.ts
export async function GET(req: NextRequest) {
  const query = req.nextUrl.searchParams.get('q') ?? ''
  
  if (query.length < 2) return NextResponse.json([])
  
  const supabase = createAdminClient()
  const { data } = await supabase
    .from('customers')
    .select('id, name, email')
    .or(`name.ilike.%${query}%,email.ilike.%${query}%`)
    .limit(10)

  return NextResponse.json(data ?? [])
}
```

## Highlighting Search Terms

```typescript
function highlightMatch(text: string, query: string): React.ReactNode {
  if (!query) return text
  const regex = new RegExp(`(${query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi')
  const parts = text.split(regex)
  return parts.map((part, i) =>
    regex.test(part) ? <mark key={i} className="bg-yellow-200">{part}</mark> : part
  )
}
```

## Common Mistakes

- **No minimum query length** — single characters produce huge, noisy result sets; use `enabled: query.length >= 2`
- **Missing debounce** — every keystroke triggers a fetch without debounce
- **Not resetting page on search** — always set page back to 1 when a new search is performed
- **SQL injection in ILIKE** — use parameterized queries; Supabase client handles this, but raw `execute_sql` must use bound parameters
- **Searching without indexes** — ILIKE queries on unindexed columns are table scans; add trigram index for large tables
