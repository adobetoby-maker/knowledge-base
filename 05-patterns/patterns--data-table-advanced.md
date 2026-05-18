# Data Table Advanced Patterns

## Column Definitions Outside Component

This is the most important rule for TanStack Table performance. Column definitions defined inside a component are recreated on every render, causing the table to remount:

```typescript
// WRONG — column definitions inside component body:
export function InvoiceTable({ data }: Props) {
  const columns = [  // recreated on EVERY render
    columnHelper.accessor('id', { ... }),
  ]
  return <DataTable columns={columns} data={data} />
}

// CORRECT — defined outside component at module level:
const columnHelper = createColumnHelper<Invoice>()

const columns = [
  columnHelper.accessor('invoice_number', {
    header: 'Invoice #',
    cell: ({ row }) => <span className="font-mono">{row.original.invoice_number}</span>,
  }),
  columnHelper.accessor('customer_name', {
    header: 'Customer',
  }),
  columnHelper.accessor('status', {
    header: 'Status',
    cell: ({ getValue }) => <StatusBadge status={getValue()} />,
  }),
  columnHelper.accessor('total_amount', {
    header: () => <div className="text-right">Amount</div>,
    cell: ({ getValue }) => (
      <div className="text-right font-medium">
        ${getValue().toFixed(2)}
      </div>
    ),
  }),
  columnHelper.display({
    id: 'actions',
    cell: ({ row }) => <RowActions invoice={row.original} />,
  }),
]

export function InvoiceTable({ data }: Props) {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  })
  // ...
}
```

## Sortable Columns

```typescript
// Add sorting to column definitions:
columnHelper.accessor('created_at', {
  header: ({ column }) => (
    <Button variant="ghost" onClick={() => column.toggleSorting(column.getIsSorted() === 'asc')}>
      Date
      <ArrowUpDown className="ml-2 h-4 w-4" />
    </Button>
  ),
})

// Enable in table config:
const table = useReactTable({
  data,
  columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  state: { sorting },
  onSortingChange: setSorting,
})
```

## Server-Side Pagination

For large datasets where you can't load all rows client-side:

```typescript
// page.tsx — pass pagination state to server:
const invoices = await fetchInvoices({
  page: Number(searchParams.page) || 1,
  pageSize: 20,
  sort: searchParams.sort,
  order: searchParams.order,
})

// Table with manual pagination:
const table = useReactTable({
  data: invoices.data,
  columns,
  pageCount: invoices.pageCount,
  getCoreRowModel: getCoreRowModel(),
  manualPagination: true,
  state: { pagination: { pageIndex: page - 1, pageSize: 20 } },
})

// Pagination controls:
<div className="flex items-center justify-between">
  <p className="text-sm text-muted-foreground">
    Showing {(page - 1) * 20 + 1}–{Math.min(page * 20, invoices.total)} of {invoices.total}
  </p>
  <div className="flex gap-2">
    <Button
      variant="outline" size="sm"
      disabled={page <= 1}
      onClick={() => setPage(page - 1)}
    >
      Previous
    </Button>
    <Button
      variant="outline" size="sm"
      disabled={page >= invoices.pageCount}
      onClick={() => setPage(page + 1)}
    >
      Next
    </Button>
  </div>
</div>
```

## Row Selection with Bulk Actions

```typescript
const [rowSelection, setRowSelection] = useState({})

const table = useReactTable({
  data,
  columns: [
    // Selection column:
    {
      id: 'select',
      header: ({ table }) => (
        <Checkbox
          checked={table.getIsAllRowsSelected()}
          onCheckedChange={(v) => table.toggleAllRowsSelected(!!v)}
        />
      ),
      cell: ({ row }) => (
        <Checkbox
          checked={row.getIsSelected()}
          onCheckedChange={(v) => row.toggleSelected(!!v)}
        />
      ),
      size: 40,
    },
    ...columns,
  ],
  state: { rowSelection },
  onRowSelectionChange: setRowSelection,
  getRowId: (row) => row.id,
})

// Bulk action bar:
const selectedIds = Object.keys(rowSelection)

{selectedIds.length > 0 && (
  <div className="flex items-center gap-3 p-2 bg-muted rounded-md">
    <span className="text-sm">{selectedIds.length} selected</span>
    <Button size="sm" onClick={() => handleBulkDelete(selectedIds)}>
      Delete selected
    </Button>
    <Button size="sm" variant="outline" onClick={() => setRowSelection({})}>
      Clear
    </Button>
  </div>
)}
```

## Empty State

```typescript
// After rendering headers:
{table.getRowModel().rows.length === 0 && (
  <TableRow>
    <TableCell colSpan={columns.length} className="h-32 text-center text-muted-foreground">
      {isFiltered ? 'No invoices match your filters.' : 'No invoices yet.'}
    </TableCell>
  </TableRow>
)}
```

## Optimistic Row Deletion

```typescript
function RowActions({ invoice }: { invoice: Invoice }) {
  const queryClient = useQueryClient()
  
  const deleteMutation = useMutation({
    mutationFn: () => deleteInvoice(invoice.id),
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: ['invoices'] })
      const prev = queryClient.getQueryData(['invoices'])
      queryClient.setQueryData(['invoices'], (old: Invoice[]) =>
        old.filter(i => i.id !== invoice.id)
      )
      return { prev }
    },
    onError: (_, __, context) => {
      queryClient.setQueryData(['invoices'], context?.prev)
      toast.error('Failed to delete invoice')
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: ['invoices'] }),
  })
  
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon"><MoreHorizontal className="h-4 w-4" /></Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={() => deleteMutation.mutate()}>Delete</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```
