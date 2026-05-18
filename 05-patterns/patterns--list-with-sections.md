# Pattern: Grouped List with Sticky Section Headers

## Overview
Section headers that scroll away leave users confused about which group they're viewing, especially in long contact lists, sidebars, or alphabetical indexes. Without proper semantic HTML, screen reader users can't understand the list structure. Keyboard navigation should skip over headers — they are not interactive elements — and land only on list items.

## Implementation

```tsx
// GroupedList.tsx
interface GroupedListProps<T> {
  groups: Array<{
    key: string
    label: string
    items: T[]
  }>
  renderItem: (item: T, index: number) => React.ReactNode
  getItemId: (item: T) => string
}

export function GroupedList<T>({ groups, renderItem, getItemId }: GroupedListProps<T>) {
  return (
    // Outer list contains group items
    <ul
      style={{ listStyle: 'none', padding: 0, margin: 0, position: 'relative' }}
      role="list"
    >
      {groups.map(group => (
        <li key={group.key}>
          {/* Section header — sticky within the scroll container */}
          <div
            role="presentation"  // Not interactive — presentation role removes from tab order
            aria-hidden="true"   // Screen readers see the nested list structure instead
            style={{
              position: 'sticky',
              top: 0,
              zIndex: 10,
              // CRITICAL: background must be solid, not transparent
              // transparent = all list items bleed through header on scroll
              backgroundColor: 'var(--color-surface-secondary, #f5f5f5)',
              padding: '6px 12px',
              fontSize: 12,
              fontWeight: 600,
              letterSpacing: '0.05em',
              textTransform: 'uppercase',
              color: '#666',
              // Border bottom separates header from content
              borderBottom: '1px solid var(--color-border, #e5e5e5)',
            }}
          >
            {group.label}
          </div>

          {/* Inner list of items within this group */}
          {/* Nested <ul> inside <li> is semantically correct */}
          <ul style={{ listStyle: 'none', padding: 0, margin: 0 }} role="list">
            {group.items.map((item, index) => (
              <li key={getItemId(item)}>
                {renderItem(item, index)}
              </li>
            ))}
          </ul>
        </li>
      ))}
    </ul>
  )
}
```

```tsx
// Keyboard navigation — skip headers, navigate only items
// When using a "listbox" pattern (selectable items), keyboard nav skips headers
function useGroupedListKeyboard(groups: Group[]) {
  // Flatten all items for sequential keyboard navigation
  const flatItems = useMemo(
    () => groups.flatMap(g => g.items),
    [groups]
  )

  const [focusedIndex, setFocusedIndex] = useState(-1)

  function handleKeyDown(e: React.KeyboardEvent) {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault()
        setFocusedIndex(i => Math.min(i + 1, flatItems.length - 1))
        break
      case 'ArrowUp':
        e.preventDefault()
        setFocusedIndex(i => Math.max(i - 1, 0))
        break
      // Headers are never in the flatItems array — navigation skips them automatically
    }
  }

  return { flatItems, focusedIndex, handleKeyDown }
}
```

```tsx
// Virtualized version — required when total items > 500
import { useVirtualizer } from '@tanstack/react-virtual'

interface FlatRow<T> {
  type: 'header' | 'item'
  label?: string
  item?: T
  groupKey?: string
}

function flattenGroups<T>(groups: GroupedListProps<T>['groups']): FlatRow<T>[] {
  return groups.flatMap(group => [
    { type: 'header', label: group.label, groupKey: group.key },
    ...group.items.map(item => ({ type: 'item' as const, item })),
  ])
}

export function VirtualizedGroupedList<T>({ groups, renderItem, getItemId }: GroupedListProps<T>) {
  const rows = useMemo(() => flattenGroups(groups), [groups])
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: i => rows[i].type === 'header' ? 36 : 56,
    overscan: 5,
  })

  return (
    <div ref={parentRef} style={{ height: 600, overflow: 'auto' }}>
      <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => {
          const row = rows[virtualItem.index]

          return (
            <div
              key={virtualItem.index}
              style={{
                position: 'absolute',
                top: virtualItem.start,
                width: '100%',
                height: virtualItem.size,
              }}
            >
              {row.type === 'header' ? (
                <div
                  aria-hidden
                  style={{
                    // NOTE: sticky headers don't work inside virtualized lists
                    // because items are absolutely positioned.
                    // Use a separate sticky overlay for the current section label
                    // or accept non-sticky headers in virtualized mode.
                    padding: '6px 12px',
                    fontWeight: 600,
                    fontSize: 12,
                    backgroundColor: '#f5f5f5',
                  }}
                >
                  {row.label}
                </div>
              ) : (
                renderItem(row.item!, virtualItem.index)
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
```

## Key Rules
- Section headers must have a solid `background-color` — transparent headers let scrolling content bleed through.
- Use nested `<ul>` inside `<li>` for groups: `<ul> <li> [header] <ul> <li>[items]` — this is semantically correct and communicated to screen readers as nested lists.
- Mark headers with `role="presentation"` and `aria-hidden="true"` — they are visual separators, not interactive or navigable elements.
- Keyboard navigation (ArrowDown/Up) must skip headers — flatten all items for the navigation index so headers are invisible to keyboard traversal.
- `position: sticky; top: 0` on the header div, with a bounded scroll container (parent has `overflow-y: auto` and defined height).
- `z-index: 10` on headers so they stack above scrolling items.
- Virtualize when total item count exceeds ~500 — non-virtualized long lists block the main thread.
- In virtualized mode, CSS sticky headers don't work (absolute positioning overrides sticky) — use a separate fixed overlay showing the current section label, or accept non-sticky headers.
- Never use `<h2>`–`<h6>` for list section headers — it pollutes the page heading outline. Use `<div role="presentation">` or `<div aria-hidden>`.
