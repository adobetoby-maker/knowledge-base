# Data Table Pattern

## When to Use

Use a data table when displaying a list of records that needs: sorting, filtering, pagination, or row selection. A plain `<ul>` is fine for simple read-only lists without those features.

## TanStack Table + shadcn/ui DataTable

The standard implementation in these projects uses TanStack Table for logic and shadcn/ui for rendering.

```typescript
// components/invoices/columns.tsx
import { ColumnDef } from '@tanstack/react-table'
import { Invoice } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { ArrowUpDown } from 'lucide-react'
import { formatCurrency, formatDate } from '@/lib/format'

export const columns: ColumnDef<Invoice>[] = [
  {
    accessorKey: 'number',
    header: 'Invoice #',
  },
  {
    accessorKey: 'customer_name',
    header: ({ column }) => (
      <Button variant="ghost" onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}>
        Customer
        <ArrowUpDown className="ml-2 h-4 w-4" />
      </Button>
    ),
  },
  {
    accessorKey: 'total',
    header: 'Amount',
    cell: ({ row }) => formatCurrency(row.getValue('total')),
  },
  {
    accessorKey: 'status',
    header: 'Status',
    cell: ({ row }) => {
      const status = row.getValue<string>('status')
      return (
        <span className={`px-2 py-1 rounded-full text-xs font-medium ${
          status === 'paid' ? 'bg-green-100 text-green-800' :
          status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
          'bg-red-100 text-red-800'
        }`}>
          {status}
        </span>
      )
    },
  },
  {
    accessorKey: 'created_at',
    header: 'Date',
    cell: ({ row }) => formatDate(row.getValue('created_at')),
  },
]
```

```typescript
// components/invoices/data-table.tsx
'use client'
import {
  useReactTable,
  getCoreRowModel,
  getSortedRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  flexRender,
  SortingState,
  ColumnFiltersState,
} from '@tanstack/react-table'
import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

interface DataTableProps<TData> {
  columns: ColumnDef<TData>[]
  data: TData[]
}

export function DataTable<TData>({ columns, data }: DataTableProps<TData>) {
  const [sorting, setSorting] = useState<SortingState>([])
  const [columnFilters, setColumnFilters] = useState<ColumnFiltersState>([])

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    onSortingChange: setSorting,
    onColumnFiltersChange: setColumnFilters,
    state: { sorting, columnFilters },
    initialState: { pagination: { pageSize: 20 } },
  })

  return (
    <div className="space-y-4">
      <Input
        placeholder="Filter by customer..."
        value={(table.getColumn('customer_name')?.getFilterValue() as string) ?? ''}
        onChange={e => table.getColumn('customer_name')?.setFilterValue(e.target.value)}
        className="max-w-sm"
      />
      
      <div className="rounded-md border">
        <table className="w-full">
          <thead>
            {table.getHeaderGroups().map(headerGroup => (
              <tr key={headerGroup.id} className="border-b bg-muted/50">
                {headerGroup.headers.map(header => (
                  <th key={header.id} className="px-4 py-3 text-left text-sm font-medium">
                    {flexRender(header.column.columnDef.header, header.getContext())}
                  </th>
                ))}
              </tr>
            ))}
          </thead>
          <tbody>
            {table.getRowModel().rows.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-8 text-center text-muted-foreground">
                  No invoices found.
                </td>
              </tr>
            ) : (
              table.getRowModel().rows.map(row => (
                <tr key={row.id} className="border-b hover:bg-muted/50 transition-colors">
                  {row.getVisibleCells().map(cell => (
                    <td key={cell.id} className="px-4 py-3 text-sm">
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
          {' '}· {table.getFilteredRowModel().rows.length} total
        </p>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.previousPage()}
            disabled={!table.getCanPreviousPage()}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.nextPage()}
            disabled={!table.getCanNextPage()}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  )
}
```

## Server-Side Pagination (Large Datasets)

When data exceeds ~1000 rows, switch to server-side pagination — fetch only the current page from Supabase.

```typescript
// app/admin/invoices/page.tsx
export default async function InvoicesPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; q?: string }>
}) {
  const { page = '1', q = '' } = await searchParams
  const currentPage = parseInt(page)
  const pageSize = 20
  const from = (currentPage - 1) * pageSize
  const to = from + pageSize - 1

  const supabase = createAdminClient()
  let query = supabase
    .from('invoices')
    .select('*, customers(name)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, to)

  if (q) query = query.ilike('customers.name', `%${q}%`)

  const { data: invoices, count } = await query

  return (
    <div>
      <ServerDataTable
        data={invoices ?? []}
        totalCount={count ?? 0}
        currentPage={currentPage}
        pageSize={pageSize}
      />
    </div>
  )
}
```

## Row Actions

Add an actions column for edit/delete/view per row:

```typescript
{
  id: 'actions',
  cell: ({ row }) => {
    const invoice = row.original
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon">
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => router.push(`/admin/invoices/${invoice.id}`)}>
            View
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => handleDelete(invoice.id)} className="text-destructive">
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    )
  },
}
```

## Common Pitfalls

- **Client-side filtering on server-paginated tables** — filter must happen server-side when data is paginated at the DB level
- **No empty state** — always show a "No results" message when rows are empty
- **Missing column key stability** — use `id` property on columns without `accessorKey` to prevent React key warnings
