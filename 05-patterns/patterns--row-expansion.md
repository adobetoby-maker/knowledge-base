# Pattern: Row Expansion (Expandable Table Rows)

## Overview

Table rows that expand to reveal detail inline — avoids navigating away for details, reduces cognitive load for scanning. Two variants: accordion (one at a time) and multi-expand. Key challenge: layout stability when rows change height.

## TanStack Table with Expanded Rows

```tsx
import {
  useReactTable,
  getCoreRowModel,
  getExpandedRowModel,
  ExpandedState,
} from '@tanstack/react-table'

const [expanded, setExpanded] = useState<ExpandedState>({})

const table = useReactTable({
  data,
  columns,
  state: { expanded },
  onExpandedChange: setExpanded,
  getExpandedRowModel: getExpandedRowModel(),
  getCoreRowModel: getCoreRowModel(),
})
```

Add an expand toggle column:

```tsx
const columns = [
  {
    id: 'expander',
    header: () => null,
    cell: ({ row }) =>
      row.getCanExpand() ? (
        <button
          onClick={row.getToggleExpandedHandler()}
          className="p-1 hover:bg-gray-100 rounded"
          aria-label={row.getIsExpanded() ? 'Collapse' : 'Expand'}
        >
          {row.getIsExpanded() ? '▾' : '▸'}
        </button>
      ) : null,
  },
  // ...other columns
]
```

## Rendering the Detail Row

```tsx
{table.getRowModel().rows.map(row => (
  <Fragment key={row.id}>
    <tr className="border-b">
      {row.getVisibleCells().map(cell => (
        <td key={cell.id} className="px-4 py-3">
          {flexRender(cell.column.columnDef.cell, cell.getContext())}
        </td>
      ))}
    </tr>
    {row.getIsExpanded() && (
      <tr>
        <td colSpan={row.getAllCells().length} className="bg-gray-50 px-6 py-4">
          <RowDetail row={row.original} />
        </td>
      </tr>
    )}
  </Fragment>
))}
```

`colSpan` set to full column count makes the detail row span the whole table width.

## Accordion Mode (One Open at a Time)

```tsx
function handleExpandedChange(updater: Updater<ExpandedState>) {
  setExpanded(prev => {
    const next = typeof updater === 'function' ? updater(prev) : updater
    // Find newly opened row
    const newlyOpened = Object.keys(next).find(k => !(k in prev))
    if (newlyOpened) {
      // Keep only the newly opened row
      return { [newlyOpened]: true }
    }
    return next
  })
}
```

## Lazy-Load Detail Content

Don't fetch detail data for all rows upfront. Fetch when expanded:

```tsx
function RowDetail({ row }: { row: Order }) {
  const { data, isLoading } = useQuery({
    queryKey: ['order-detail', row.id],
    queryFn: () => fetchOrderDetail(row.id),
  })

  if (isLoading) return <Skeleton className="h-20" />
  return <OrderLineItems items={data.items} />
}
```

## Animation

Smooth height transition when expanding/collapsing:

```tsx
<tr>
  <td colSpan={...}>
    <div
      className={`overflow-hidden transition-all duration-200 ${
        row.getIsExpanded() ? 'max-h-96' : 'max-h-0'
      }`}
    >
      <div className="px-6 py-4">
        <RowDetail row={row.original} />
      </div>
    </div>
  </td>
</tr>
```

Using `max-height` transition is simpler than animating `height` (which requires measuring the content).

## Key Rules

- Use `Fragment` wrapper for paired rows — table DOM requires `<tr>` direct children of `<tbody>`.
- `colSpan` must equal the total number of visible columns (including action columns).
- Accordion mode (one at a time) is better for reading detail; multi-expand is better for comparison.
- Don't fetch detail data until the row expands — saves N network requests on table load.
