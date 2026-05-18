# Pattern: Persistent Search + Filter UI

A combined search input and filter panel where all active state lives in the URL. Users can share a filtered view via link, use the browser back button to undo a filter, and refresh without losing context. Different from `patterns--filter-panel.md` which covers the panel UI component—this covers URL state synchronization as the source of truth.

## Why It Matters

Keeping filter state in React state alone means it's ephemeral: a refresh wipes it, a link shares nothing, the back button closes the whole page instead of clearing the last filter. URL-based state costs almost nothing to implement with the right hook and pays dividends in UX quality.

## URL State Sync

Use `nuqs` (Next.js) or a thin wrapper around `URLSearchParams` for URL state. Don't roll your own serialization.

```ts
// With nuqs in Next.js App Router
import { useQueryStates, parseAsString, parseAsArrayOf } from 'nuqs';

function useSearchFilters() {
  const [filters, setFilters] = useQueryStates({
    q:        parseAsString.withDefault(''),
    status:   parseAsArrayOf(parseAsString).withDefault([]),
    category: parseAsArrayOf(parseAsString).withDefault([]),
    sort:     parseAsString.withDefault('newest'),
  }, {
    history: 'push',    // back button undoes each filter change
    shallow: true,      // don't trigger server re-fetch on every keystroke
    throttleMs: 300,    // debounce URL writes during typing
  });

  const activeCount = [
    filters.status.length,
    filters.category.length,
    filters.q ? 1 : 0,
    filters.sort !== 'newest' ? 1 : 0,
  ].reduce((a, b) => a + b, 0);

  function clearAll() {
    setFilters({ q: '', status: [], category: [], sort: 'newest' });
  }

  return { filters, setFilters, activeCount, clearAll };
}
```

`throttleMs` on the search query field prevents a URL write (and possible server re-fetch) on every keystroke. The input value is kept in local state; the URL updates 300ms after the last keystroke.

## Search Input with Debounce

```tsx
function SearchInput({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const [localValue, setLocalValue] = useState(value);

  // Sync local → URL after typing stops
  useEffect(() => {
    const timer = setTimeout(() => onChange(localValue), 300);
    return () => clearTimeout(timer);
  }, [localValue]);

  // Sync URL → local when navigating back
  useEffect(() => { setLocalValue(value); }, [value]);

  return (
    <div className="search-input">
      <SearchIcon aria-hidden />
      <input
        type="search"
        value={localValue}
        onChange={e => setLocalValue(e.target.value)}
        placeholder="Search..."
        aria-label="Search"
      />
      {localValue && (
        <button
          type="button"
          onClick={() => { setLocalValue(''); onChange(''); }}
          aria-label="Clear search"
        >
          ×
        </button>
      )}
    </div>
  );
}
```

## Active Filter Chips

Show each active filter as a removable chip. This gives users a scannable summary of current filters and a fast removal path without reopening the filter panel.

```tsx
function ActiveFilterChips({ filters, setFilters }) {
  const chips: { label: string; remove: () => void }[] = [];

  filters.status.forEach(s =>
    chips.push({ label: `Status: ${s}`, remove: () =>
      setFilters({ status: filters.status.filter(x => x !== s) }) })
  );

  filters.category.forEach(c =>
    chips.push({ label: `Category: ${c}`, remove: () =>
      setFilters({ category: filters.category.filter(x => x !== c) }) })
  );

  if (filters.sort !== 'newest')
    chips.push({ label: `Sort: ${filters.sort}`, remove: () => setFilters({ sort: 'newest' }) });

  if (chips.length === 0) return null;

  return (
    <div className="active-filters" role="group" aria-label="Active filters">
      {chips.map(chip => (
        <span key={chip.label} className="filter-chip">
          {chip.label}
          <button
            type="button"
            onClick={chip.remove}
            aria-label={`Remove filter: ${chip.label}`}
          >×</button>
        </span>
      ))}
      <button type="button" onClick={clearAll} className="clear-all">
        Clear all
      </button>
    </div>
  );
}
```

## Filter Count Badge

Show the number of active filters on the filter panel toggle button:

```tsx
<button
  type="button"
  onClick={() => setPanelOpen(o => !o)}
  aria-expanded={panelOpen}
  aria-controls="filter-panel"
>
  <FilterIcon aria-hidden />
  Filters
  {activeCount > 0 && (
    <span className="filter-badge" aria-label={`${activeCount} active filters`}>
      {activeCount}
    </span>
  )}
</button>
```

Don't count the default sort as an active filter—only non-default values contribute to the badge count.

## Server-Side Filtering

In a server-rendered app, read filters from `searchParams` directly in the Server Component:

```tsx
// app/inventory/page.tsx
export default async function InventoryPage({ searchParams }) {
  const { q, status, category, sort } = await searchParams;

  const items = await db.query({
    search: q ?? '',
    status: status ? (Array.isArray(status) ? status : [status]) : [],
    category: category ? (Array.isArray(category) ? category : [category]) : [],
    sort: sort ?? 'newest',
  });

  return <InventoryView items={items} />;
}
```

No React state needed server-side—the URL is the state.

## Key Rules

- **URL is the single source of truth**—all filter state serialized to query params.
- **`history: 'push'`** so back button undoes filter changes one at a time.
- **Debounce search input to URL** at ~300ms—don't write on every keystroke.
- **Two-way sync** for search: local state → URL after debounce; URL → local state on navigation.
- **Active filter chips** beside the search bar—one-click removal without reopening the panel.
- **Filter count badge** on the toggle button—signals state even when panel is closed.
- **Clear all** resets to defaults, not to empty—don't leave sort undefined.
- **Don't count default values** toward the active filter badge count.
