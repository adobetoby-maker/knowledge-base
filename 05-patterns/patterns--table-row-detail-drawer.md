# Pattern: Table Row Detail Drawer

## Overview
When a table row contains more information than fits in columns, a detail drawer is preferable to a full-page navigation because it keeps the table visible — users can see where they are and navigate to adjacent rows without going back. Dimming the table (not hiding it) reinforces focus without scroll-locking, which prevents mobile viewport jumping. Updating the URL with the row ID makes the detail view shareable and bookmarkable.

## Implementation

### URL State
```tsx
// Using URLSearchParams to store the detail row ID
// /items?detail=123

function useDetailDrawer() {
  const [searchParams, setSearchParams] = useSearchParams()
  const detailId = searchParams.get('detail')

  const open = (id: string) =>
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('detail', id)
      return next
    }, { replace: false }) // push to history so back button closes drawer

  const close = () =>
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.delete('detail')
      return next
    }, { replace: false })

  return { detailId, open, close }
}
```

### Keyboard Escape
```tsx
function useEscapeKey(onEscape: () => void, enabled: boolean) {
  useEffect(() => {
    if (!enabled) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onEscape()
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [onEscape, enabled])
}
```

### Drawer Component
```tsx
function RowDetailDrawer({
  id,
  onClose,
  renderContent,
}: {
  id: string | null
  onClose: () => void
  renderContent: (id: string) => React.ReactNode
}) {
  useEscapeKey(onClose, !!id)

  return (
    <>
      {/* Overlay — dims but does NOT scroll-lock */}
      <div
        aria-hidden="true"
        onClick={onClose}
        className={[
          'fixed inset-0 bg-black/30 z-30 transition-opacity duration-200',
          id ? 'opacity-100' : 'opacity-0 pointer-events-none',
        ].join(' ')}
      />

      {/* Drawer panel */}
      <div
        role="dialog"
        aria-modal="false"  // false: main content is still accessible
        aria-label="Row details"
        className={[
          'fixed inset-y-0 right-0 w-full max-w-lg bg-white shadow-xl z-40',
          'flex flex-col transition-transform duration-300 ease-in-out',
          id ? 'translate-x-0' : 'translate-x-full',
        ].join(' ')}
      >
        {/* Drawer header */}
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <button
            type="button"
            onClick={onClose}
            aria-label="Close details"
            className="flex items-center gap-1 text-sm text-gray-600 hover:text-gray-900"
          >
            <span aria-hidden="true">←</span>
            Back
          </button>
        </div>

        {/* Drawer body — has its own scroll */}
        <div className="flex-1 overflow-y-auto p-4">
          {id ? renderContent(id) : null}
        </div>
      </div>
    </>
  )
}
```

### Table Integration
```tsx
function ItemsTable() {
  const { detailId, open, close } = useDetailDrawer()

  return (
    <div className={detailId ? 'opacity-50 pointer-events-none' : ''}>
      <table>
        <tbody>
          {items.map((item) => (
            <tr
              key={item.id}
              onClick={() => open(item.id)}
              className="cursor-pointer hover:bg-gray-50"
              aria-selected={detailId === item.id}
            >
              <td>{item.name}</td>
              <td>{item.status}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <RowDetailDrawer
        id={detailId}
        onClose={close}
        renderContent={(id) => <ItemDetail id={id} />}
      />
    </div>
  )
}
```

### Lazy-Load Detail Content
```tsx
function ItemDetail({ id }: { id: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ['item', id],
    queryFn: () => fetchItem(id),
    // Fetch on first open — staleTime keeps it cached if user reopens same row
    staleTime: 30_000,
  })

  if (isLoading) return <DetailSkeleton />
  if (!data) return <p>Not found</p>
  return <ItemDetailForm item={data} />
}
```

## Key Rules
- Use `replace: false` (push to history) so the browser back button closes the drawer naturally
- Dim the main content area with a semi-transparent overlay; do NOT add `overflow: hidden` to `<body>` — this causes layout shift and breaks mobile scroll position
- `aria-modal="false"` on the drawer — unlike a true modal, the table remains interactive (users can click another row)
- Escape key must close the drawer — add the listener only when drawer is open
- The drawer must have its own `overflow-y: auto` scroll region — letting it overflow the viewport makes content unreachable
- Put a visible "Back" or close button at the top of the drawer — do not rely on Escape alone on mobile
- Lazy-load the detail content on drawer open, not when the table row data loads — avoids fetching detail for every visible row
- Animate with `transform: translateX` not `width` — width animation causes reflows and jank
