# Pattern: Advanced URL State (nuqs)

## What This Solves

Simple URL state (one search param) is easy. The challenge comes when multiple interacting params exist simultaneously — filters, pagination, sorting, and tab state all living in the URL together. Naive `router.push` on every change causes full page re-renders, breaks the back button, and creates flash of incorrect state. `nuqs` solves this with typed URL params, shallow updates, and server-side parsing.

## Why URL State Beats useState for Shareable State

URL state is shareable, bookmarkable, and survives page refreshes. The tradeoff is serialization overhead. Use URL state for anything a user might want to share or return to: search queries, filter selections, pagination, active tabs, and selected items. Use `useState` for ephemeral UI state: hover, open/closed, drag progress.

## nuqs Setup

```bash
npm i nuqs
```

In Next.js App Router, wrap the root layout in `NuqsAdapter`:

```tsx
// app/layout.tsx
import { NuqsAdapter } from 'nuqs/adapters/next/app'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <NuqsAdapter>{children}</NuqsAdapter>
      </body>
    </html>
  )
}
```

## Multiple Interacting Params

Use `useQueryStates` to manage related params atomically. This prevents partial updates where one param changes before another:

```tsx
import { useQueryStates, parseAsString, parseAsInteger, parseAsArrayOf } from 'nuqs'

const invoiceFilters = {
  search: parseAsString.withDefault(''),
  status: parseAsString.withDefault('all'),
  page: parseAsInteger.withDefault(1),
  sort: parseAsString.withDefault('created_at'),
  dir: parseAsString.withDefault('desc'),
  tags: parseAsArrayOf(parseAsString).withDefault([]),
}

function InvoiceFilters() {
  const [filters, setFilters] = useQueryStates(invoiceFilters)

  function handleStatusChange(status: string) {
    // Atomic update: status changes AND page resets to 1
    setFilters({ status, page: 1 })
  }

  function handleSearchChange(search: string) {
    setFilters({ search, page: 1 })
  }

  return (/* filter UI */)
}
```

The atomic update prevents the issue where changing a filter shows page 3 of results before the page param resets.

## Shallow Push vs Hard Navigation

`nuqs` uses shallow updates by default — it updates the URL without triggering a server round-trip or re-running Server Component fetches. This is correct for client-side filter UI. When you need the server to re-fetch data on param change, pass `shallow: false`:

```tsx
const [filters, setFilters] = useQueryStates(invoiceFilters, {
  shallow: false,  // triggers server re-render; Server Components re-fetch data
})
```

Use `shallow: true` (default) for: live search, tab selection, UI-only state.
Use `shallow: false` for: pagination where data comes from a Server Component, filter changes that must re-run RSC data fetching.

## Default Values That Don't Appear in URL

`.withDefault()` sets the default value AND controls whether it appears in the URL. When the value equals the default, nuqs omits the param from the URL — keeping URLs clean:

```ts
// URL is /invoices, not /invoices?page=1&dir=desc&status=all
const schema = {
  page: parseAsInteger.withDefault(1),    // page=1 never shows in URL
  status: parseAsString.withDefault('all'), // status=all never shows in URL
}
```

This makes URLs shareable without noise. Only non-default values appear.

## Server-Side Param Parsing

Parse params in Server Components or route handlers using `createSearchParamsCache`:

```tsx
// app/invoices/searchParams.ts
import { createSearchParamsCache, parseAsString, parseAsInteger } from 'nuqs/server'

export const searchParamsCache = createSearchParamsCache({
  search: parseAsString.withDefault(''),
  status: parseAsString.withDefault('all'),
  page: parseAsInteger.withDefault(1),
})

// app/invoices/page.tsx (Server Component)
import { searchParamsCache } from './searchParams'

export default async function InvoicesPage({ searchParams }) {
  const { search, status, page } = await searchParamsCache.parse(searchParams)

  const invoices = await db.invoices.findMany({
    where: {
      ...(search && { number: { contains: search } }),
      ...(status !== 'all' && { status }),
    },
    skip: (page - 1) * 20,
    take: 20,
  })

  return <InvoiceTable invoices={invoices} />
}
```

This ensures the server uses the same defaults and types as the client — no divergence.

## History Mode: push vs replace

By default nuqs uses `replace` so filter changes don't flood the history stack (you don't want 20 back-button presses to undo a search). Use `push` only for navigational changes where back-button semantics matter:

```tsx
setFilters({ status: 'paid' }, { history: 'replace' })  // default — no history entry
setFilters({ tab: 'details' }, { history: 'push' })     // tab nav gets a history entry
```

## Key Rules

- Use `useQueryStates` (not multiple `useQueryState` calls) for related params — guarantees atomic updates
- Reset pagination to page 1 whenever a filter changes
- Omit params from URL when they equal the default via `.withDefault()`
- Use `shallow: false` only when Server Components need to re-fetch on param change
- Share the same schema between client `useQueryStates` and server `searchParamsCache` — define it once and import both places
- Use `history: 'replace'` for filter changes; `history: 'push'` for navigational tab/section changes
