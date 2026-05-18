# Skill: Search with Filters

## Overview

Search input + filter sidebar/panel that updates URL state, enabling shareable/bookmarkable searches. Combines text search with faceted filters.

## URL State Pattern

Store all filter state in the URL — not React state. This makes searches shareable, bookmarkable, and back-button friendly:

```
/products?q=wireless+headphones&category=electronics&price_max=200&sort=rating
```

```ts
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useCallback, useTransition } from 'react'

function useFilters() {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [isPending, startTransition] = useTransition()

  const setFilter = useCallback(
    (key: string, value: string | null) => {
      const params = new URLSearchParams(searchParams.toString())
      if (value === null || value === '') {
        params.delete(key)
      } else {
        params.set(key, value)
      }
      // Reset to page 1 when filter changes
      params.delete('page')

      startTransition(() => {
        router.push(`${pathname}?${params.toString()}`, { scroll: false })
      })
    },
    [router, pathname, searchParams],
  )

  const clearAll = useCallback(() => {
    startTransition(() => router.push(pathname, { scroll: false }))
  }, [router, pathname])

  return {
    q: searchParams.get('q') ?? '',
    category: searchParams.get('category') ?? '',
    priceMax: searchParams.get('price_max') ? Number(searchParams.get('price_max')) : null,
    sort: (searchParams.get('sort') ?? 'newest') as 'newest' | 'rating' | 'price_asc' | 'price_desc',
    setFilter,
    clearAll,
    isPending,
  }
}
```

`useTransition` marks the navigation as non-urgent — the UI stays responsive while the new results load.

## Search Input with Debounce

```tsx
'use client'
import { useRef } from 'react'
import { useFilters } from './useFilters'

export function SearchInput() {
  const { q, setFilter } = useFilters()
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const value = e.target.value
    if (debounceRef.current) clearTimeout(debounceRef.current)
    debounceRef.current = setTimeout(() => {
      setFilter('q', value || null)
    }, 300)
  }

  return (
    <div className="relative">
      <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
      <input
        type="search"
        defaultValue={q}
        onChange={handleChange}
        placeholder="Search..."
        className="w-full pl-9 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
      />
    </div>
  )
}
```

Use `defaultValue` (uncontrolled) not `value` (controlled) for the search input — with debouncing, you don't want React re-rendering the input on every keystroke. The `defaultValue` renders the initial value from the URL but doesn't re-render on filter changes.

## Filter Panel

```tsx
export function FilterPanel({ categories }: { categories: string[] }) {
  const { category, priceMax, sort, setFilter, clearAll } = useFilters()
  const hasFilters = category || priceMax || sort !== 'newest'

  return (
    <div className="space-y-6">
      {hasFilters && (
        <button onClick={clearAll} className="text-sm text-blue-600 hover:underline">
          Clear all filters
        </button>
      )}

      <div>
        <h3 className="text-sm font-semibold text-gray-900 mb-3">Category</h3>
        <div className="space-y-2">
          {['all', ...categories].map((cat) => (
            <label key={cat} className="flex items-center gap-2 cursor-pointer">
              <input
                type="radio"
                name="category"
                value={cat}
                checked={cat === 'all' ? !category : category === cat}
                onChange={() => setFilter('category', cat === 'all' ? null : cat)}
                className="accent-blue-600"
              />
              <span className="text-sm text-gray-700">{cat === 'all' ? 'All' : cat}</span>
            </label>
          ))}
        </div>
      </div>

      <div>
        <h3 className="text-sm font-semibold text-gray-900 mb-3">Max Price</h3>
        <div className="flex gap-2">
          {[50, 100, 200, 500].map((price) => (
            <button
              key={price}
              onClick={() => setFilter('price_max', priceMax === price ? null : String(price))}
              className={`px-3 py-1 rounded-full text-sm border transition-colors
                ${priceMax === price ? 'bg-blue-600 text-white border-blue-600' : 'border-gray-300 hover:border-gray-400'}`}
            >
              ${price}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}
```

## Server Component — Reading Filters

```tsx
// app/products/page.tsx
export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; category?: string; price_max?: string; sort?: string }>
}) {
  const params = await searchParams
  const products = await searchProducts({
    query: params.q ?? '',
    category: params.category,
    priceMax: params.price_max ? Number(params.price_max) : undefined,
    sort: (params.sort as SortOption) ?? 'newest',
  })

  return (
    <div className="flex gap-8">
      <aside className="w-64 flex-shrink-0">
        <FilterPanel categories={ALL_CATEGORIES} />
      </aside>
      <main className="flex-1">
        <SearchInput />
        <Suspense fallback={<ProductGridSkeleton />}>
          <ProductGrid products={products} />
        </Suspense>
      </main>
    </div>
  )
}
```

## Full-Text Search in Supabase

```ts
async function searchProducts({ query, category, priceMax, sort }: SearchParams) {
  let qb = supabase
    .from('products')
    .select('*')
    .eq('active', true)

  if (query) {
    // Full-text search on title + description
    qb = qb.textSearch('fts', query, { type: 'websearch' })
  }
  if (category) qb = qb.eq('category', category)
  if (priceMax) qb = qb.lte('price_cents', priceMax * 100)

  switch (sort) {
    case 'rating': qb = qb.order('avg_rating', { ascending: false }); break
    case 'price_asc': qb = qb.order('price_cents', { ascending: true }); break
    case 'price_desc': qb = qb.order('price_cents', { ascending: false }); break
    default: qb = qb.order('created_at', { ascending: false })
  }

  const { data } = await qb.limit(50)
  return data ?? []
}
```

Add a `fts tsvector` column generated from `title || ' ' || description` for `textSearch` to work.

## Active Filter Badges

```tsx
export function ActiveFilters() {
  const { q, category, priceMax, setFilter } = useFilters()
  const active = [
    q && { label: `"${q}"`, key: 'q' },
    category && { label: category, key: 'category' },
    priceMax && { label: `Under $${priceMax}`, key: 'price_max' },
  ].filter(Boolean) as Array<{ label: string; key: string }>

  if (!active.length) return null

  return (
    <div className="flex flex-wrap gap-2">
      {active.map((f) => (
        <span key={f.key} className="flex items-center gap-1 px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm">
          {f.label}
          <button onClick={() => setFilter(f.key, null)} className="hover:text-blue-600">×</button>
        </span>
      ))}
    </div>
  )
}
```
