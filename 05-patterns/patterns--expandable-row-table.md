# Pattern: Expandable Table Rows

## Overview
Expandable rows let users access detail without leaving the table context, preserving awareness of surrounding records. Lazy-loading row detail on first expand (not on table load) is critical for performance — a table with 50 expandable rows should not fire 50 additional queries on render. Whether to allow multiple rows open simultaneously is a UI choice: single-expand keeps the view cleaner; multi-expand lets users compare rows.

## Implementation

### Expansion State
```tsx
// Single-expand: only one row open at a time
function useSingleExpand() {
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const toggle = (id: string) =>
    setExpandedId((prev) => (prev === id ? null : id))
  return { expandedId, toggle, isExpanded: (id: string) => expandedId === id }
}

// Multi-expand: multiple rows open simultaneously
function useMultiExpand() {
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set())
  const toggle = (id: string) =>
    setExpandedIds((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  return { toggle, isExpanded: (id: string) => expandedIds.has(id) }
}
```

### Lazy Load Row Detail
```tsx
// Track which rows have been expanded — fetch only on first open
function useRowDetail(id: string, isExpanded: boolean) {
  const hasFetchedRef = useRef(false)
  const [data, setData] = useState<RowDetail | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (!isExpanded || hasFetchedRef.current) return
    hasFetchedRef.current = true

    setLoading(true)
    fetchRowDetail(id)
      .then(setData)
      .finally(() => setLoading(false))
  }, [isExpanded, id])

  return { data, loading }
}
```

### Table Row + Expansion
```tsx
function ExpandableRow({ row }: { row: TableRow }) {
  const { isExpanded, toggle } = useSingleExpand() // or useMultiExpand

  const expandedRowId = `expanded-${row.id}`

  return (
    <>
      <tr
        onClick={() => toggle(row.id)}
        aria-expanded={isExpanded(row.id)}
        aria-controls={expandedRowId}
        className="cursor-pointer hover:bg-gray-50"
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            toggle(row.id)
          }
        }}
      >
        {/* Chevron indicator */}
        <td className="w-10 pr-0">
          <svg
            aria-hidden="true"
            className={[
              'w-4 h-4 text-gray-400 transition-transform duration-150',
              isExpanded(row.id) ? 'rotate-90' : '',
            ].join(' ')}
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path fillRule="evenodd" d="M7.293 4.707a1 1 0 010 1.414L4.414 9H17a1 1 0 010 2H4.414l2.879 2.879a1 1 0 01-1.414 1.414l-4.586-4.586a1 1 0 010-1.414l4.586-4.586a1 1 0 011.414 0z" clipRule="evenodd" />
          </svg>
        </td>
        <td>{row.name}</td>
        <td>{row.status}</td>
        <td>{row.date}</td>
      </tr>

      {/* Expanded detail row */}
      <tr
        id={expandedRowId}
        className={isExpanded(row.id) ? '' : 'hidden'}
        aria-hidden={!isExpanded(row.id)}
      >
        <td colSpan={4} className="bg-gray-50 px-6 py-4">
          <ExpandedRowContent rowId={row.id} isVisible={isExpanded(row.id)} />
        </td>
      </tr>
    </>
  )
}
```

### Lazy Content Component
```tsx
function ExpandedRowContent({
  rowId,
  isVisible,
}: {
  rowId: string
  isVisible: boolean
}) {
  const { data, loading } = useRowDetail(rowId, isVisible)

  if (loading) {
    return (
      <div className="flex gap-4 animate-pulse">
        <div className="h-4 bg-gray-200 rounded w-1/4" />
        <div className="h-4 bg-gray-200 rounded w-1/3" />
        <div className="h-4 bg-gray-200 rounded w-1/4" />
      </div>
    )
  }

  if (!data) return null

  return (
    <dl className="grid grid-cols-3 gap-4 text-sm">
      {Object.entries(data).map(([key, value]) => (
        <div key={key}>
          <dt className="text-gray-500 capitalize">{key}</dt>
          <dd className="font-medium">{String(value)}</dd>
        </div>
      ))}
    </dl>
  )
}
```

### Multi-Expand Toggle in Table Header
```tsx
function ExpandAllToggle({
  allExpanded,
  onExpandAll,
  onCollapseAll,
}: {
  allExpanded: boolean
  onExpandAll: () => void
  onCollapseAll: () => void
}) {
  return (
    <button
      type="button"
      onClick={allExpanded ? onCollapseAll : onExpandAll}
      className="text-xs text-blue-600 hover:underline"
    >
      {allExpanded ? 'Collapse all' : 'Expand all'}
    </button>
  )
}
```

## Key Rules
- Lazy-load detail content on first expand — never fetch all row details when the table renders
- Cache fetched detail so re-expanding a row doesn't re-fetch — use a `hasFetchedRef` or query library
- Keyboard: Space or Enter on the row toggles expansion — `tabIndex={0}` on the `<tr>` element enables focus
- `aria-expanded` on the `<tr>` + `aria-controls` pointing to the expanded `<tr>` id is the correct ARIA pattern
- Chevron rotates 90° when expanded — rotation direction: right = collapsed, down = expanded
- Use `hidden` attribute (not `display: none` via CSS class alone) on the expanded row when collapsed — this prevents the content from being read by screen readers when invisible
- For multi-expand: provide "Expand all / Collapse all" toggle in the header — manually opening 50 rows is tedious
- Expanded row spans full column width (`colSpan={n}`) — never truncate detail into a partial column width
