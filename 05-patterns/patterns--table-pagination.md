# Pattern: Paginated Data Table with Page Size Selector

## Problem

Pagination state can live in component state (controlled, local), in a URL query string (shareable, bookmarkable), or in both simultaneously. Tables also need accurate total count display, disabled next/prev at bounds, and a page-size selector that resets to page 1 to avoid showing an empty page.

## URL-Synced State

URL sync is almost always the right choice for data tables — it preserves state on refresh, supports bookmarking, and works with browser back/forward:

```ts
// Parse from URL: ?page=2&per_page=25
function usePaginationState() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  const page = Math.max(1, Number(searchParams.get('page') ?? 1));
  const perPage = [10, 25, 50, 100].includes(Number(searchParams.get('per_page')))
    ? Number(searchParams.get('per_page'))
    : 25;

  function setPage(p: number) {
    const params = new URLSearchParams(searchParams.toString());
    params.set('page', String(p));
    router.push(`${pathname}?${params}`);
  }

  function setPerPage(n: number) {
    const params = new URLSearchParams(searchParams.toString());
    params.set('per_page', String(n));
    params.set('page', '1');    // ← always reset to 1 when changing page size
    router.push(`${pathname}?${params}`);
  }

  return { page, perPage, setPage, setPerPage };
}
```

WHY validate `perPage` against an allowlist: arbitrary query string values like `per_page=99999` should not reach the server. Clamp or reject them.

## Fetching with Offset

```ts
async function fetchRows(page: number, perPage: number) {
  const offset = (page - 1) * perPage;
  const { data, count } = await supabase
    .from('orders')
    .select('*', { count: 'exact' })  // Supabase: count total rows in one query
    .range(offset, offset + perPage - 1)
    .order('created_at', { ascending: false });

  return { rows: data ?? [], total: count ?? 0 };
}
```

## Pagination Controls Component

```tsx
function PaginationControls({ page, perPage, total, setPage, setPerPage }: Props) {
  const totalPages = Math.ceil(total / perPage);
  const start = (page - 1) * perPage + 1;
  const end = Math.min(page * perPage, total);

  return (
    <div className="flex items-center justify-between">
      {/* Total count display */}
      <p className="text-sm text-gray-600">
        {total === 0 ? 'No results' : `Showing ${start}–${end} of ${total}`}
      </p>

      <div className="flex items-center gap-4">
        {/* Page size selector */}
        <label className="flex items-center gap-2 text-sm">
          Rows per page
          <select
            value={perPage}
            onChange={e => setPerPage(Number(e.target.value))}
            className="rounded border px-2 py-1 text-sm"
          >
            {[10, 25, 50, 100].map(n => (
              <option key={n} value={n}>{n}</option>
            ))}
          </select>
        </label>

        {/* Page navigation */}
        <div className="flex items-center gap-1">
          <button
            onClick={() => setPage(1)}
            disabled={page === 1}
            aria-label="First page"
          >«</button>
          <button
            onClick={() => setPage(page - 1)}
            disabled={page === 1}
            aria-label="Previous page"
          >‹</button>

          <span className="px-3 text-sm">{page} / {totalPages}</span>

          <button
            onClick={() => setPage(page + 1)}
            disabled={page >= totalPages}
            aria-label="Next page"
          >›</button>
          <button
            onClick={() => setPage(totalPages)}
            disabled={page >= totalPages}
            aria-label="Last page"
          >»</button>
        </div>
      </div>
    </div>
  );
}
```

## Controlled vs Uncontrolled

- **URL-synced (recommended)**: use `useSearchParams` + `router.push`. Sharable, bookmarkable, survives refresh.
- **Component state (use when)**: the table is inside a modal or drawer where URL changes would be jarring.

Never mix both — pick one source of truth.

## Key Rules

- Always reset `page` to 1 when `perPage` changes, or the user may land on an empty page
- Validate `perPage` against an explicit allowlist — reject arbitrary values
- Disable prev/first at page 1, disable next/last at the final page (use `disabled` attribute, not hidden)
- Display "Showing X–Y of Z" so users understand their position in the dataset
- URL sync is preferred for any full-page table; local state is acceptable inside modals
