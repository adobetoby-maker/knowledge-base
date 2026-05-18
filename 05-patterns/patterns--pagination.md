# Pagination Pattern

## Two Pagination Types

**Offset pagination** — page 1, 2, 3... with previous/next buttons. Simple, supports random access. Consistent with large datasets, but can miss/duplicate rows if data changes during navigation.

**Cursor pagination** — "load more" or infinite scroll using a cursor pointing to the last seen record. No random access, but consistent results when data changes.

Use offset pagination for admin tables with page numbers. Use cursor pagination for feed-style UIs or infinite scroll.

## Offset Pagination with Supabase

```typescript
// Server Component — URL-driven pagination
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>
}) {
  const { page = '1' } = await searchParams
  const currentPage = Math.max(1, parseInt(page))
  const pageSize = 20
  const from = (currentPage - 1) * pageSize
  const to = from + pageSize - 1

  const supabase = createAdminClient()
  const { data: invoices, count, error } = await supabase
    .from('invoices')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, to)

  const totalPages = Math.ceil((count ?? 0) / pageSize)

  return (
    <div>
      <InvoiceList invoices={invoices ?? []} />
      <Pagination currentPage={currentPage} totalPages={totalPages} />
    </div>
  )
}
```

## Pagination Component

```typescript
// components/ui/pagination.tsx
import Link from 'next/link'

interface PaginationProps {
  currentPage: number
  totalPages: number
  basePath?: string
}

export function Pagination({ currentPage, totalPages, basePath = '' }: PaginationProps) {
  if (totalPages <= 1) return null

  const pages = getPaginationRange(currentPage, totalPages)

  return (
    <nav className="flex items-center gap-1">
      <PaginationLink href={`${basePath}?page=${currentPage - 1}`} disabled={currentPage <= 1}>
        ← Previous
      </PaginationLink>

      {pages.map((page, i) =>
        page === '...' ? (
          <span key={i} className="px-3 py-2 text-muted-foreground">...</span>
        ) : (
          <PaginationLink
            key={page}
            href={`${basePath}?page=${page}`}
            isActive={page === currentPage}
          >
            {page}
          </PaginationLink>
        )
      )}

      <PaginationLink href={`${basePath}?page=${currentPage + 1}`} disabled={currentPage >= totalPages}>
        Next →
      </PaginationLink>
    </nav>
  )
}

function PaginationLink({
  href,
  disabled,
  isActive,
  children,
}: {
  href: string
  disabled?: boolean
  isActive?: boolean
  children: React.ReactNode
}) {
  if (disabled) {
    return <span className="px-3 py-2 text-muted-foreground cursor-not-allowed">{children}</span>
  }
  return (
    <Link
      href={href}
      className={`px-3 py-2 rounded text-sm transition-colors ${
        isActive
          ? 'bg-primary text-primary-foreground'
          : 'hover:bg-muted'
      }`}
    >
      {children}
    </Link>
  )
}

// Show at most 7 page numbers with ellipsis
function getPaginationRange(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  
  if (current <= 4) return [1, 2, 3, 4, 5, '...', total]
  if (current >= total - 3) return [1, '...', total - 4, total - 3, total - 2, total - 1, total]
  return [1, '...', current - 1, current, current + 1, '...', total]
}
```

## Preserving Other Query Params

When paginating alongside search/filter, preserve other params:

```typescript
// Use URLSearchParams to preserve existing params
function buildPageUrl(searchParams: URLSearchParams, page: number): string {
  const params = new URLSearchParams(searchParams)
  params.set('page', page.toString())
  return `?${params.toString()}`
}

// In the component
const params = new URLSearchParams({ q: searchQuery, status: statusFilter })
```

## Cursor Pagination

For feeds and infinite scroll:

```typescript
// API: return cursor with results
export async function GET(req: NextRequest) {
  const cursor = req.nextUrl.searchParams.get('cursor')
  
  const supabase = createAdminClient()
  let query = supabase
    .from('posts')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(20)

  if (cursor) {
    query = query.lt('created_at', cursor)
  }

  const { data: posts } = await query
  const nextCursor = posts?.length === 20 ? posts[posts.length - 1].created_at : null

  return NextResponse.json({ posts, nextCursor })
}
```

```typescript
// Client: infinite scroll with TanStack Query
import { useInfiniteQuery } from '@tanstack/react-query'
import { useIntersectionObserver } from '@/hooks/use-intersection-observer'

function PostFeed() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['posts'],
    queryFn: ({ pageParam }) =>
      fetch(`/api/posts${pageParam ? `?cursor=${pageParam}` : ''}`).then(r => r.json()),
    getNextPageParam: lastPage => lastPage.nextCursor,
    initialPageParam: undefined,
  })

  const { ref } = useIntersectionObserver({
    onIntersect: () => { if (hasNextPage && !isFetchingNextPage) fetchNextPage() },
  })

  const posts = data?.pages.flatMap(p => p.posts) ?? []

  return (
    <div>
      {posts.map(post => <PostCard key={post.id} post={post} />)}
      <div ref={ref} className="h-4" />
      {isFetchingNextPage && <Spinner />}
    </div>
  )
}
```

## Common Mistakes

- **No total count in SQL** — include `{ count: 'exact' }` in Supabase select or pagination math breaks
- **Page 0** — always start at page 1; guard with `Math.max(1, parseInt(page))`
- **Off-by-one in range** — Supabase `range(from, to)` is inclusive on both ends; page 1, size 20 → `range(0, 19)`
- **Resetting page on filter change** — when search/filter changes, reset to page 1 or results will be empty
