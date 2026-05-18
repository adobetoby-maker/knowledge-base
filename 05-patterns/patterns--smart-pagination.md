# Pattern: Smart Pagination

## Overview
Pagination without context (total count, current range) leaves users disoriented — they don't know how much data exists or how far they've scrolled. Persisting page state in the URL enables sharing, bookmarking, and back-button navigation. Jumping back to page 1 on sort changes is the only defensible behavior because the sort order changes which items appear on which page.

## Implementation

### URL State Persistence
```typescript
// /invoices?page=3&sort=date&dir=desc&status=paid

function usePaginationState() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const page = Number(searchParams.get('page') ?? '1');
  const sort = searchParams.get('sort') ?? 'createdAt';
  const dir = (searchParams.get('dir') ?? 'desc') as 'asc' | 'desc';

  function setPage(newPage: number) {
    const params = new URLSearchParams(searchParams);
    params.set('page', String(newPage));
    router.push(`${pathname}?${params}`);
  }

  function setSort(newSort: string, newDir: 'asc' | 'desc' = 'desc') {
    const params = new URLSearchParams(searchParams);
    params.set('sort', newSort);
    params.set('dir', newDir);
    params.set('page', '1'); // always reset page on sort change
    router.push(`${pathname}?${params}`);
  }

  return { page, sort, dir, setPage, setSort };
}
```

### Pagination Controls Component
```tsx
interface PaginationProps {
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (page: number) => void;
}

function Pagination({ page, pageSize, total, onPageChange }: PaginationProps) {
  const totalPages = Math.ceil(total / pageSize);
  const from = (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, total);

  const [jumpInput, setJumpInput] = useState('');

  if (totalPages <= 1) return null; // don't render for single-page results

  return (
    <div className="pagination">
      {/* Range indicator */}
      <span className="range-indicator">
        {from}–{to} of {total.toLocaleString()}
      </span>

      <div className="controls">
        {/* First page — show for large sets only */}
        {totalPages > 10 && (
          <button onClick={() => onPageChange(1)} disabled={page === 1} aria-label="First page">
            «
          </button>
        )}

        {/* Previous */}
        <button onClick={() => onPageChange(page - 1)} disabled={page === 1} aria-label="Previous page">
          ‹
        </button>

        {/* Page numbers — show window of 5 */}
        <PageNumbers page={page} totalPages={totalPages} onPageChange={onPageChange} />

        {/* Next */}
        <button onClick={() => onPageChange(page + 1)} disabled={page === totalPages} aria-label="Next page">
          ›
        </button>

        {/* Last page — show for large sets */}
        {totalPages > 10 && (
          <button onClick={() => onPageChange(totalPages)} disabled={page === totalPages} aria-label="Last page">
            »
          </button>
        )}
      </div>

      {/* Jump to page — show for large sets */}
      {totalPages > 10 && (
        <form
          onSubmit={e => {
            e.preventDefault();
            const n = Number(jumpInput);
            if (n >= 1 && n <= totalPages) onPageChange(n);
          }}
          className="jump-to-page"
        >
          <label>Go to page</label>
          <input
            type="number"
            min={1}
            max={totalPages}
            value={jumpInput}
            onChange={e => setJumpInput(e.target.value)}
            style={{ width: '4rem' }}
          />
        </form>
      )}
    </div>
  );
}

function PageNumbers({ page, totalPages, onPageChange }) {
  // Show window: [1] ... [3][4][5][6][7] ... [20]
  const window = 2; // pages on each side of current
  const pages: (number | '...')[] = [];

  if (page - window > 2) pages.push(1, '...');
  else for (let i = 1; i < page - window; i++) pages.push(i);

  for (let i = Math.max(1, page - window); i <= Math.min(totalPages, page + window); i++) {
    pages.push(i);
  }

  if (page + window < totalPages - 1) pages.push('...', totalPages);
  else for (let i = page + window + 1; i <= totalPages; i++) pages.push(i);

  return (
    <>
      {pages.map((p, i) =>
        p === '...' ? (
          <span key={`ellipsis-${i}`} className="ellipsis">…</span>
        ) : (
          <button
            key={p}
            onClick={() => onPageChange(p)}
            aria-current={p === page ? 'page' : undefined}
            className={p === page ? 'active' : ''}
          >
            {p}
          </button>
        )
      )}
    </>
  );
}
```

## Key Rules
- Always show "X–Y of Z" — users need to know where they are and how much data exists
- Persist `page`, `sort`, and `dir` in URL search params — enables bookmarking and sharing
- Reset to page 1 when sort changes — page 3 sorted by date has no relationship to page 3 sorted by name
- Try to maintain page when changing filters — if filtered results have fewer pages, go to last available page
- First and Last buttons only for large sets (>10 pages) — they're noise for 2-page results
- Jump-to-page input only for large sets — overkill for small result sets
- Don't render the pagination component at all for single-page results
- `aria-current="page"` on the active page button for screen reader accessibility
- Number format for total: `total.toLocaleString()` — "1,248" not "1248"
- Debounce rapid page changes from keyboard — don't fire an API call for every keystroke in jump input
