# TanStack Table

## What TanStack Table Provides

TanStack Table (formerly React Table) is a headless UI library for building data tables. It handles:
- Column definitions and rendering
- Sorting (client-side and server-side)
- Filtering
- Pagination
- Row selection
- Column visibility

"Headless" means it provides logic, not UI. You supply the markup and CSS. This makes it work with any design system including Tailwind/shadcn.

## Installation

```bash
npm install @tanstack/react-table
```

## Minimal Table Setup

```typescript
'use client'
import {
  useReactTable,
  getCoreRowModel,
  flexRender,
  ColumnDef,
} from '@tanstack/react-table'

interface User {
  id: string
  name: string
  email: string
}

const columns: ColumnDef<User>[] = [
  { accessorKey: 'name', header: 'Name' },
  { accessorKey: 'email', header: 'Email' },
]

export function UsersTable({ users }: { users: User[] }) {
  const table = useReactTable({
    data: users,
    columns,
    getCoreRowModel: getCoreRowModel(),
  })

  return (
    <table>
      <thead>
        {table.getHeaderGroups().map(hg => (
          <tr key={hg.id}>
            {hg.headers.map(header => (
              <th key={header.id}>
                {flexRender(header.column.columnDef.header, header.getContext())}
              </th>
            ))}
          </tr>
        ))}
      </thead>
      <tbody>
        {table.getRowModel().rows.map(row => (
          <tr key={row.id}>
            {row.getVisibleCells().map(cell => (
              <td key={cell.id}>
                {flexRender(cell.column.columnDef.cell, cell.getContext())}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

## Sorting

```typescript
import { SortingState, getSortedRowModel } from '@tanstack/react-table'
import { useState } from 'react'
import { ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react'

const [sorting, setSorting] = useState<SortingState>([])

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  onSortingChange: setSorting,
  state: { sorting },
})

// Sortable column header
{
  accessorKey: 'name',
  header: ({ column }) => (
    <button onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}>
      Name
      {column.getIsSorted() === 'asc' ? <ArrowUp /> :
       column.getIsSorted() === 'desc' ? <ArrowDown /> :
       <ArrowUpDown />}
    </button>
  ),
}
```

## Filtering

```typescript
import { ColumnFiltersState, getFilteredRowModel } from '@tanstack/react-table'

const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  onColumnFiltersChange: setColumnFilters,
  state: { columnFilters },
})

// Filter input
<input
  value={(table.getColumn('name')?.getFilterValue() as string) ?? ''}
  onChange={e => table.getColumn('name')?.setFilterValue(e.target.value)}
  placeholder="Filter by name..."
/>
```

## Pagination

```typescript
import { getPaginationRowModel } from '@tanstack/react-table'

const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  initialState: {
    pagination: { pageSize: 20, pageIndex: 0 },
  },
})

// Pagination controls
<div>
  <button onClick={() => table.previousPage()} disabled={!table.getCanPreviousPage()}>
    Previous
  </button>
  <span>Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}</span>
  <button onClick={() => table.nextPage()} disabled={!table.getCanNextPage()}>
    Next
  </button>
</div>
```

## Row Selection

```typescript
import { RowSelectionState } from '@tanstack/react-table'
import { Checkbox } from '@/components/ui/checkbox'

const [rowSelection, setRowSelection] = useState<RowSelectionState>({})

// Add selection column first
const selectionColumn: ColumnDef<User> = {
  id: 'select',
  header: ({ table }) => (
    <Checkbox
      checked={table.getIsAllPageRowsSelected()}
      onCheckedChange={v => table.toggleAllPageRowsSelected(!!v)}
    />
  ),
  cell: ({ row }) => (
    <Checkbox
      checked={row.getIsSelected()}
      onCheckedChange={v => row.toggleSelected(!!v)}
    />
  ),
}

const table = useReactTable({
  data,
  columns: [selectionColumn, ...columns],
  getCoreRowModel: getCoreRowModel(),
  onRowSelectionChange: setRowSelection,
  state: { rowSelection },
})

// Get selected rows
const selectedRows = table.getFilteredSelectedRowModel().rows.map(r => r.original)
```

## Custom Cell Renderers

```typescript
{
  accessorKey: 'status',
  header: 'Status',
  cell: ({ row }) => {
    const status = row.getValue<'pending' | 'paid' | 'overdue'>('status')
    const colors = {
      pending: 'bg-yellow-100 text-yellow-800',
      paid: 'bg-green-100 text-green-800',
      overdue: 'bg-red-100 text-red-800',
    }
    return (
      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${colors[status]}`}>
        {status}
      </span>
    )
  },
}
```

## Common Mistakes

- **Not passing `state` object** — sorting/filtering state is managed externally; must pass to `state` prop
- **`columns` defined inside component** — causes re-render loop; define outside component or use `useMemo`
- **Missing `id` on action columns** — columns without `accessorKey` need explicit `id` property
