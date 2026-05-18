# Disambig: Pagination Approach

## Three Approaches

**Offset pagination** — `LIMIT N OFFSET M`. Simple, works with URL params.
- Use for: admin tables, search results, any list where jumping to a page makes sense
- Problem: skips/duplicates when data changes while paginating (acceptable for most admin use cases)

**Cursor pagination** — fetch next N items after a cursor (usually an ID or timestamp).
- Use for: real-time feeds, activity logs, anything that updates frequently
- Problem: no "go to page 5" — only forward/backward

**Load more / infinite scroll** — append items to list, never replace.
- Use for: social feeds, image galleries, content discovery
- Problem: hard to navigate back to a specific position

## Offset Pagination (Most Common)

```typescript
// URL: /invoices?page=2&per_page=20

// Fetch:
const page = parseInt(searchParams.get('page') ?? '1')
const perPage = parseInt(searchParams.get('per_page') ?? '20')
const offset = (page - 1) * perPage

const { data, count } = await supabase
  .from('invoices')
  .select('*', { count: 'exact' })  // count returns total rows
  .range(offset, offset + perPage - 1)
  .order('created_at', { ascending: false })

const totalPages = Math.ceil((count ?? 0) / perPage)
```

## When to Use Cursor vs Offset

| Situation | Approach |
|---|---|
| Admin invoice list — user pages through | Offset |
| Activity/audit log feed — real-time | Cursor |
| Customer search results | Offset |
| Chat messages, loading history | Cursor (load older) |
| Image gallery (Instagram-style) | Infinite scroll |
| Report with 10k+ rows exported | No pagination — generate CSV |

## Cursor Pagination

```typescript
// Fetch next page after cursor (ID or timestamp):
const { data } = await supabase
  .from('audit_logs')
  .select('*')
  .lt('created_at', cursor)   // less than cursor timestamp
  .order('created_at', { ascending: false })
  .limit(20)

// Next cursor = last item's timestamp:
const nextCursor = data?.at(-1)?.created_at ?? null
```

## Load More (Infinite Scroll)

Use TanStack Query's `useInfiniteQuery`:

```typescript
const {
  data,
  fetchNextPage,
  hasNextPage,
  isFetchingNextPage,
} = useInfiniteQuery({
  queryKey: ['invoices', filters],
  queryFn: ({ pageParam = 0 }) => fetchInvoices({ offset: pageParam, limit: 20 }),
  getNextPageParam: (lastPage, allPages) => {
    const fetched = allPages.reduce((sum, page) => sum + page.items.length, 0)
    return lastPage.items.length === 20 ? fetched : undefined  // undefined = no more pages
  },
})

const allInvoices = data?.pages.flatMap(page => page.items) ?? []
```

## Where to Put Pagination State

**URL params (recommended for most admin pages):**
```typescript
const [searchParams, setSearchParams] = useSearchParams()
const page = parseInt(searchParams.get('page') ?? '1')

function goToPage(p: number) {
  setSearchParams(prev => { prev.set('page', String(p)); return prev })
}
```

Benefit: shareable URLs, browser back/forward works, page survives refresh.

**useState (for ephemeral or embedded lists):**
```typescript
const [page, setPage] = useState(1)
```

Use only when the list is a small embedded component, not a main page.
