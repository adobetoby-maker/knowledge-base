# Pattern: Per-Column Filter in Table Header

## Overview
Per-column filters are essential for power-user data tables where users need to narrow down results across specific dimensions simultaneously. The pattern must handle multiple active filters at once, persist filter state in the URL (enabling shareable filtered views), and clearly communicate which columns have active filters. The UI must be discoverable (icon in header) without cluttering the header with permanent input fields.

## Implementation

### Filter State in URL
```tsx
// URL: /customers?filters=status:active,country:US
function useColumnFilters() {
  const searchParams = useSearchParams();
  const router = useRouter();

  const filters = useMemo<Record<string, string>>(() => {
    const raw = searchParams.get('filters') ?? '';
    if (!raw) return {};
    return Object.fromEntries(
      raw.split(',').map(pair => pair.split(':').map(decodeURIComponent) as [string, string])
    );
  }, [searchParams]);

  const setFilter = (column: string, value: string) => {
    const next = { ...filters };
    if (value === '') {
      delete next[column];
    } else {
      next[column] = value;
    }
    const encoded = Object.entries(next)
      .map(([k, v]) => `${encodeURIComponent(k)}:${encodeURIComponent(v)}`)
      .join(',');
    const params = new URLSearchParams(searchParams.toString());
    if (encoded) {
      params.set('filters', encoded);
    } else {
      params.delete('filters');
    }
    params.delete('page'); // reset pagination when filter changes
    router.push(`?${params.toString()}`);
  };

  const clearFilter = (column: string) => setFilter(column, '');
  const clearAll = () => {
    const params = new URLSearchParams(searchParams.toString());
    params.delete('filters');
    params.delete('page');
    router.push(`?${params.toString()}`);
  };

  const activeCount = Object.keys(filters).length;

  return { filters, setFilter, clearFilter, clearAll, activeCount };
}
```

### Column Filter Header Cell
```tsx
function FilterableColumnHeader({
  column,
  label,
  filterType = 'text',   // 'text' | 'select' | 'date-range'
  options,               // for 'select' type
  filters,
  onSetFilter,
}: {
  column: string;
  label: string;
  filterType?: 'text' | 'select';
  options?: { value: string; label: string }[];
  filters: Record<string, string>;
  onSetFilter: (column: string, value: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState(filters[column] ?? '');
  const isActive = Boolean(filters[column]);
  const popoverRef = useRef<HTMLDivElement>(null);

  // Close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    if (open) document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [open]);

  const apply = () => {
    onSetFilter(column, draft);
    setOpen(false);
  };

  const clear = () => {
    setDraft('');
    onSetFilter(column, '');
    setOpen(false);
  };

  return (
    <th>
      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
        <span>{label}</span>
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setOpen(o => !o)}
            aria-label={`Filter by ${label}${isActive ? ` (active: ${filters[column]})` : ''}`}
            aria-pressed={isActive}
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              color: isActive ? '#3b82f6' : '#9ca3af',
              position: 'relative',
            }}
          >
            {/* Filter icon */}
            <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor">
              <path d="M1 2h10l-4 5v3l-2-1V7L1 2z" />
            </svg>
            {/* Active indicator dot */}
            {isActive && (
              <span
                style={{
                  position: 'absolute',
                  top: -2, right: -2,
                  width: 6, height: 6,
                  borderRadius: '50%',
                  background: '#3b82f6',
                }}
              />
            )}
          </button>

          {open && (
            <div
              ref={popoverRef}
              style={{
                position: 'absolute',
                top: '100%',
                left: 0,
                zIndex: 50,
                background: '#fff',
                border: '1px solid #e5e7eb',
                borderRadius: 8,
                padding: 12,
                minWidth: 200,
                boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
              }}
            >
              <label htmlFor={`filter-${column}`} style={{ fontSize: 12, fontWeight: 500 }}>
                Filter by {label}
              </label>

              {filterType === 'text' ? (
                <input
                  id={`filter-${column}`}
                  type="text"
                  value={draft}
                  onChange={e => setDraft(e.target.value)}
                  onKeyDown={e => { if (e.key === 'Enter') apply(); if (e.key === 'Escape') setOpen(false); }}
                  autoFocus
                  style={{ width: '100%', marginTop: 4 }}
                  placeholder={`Filter ${label}...`}
                />
              ) : (
                <select
                  id={`filter-${column}`}
                  value={draft}
                  onChange={e => { setDraft(e.target.value); onSetFilter(column, e.target.value); setOpen(false); }}
                  autoFocus
                  style={{ width: '100%', marginTop: 4 }}
                >
                  <option value="">All</option>
                  {options?.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
              )}

              {filterType === 'text' && (
                <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                  <button onClick={apply} style={{ flex: 1 }}>Apply</button>
                  {isActive && <button onClick={clear}>Clear</button>}
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </th>
  );
}
```

## Key Rules
- Filter state must live in URL params — in-component state is lost on page refresh and prevents sharing filtered views.
- Reset pagination (`page` param) whenever a filter changes — being on page 5 of a filtered result set that now has 2 pages is confusing.
- Show a blue dot (active indicator) on the filter icon when a column has an active filter — badge counters are insufficient alone.
- `aria-pressed={isActive}` on the filter button communicates toggle state to screen readers.
- Multiple columns can have filters simultaneously — the filters object is a map, not a single value.
- Select-type filters apply immediately on selection (no Apply button needed). Text filters apply on Enter or Apply button click.
- Provide a "Clear all filters" control when `activeCount > 0` — clearing one column at a time is tedious.
