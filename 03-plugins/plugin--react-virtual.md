# Plugin: TanStack Virtual (react-virtual)

## Overview

TanStack Virtual renders only the visible rows of a long list. A 10,000-row table renders ~20 rows in the DOM at any time — performance stays constant regardless of list length.

## When to Virtualize

Virtualize when:
- List has more than 200 items
- Each item contains media, complex components, or event listeners
- Users scroll through (vs. paginating to a new page)

Don't virtualize:
- Lists shorter than 100 items — the complexity isn't worth it
- Paginated lists where users navigate to a new page
- Lists where items vary wildly in height (complex — use `estimateSize` + dynamic measurement)

## Fixed-Height Row Virtualization

```tsx
'use client'
import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

const ROW_HEIGHT = 60  // Fixed height in pixels

export function VirtualizedList<T>({
  items,
  renderItem,
}: {
  items: T[]
  renderItem: (item: T, index: number) => React.ReactNode
}) {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => ROW_HEIGHT,
    overscan: 5,  // Render 5 extra rows above/below viewport
  })

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      {/* Total height spacer */}
      <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.index}
            style={{
              position: 'absolute',
              top: virtualRow.start,
              left: 0,
              right: 0,
              height: ROW_HEIGHT,
            }}
          >
            {renderItem(items[virtualRow.index], virtualRow.index)}
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Variable-Height Rows

When row heights differ (e.g., expandable rows, varying text lengths):

```tsx
const virtualizer = useVirtualizer({
  count: items.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 80,  // Initial estimate — refined after measurement
  measureElement: (element) => element.getBoundingClientRect().height,
})

// In the rendered rows
<div
  key={virtualRow.key}
  ref={virtualizer.measureElement}  // Measures actual height after render
  data-index={virtualRow.index}
  style={{ position: 'absolute', top: virtualRow.start, left: 0, right: 0 }}
>
  {renderItem(items[virtualRow.index])}
</div>
```

Variable-height virtualization causes jitter during first render as heights are measured. Minimize this by: using accurate initial estimates, keeping items structurally similar, and precomputing heights when possible.

## Virtualized Table

```tsx
import { useVirtualizer } from '@tanstack/react-virtual'
import {
  flexRender,
  useReactTable,
  getCoreRowModel,
} from '@tanstack/react-table'

export function VirtualizedTable<T>({ data, columns }: TableProps<T>) {
  const table = useReactTable({ data, columns, getCoreRowModel: getCoreRowModel() })
  const parentRef = useRef<HTMLDivElement>(null)

  const { rows } = table.getRowModel()
  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 40,
    overscan: 10,
  })

  return (
    <div ref={parentRef} className="overflow-auto" style={{ height: '500px' }}>
      <table className="w-full">
        <thead className="sticky top-0 bg-white z-10">
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map((header) => (
                <th key={header.id} className="px-4 py-2 text-left text-sm font-semibold text-gray-900 border-b">
                  {flexRender(header.column.columnDef.header, header.getContext())}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
          {rowVirtualizer.getVirtualItems().map((virtualRow) => {
            const row = rows[virtualRow.index]
            return (
              <tr
                key={row.id}
                style={{
                  position: 'absolute',
                  top: virtualRow.start,
                  left: 0,
                  right: 0,
                  height: 40,
                }}
                className="hover:bg-gray-50"
              >
                {row.getVisibleCells().map((cell) => (
                  <td key={cell.id} className="px-4 py-2 text-sm">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            )
          })}
        </tbody>
      </table>
    </div>
  )
}
```

## Scroll to Row

```ts
// Programmatically scroll to a specific row (e.g., after search)
function scrollToRow(index: number) {
  virtualizer.scrollToIndex(index, { align: 'center' })
}
```

## Key Pitfalls

**The parent must have a fixed height** — `overflow-auto` only scrolls if the container has a defined height. If the parent is `height: auto`, the browser thinks it's infinitely tall and never triggers intersection.

**Don't use `key` from array index** — use a stable ID from your data. Array index keys cause React to re-render every row on filter/sort instead of reconciling by identity.

**Sticky headers need `position: sticky; top: 0; z-index`** — virtual rows are `position: absolute` inside a `position: relative` container. Sticky only works on the thead when it's outside the relative container.
