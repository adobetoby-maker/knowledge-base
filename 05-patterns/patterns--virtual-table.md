# Pattern: Virtualized Data Table

## Overview

Render only visible rows in a data table with thousands of rows. Without virtualization, 10,000 rows of DOM nodes causes severe scroll jank. With it, only ~20-40 rows exist in the DOM at any time.

## Library: TanStack Virtual + TanStack Table

The two libraries compose: TanStack Table handles data logic, TanStack Virtual handles rendering.

```bash
npm install @tanstack/react-table @tanstack/react-virtual
```

## Implementation

```tsx
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  ColumnDef,
  flexRender,
} from '@tanstack/react-table'
import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

interface Invoice {
  id: string
  number: string
  customer: string
  amount: number
  status: 'paid' | 'pending' | 'overdue'
  date: string
}

const columns: ColumnDef<Invoice>[] = [
  { accessorKey: 'number', header: 'Invoice #', size: 120 },
  { accessorKey: 'customer', header: 'Customer', size: 200 },
  {
    accessorKey: 'amount',
    header: 'Amount',
    size: 100,
    cell: ({ getValue }) => `$${(getValue<number>() / 100).toFixed(2)}`,
  },
  { accessorKey: 'status', header: 'Status', size: 100 },
  { accessorKey: 'date', header: 'Date', size: 120 },
]

export function VirtualInvoiceTable({ data }: { data: Invoice[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  const { rows } = table.getRowModel()

  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48,         // Row height in px
    overscan: 5,                    // Render 5 extra rows beyond viewport
  })

  const totalSize = virtualizer.getTotalSize()
  const virtualRows = virtualizer.getVirtualItems()

  // Padding to maintain correct scroll position
  const paddingTop = virtualRows[0]?.start ?? 0
  const paddingBottom = totalSize - (virtualRows[virtualRows.length - 1]?.end ?? 0)

  return (
    <div
      ref={parentRef}
      className="h-[600px] overflow-auto border rounded-lg"
    >
      <table className="w-full border-collapse text-sm">
        {/* Sticky header — NOT virtualized */}
        <thead className="sticky top-0 z-10 bg-white border-b">
          {table.getHeaderGroups().map((headerGroup) => (
            <tr key={headerGroup.id}>
              {headerGroup.headers.map((header) => (
                <th
                  key={header.id}
                  style={{ width: header.getSize() }}
                  className="px-3 py-2 text-left font-medium text-gray-700 cursor-pointer select-none"
                  onClick={header.column.getToggleSortingHandler()}
                >
                  {flexRender(header.column.columnDef.header, header.getContext())}
                  {{ asc: ' ↑', desc: ' ↓' }[header.column.getIsSorted() as string] ?? null}
                </th>
              ))}
            </tr>
          ))}
        </thead>

        <tbody>
          {/* Top padding — fills space above virtual rows */}
          {paddingTop > 0 && (
            <tr><td style={{ height: paddingTop }} /></tr>
          )}

          {/* Only rendered rows */}
          {virtualRows.map((virtualRow) => {
            const row = rows[virtualRow.index]
            return (
              <tr
                key={row.id}
                className="border-b hover:bg-gray-50"
                style={{ height: 48 }}
              >
                {row.getVisibleCells().map((cell) => (
                  <td key={cell.id} className="px-3 py-2 text-gray-700">
                    {flexRender(cell.column.columnDef.cell, cell.getContext())}
                  </td>
                ))}
              </tr>
            )
          })}

          {/* Bottom padding — fills space below virtual rows */}
          {paddingBottom > 0 && (
            <tr><td style={{ height: paddingBottom }} /></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
```

## Variable Row Heights

If rows have different heights (expandable rows, multi-line cells):

```ts
const virtualizer = useVirtualizer({
  count: rows.length,
  getScrollElement: () => parentRef.current,
  estimateSize: () => 48,      // Initial estimate
  measureElement: (el) => el.getBoundingClientRect().height,  // Measure actual
  overscan: 10,                // More overscan for variable heights
})
```

In the row: add `ref={virtualizer.measureElement}` and `data-index={virtualRow.index}`.

Variable height virtualization is more complex — use fixed height when possible.

## When to Use Virtualization

| Row count | Approach |
|-----------|---------|
| < 100 | No virtualization — render all |
| 100-1000 | Pagination (simpler) |
| 1000-10000 | Virtualization worthwhile |
| > 10000 | Virtualization required + server pagination |

**Don't virtualize prematurely.** Pagination is simpler and often more usable than virtual scrolling (especially on mobile). Virtualize when: the dataset is continuous (log viewer, monitoring), users need to scroll without page breaks.

## Sticky Columns

TanStack Table supports pinning columns:

```ts
const table = useReactTable({
  ...
  state: {
    columnPinning: { left: ['select', 'number'] },
  },
})
```

With virtualization, sticky columns require explicit left offsets per column — more complex to implement correctly.
