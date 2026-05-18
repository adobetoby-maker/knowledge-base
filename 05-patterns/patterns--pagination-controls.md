# Pattern: Pagination Controls

## Why This Pattern Matters

Pagination is navigational infrastructure. URL sync is non-negotiable — users must be able to bookmark page 7, share a link, and hit the back button. Disabled states at boundaries prevent errors. Truncation with ellipsis keeps the control usable at any page count without overflowing the layout.

## URL Sync

Page number lives in the URL query string: `?page=3`. Never in React state alone. Use `useSearchParams` (Next.js App Router) or a URL state hook.

```tsx
// Next.js App Router
const searchParams = useSearchParams();
const page = Number(searchParams.get('page') ?? '1');

function goToPage(n: number) {
  const params = new URLSearchParams(searchParams.toString());
  params.set('page', String(n));
  router.push(`?${params.toString()}`, { scroll: false }); // don't jump to top
}
```

`scroll: false` prevents the page from scrolling to the top on every page change — a common UX regression.

## Calculating Visible Page Numbers

For ranges > 7 pages, show: first, ellipsis, 2 pages around current, ellipsis, last. The current page always has 1 neighbor on each side.

```ts
function getPageNumbers(current: number, total: number): (number | '...')[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);

  const pages: (number | '...')[] = [1];
  if (current > 3) pages.push('...');
  for (let i = Math.max(2, current - 1); i <= Math.min(total - 1, current + 1); i++) {
    pages.push(i);
  }
  if (current < total - 2) pages.push('...');
  pages.push(total);
  return pages;
}
```

Never use `...` as a button — it is non-interactive. Render it as a `<span aria-hidden="true">`.

## First, Previous, Next, Last Buttons

All four are standard for data-heavy apps. For simpler contexts, Previous/Next alone is sufficient. Label them with both an icon and screen-reader text:

```tsx
<button
  disabled={page <= 1}
  aria-label="First page"
  onClick={() => goToPage(1)}
>
  <ChevronsLeft className="h-4 w-4" aria-hidden="true" />
</button>
```

Disabled state: `disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none`. Never just visually style disabled — use the HTML `disabled` attribute so keyboard navigation skips these buttons.

## Disabled State at Boundaries

- Previous and First: disabled when `page === 1`
- Next and Last: disabled when `page === totalPages`
- All page number buttons except the current page are active; the current page button is `aria-current="page"` and visually highlighted (filled background), not disabled

## Page Size Selector

If variable page size is supported, add a "Rows per page" select. This also syncs to URL: `?page=1&per_page=25`. Changing page size always resets to page 1.

```tsx
<select
  value={perPage}
  onChange={e => {
    const params = new URLSearchParams(searchParams.toString());
    params.set('per_page', e.target.value);
    params.set('page', '1'); // reset
    router.push(`?${params.toString()}`);
  }}
>
  {[10, 25, 50, 100].map(n => <option key={n} value={n}>{n} per page</option>)}
</select>
```

## Result Count Summary

Always render a summary line: "Showing 26–50 of 247 results". This grounds the user in the dataset. Display it above the pagination controls (near the top of the list) and optionally repeat below.

## Key Rules

- Page number is always in the URL query string — never React state only
- `scroll: false` on navigation to prevent layout jump
- Ellipsis (`...`) is a non-interactive `<span>`, never a button
- First/Last and Prev/Next use HTML `disabled` attribute at boundaries, not just visual styling
- Current page is `aria-current="page"`, not disabled
- Page size change always resets to page 1
- Show result count summary: "Showing X–Y of Z results"
