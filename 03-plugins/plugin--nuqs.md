# Plugin: nuqs (URL Search Params State)

## Overview
nuqs treats URL search parameters as first-class React state. The URL is the source of truth for filters, pagination, search queries, and other shareable UI state — not local React state that vanishes on refresh or is lost when sharing a link. nuqs handles the serialization/deserialization, Next.js router integration (App Router and Pages Router), and SSR synchronization so you don't have to.

## Implementation

### Single Param
```tsx
import { useQueryState, parseAsInteger, parseAsString, parseAsBoolean } from 'nuqs';

// ?page=2 — defaults to 1 if not in URL
const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1));

// ?q=hello — null if not present
const [search, setSearch] = useQueryState('q');

// ?active=true
const [active, setActive] = useQueryState('active', parseAsBoolean.withDefault(false));

// Usage: same API as useState
setPage(3);       // updates URL: ?page=3
setPage(null);    // removes param from URL
```

### Multiple Params (Atomic Update)
```tsx
import { useQueryStates, parseAsInteger, parseAsString } from 'nuqs';

// All params update atomically in a single router push
const [filters, setFilters] = useQueryStates({
  page: parseAsInteger.withDefault(1),
  limit: parseAsInteger.withDefault(20),
  sort: parseAsString.withDefault('createdAt'),
  dir: parseAsString.withDefault('desc'),
  q: parseAsString,
});

// Partial update — only specified keys change, others preserved
setFilters({ page: 2 });
setFilters({ q: 'search term', page: 1 }); // reset page when searching
```

### Server Component Re-render vs Shallow
```tsx
// shallow: true (default) — updates URL without triggering Server Component re-render
// Only client-side React state changes
const [tab, setTab] = useQueryState('tab', { shallow: true });

// shallow: false — triggers full Next.js navigation, Server Components re-render
// Use when the server needs to read the param to fetch different data
const [category, setCategory] = useQueryState('category', {
  ...parseAsString,
  shallow: false,
});
```

### Throttling for Input Fields
```tsx
// throttleMs prevents URL updates on every keystroke
const [search, setSearch] = useQueryState('q', {
  ...parseAsString,
  throttleMs: 300, // debounce URL updates
});

// Input still feels instant — local state updates immediately,
// URL updates at throttled rate
<input
  value={search ?? ''}
  onChange={e => setSearch(e.target.value || null)}
/>
```

### Programmatic URL Building
```tsx
import { createSerializer, parseAsInteger, parseAsString } from 'nuqs';

const serialize = createSerializer({
  page: parseAsInteger,
  q: parseAsString,
  category: parseAsString,
});

// Generate URL string without React
const url = serialize('/search', { page: 2, q: 'bikes', category: null });
// → /search?page=2&q=bikes

// Useful for: Link hrefs, redirects, prefetching
<Link href={serialize('/products', { page: nextPage, q: currentSearch })}>
  Next page
</Link>
```

### Reading Params in Server Components (Next.js)
```tsx
// Server Component — read directly from searchParams
export default function Page({ searchParams }: { searchParams: Record<string, string> }) {
  const page = parseInt(searchParams.page ?? '1');
  const q = searchParams.q ?? '';

  // Fetch based on URL params
  const results = await searchProducts({ page, q });
  return <ProductList results={results} />;
}
```

### Null vs Default
```tsx
// withDefault — returns default when param absent, never null
const [page, setPage] = useQueryState('page', parseAsInteger.withDefault(1));
// page: number (never null)

// Without withDefault — null when absent
const [q, setQ] = useQueryState('q');
// q: string | null

// Remove param by setting null
setQ(null);    // removes ?q= from URL
setPage(null); // resets to default (1) AND removes ?page= from URL
```

## Key Rules
- Use `shallow: false` when Server Components need to re-fetch based on the URL param; `shallow: true` (default) for pure client UI state
- `parseAsInteger`, `parseAsString`, `parseAsBoolean`, `parseAsIsoDateTime`, `parseAsJson()` — use built-in parsers before writing custom
- `throttleMs` is essential for text inputs to avoid flooding the browser history with every keystroke
- `setParam(null)` removes the param from the URL entirely; `withDefault` ensures you still get a typed value
- `useQueryStates` batches multiple param changes into a single router update — always use it for related params (filters, pagination)
- `createSerializer` builds URLs without React context — useful in Server Components, Link hrefs, and API route redirects
- Wrap the app with `NuqsAdapter` (from `nuqs/adapters/next/app`) at the layout level for App Router
