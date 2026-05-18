# Pagination Implementation

## URL-Based Pagination (Always Preferred)

Page state belongs in the URL. Direct links to "page 3" work, back button returns to the same page, refresh preserves position.

```typescript
// app/(admin)/invoices/page.tsx
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; status?: string }>
}) {
  const { page, status } = await searchParams
  const currentPage = Math.max(1, Number(page) || 1)
  const pageSize = 20
  
  const { data: invoices, count } = await supabase
    .from('invoices')
    .select('*', { count: 'exact' })
    .eq('status', status ?? 'all')  // filter
    .order('created_at', { ascending: false })
    .range((currentPage - 1) * pageSize, currentPage * pageSize - 1)
  
  const totalPages = Math.ceil((count ?? 0) / pageSize)
  
  return (
    <div className="space-y-4">
      <InvoiceTable data={invoices ?? []} />
      <Pagination
        currentPage={currentPage}
        totalPages={totalPages}
        totalCount={count ?? 0}
        pageSize={pageSize}
      />
    </div>
  )
}
```

## Pagination Component

```typescript
// components/Pagination.tsx
'use client'
import { useRouter, usePathname, useSearchParams } from 'next/navigation'

interface PaginationProps {
  currentPage: number
  totalPages: number
  totalCount: number
  pageSize: number
}

export function Pagination({ currentPage, totalPages, totalCount, pageSize }: PaginationProps) {
  const router = useRouter()
  const pathname = usePathname()
  const searchParams = useSearchParams()
  
  function goToPage(page: number) {
    const params = new URLSearchParams(searchParams.toString())
    params.set('page', page.toString())
    router.push(`${pathname}?${params.toString()}`)
  }
  
  const start = (currentPage - 1) * pageSize + 1
  const end = Math.min(currentPage * pageSize, totalCount)
  
  return (
    <div className="flex items-center justify-between">
      <p className="text-sm text-muted-foreground">
        Showing {start}–{end} of {totalCount}
      </p>
      
      <div className="flex items-center gap-1">
        <Button
          variant="outline"
          size="sm"
          disabled={currentPage <= 1}
          onClick={() => goToPage(currentPage - 1)}
        >
          <ChevronLeft className="h-4 w-4" />
          Previous
        </Button>
        
        {/* Page numbers: show first, last, and 2 on each side of current */}
        {getPageRange(currentPage, totalPages).map((page, i) => (
          page === '...' ? (
            <span key={`ellipsis-${i}`} className="px-2 text-muted-foreground">...</span>
          ) : (
            <Button
              key={page}
              variant={page === currentPage ? 'default' : 'outline'}
              size="sm"
              className="w-8"
              onClick={() => goToPage(Number(page))}
            >
              {page}
            </Button>
          )
        ))}
        
        <Button
          variant="outline"
          size="sm"
          disabled={currentPage >= totalPages}
          onClick={() => goToPage(currentPage + 1)}
        >
          Next
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>
    </div>
  )
}

function getPageRange(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1)
  
  const pages: (number | '...')[] = [1]
  
  if (current > 3) pages.push('...')
  
  const start = Math.max(2, current - 1)
  const end = Math.min(total - 1, current + 1)
  
  for (let i = start; i <= end; i++) pages.push(i)
  
  if (current < total - 2) pages.push('...')
  pages.push(total)
  
  return pages
}
```

## Cursor-Based Pagination (for Real-Time Data)

Offset-based pagination (`LIMIT 20 OFFSET 40`) has a problem: if records are inserted while the user is paginating, page 2 might repeat records from page 1 or skip records.

Cursor pagination uses a stable reference point:

```typescript
// Use the last record's `created_at` as the cursor:
async function fetchInvoicesAfterCursor(cursor?: string, pageSize = 20) {
  let query = supabase
    .from('invoices')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(pageSize + 1)  // fetch one extra to determine hasMore
  
  if (cursor) {
    query = query.lt('created_at', cursor)  // records before the cursor
  }
  
  const { data } = await query
  
  const hasMore = (data?.length ?? 0) > pageSize
  return {
    data: data?.slice(0, pageSize) ?? [],
    nextCursor: hasMore ? data?.[pageSize - 1]?.created_at : undefined,
  }
}
```

Cursor pagination is better for: activity feeds, real-time lists, infinite scroll.
Offset pagination is better for: admin tables, search results, any content that needs "jump to page 5".

## Empty State

```typescript
{invoices.length === 0 && (
  <div className="text-center py-12 text-muted-foreground">
    {hasFilters ? 'No invoices match your filters.' : 'No invoices yet.'}
  </div>
)}
```

Always distinguish between "empty because filters" and "empty because no data" — they call for different UX responses.
