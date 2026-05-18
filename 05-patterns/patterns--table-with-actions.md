# Table with Row Actions Pattern

## Overview

Admin tables often need per-row actions: edit, delete, view, status change. This pattern combines TanStack Table with shadcn/ui DataTable and DropdownMenu for row actions.

## Complete Implementation

```typescript
// components/admin/InvoiceTable.tsx
'use client'
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getSortedRowModel,
  useReactTable,
  SortingState,
} from '@tanstack/react-table'
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table'
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Button } from '@/components/ui/button'
import { MoreHorizontal, Eye, Edit, Trash2, CheckCircle } from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'
import Link from 'next/link'

// Define columns OUTSIDE the component to prevent re-render loop
function createColumns(
  onMarkPaid: (id: string) => void,
  onDelete: (id: string) => void
): ColumnDef<Invoice>[] {
  return [
    {
      accessorKey: 'number',
      header: 'Invoice #',
      cell: ({ row }) => (
        <Link
          href={`/admin/invoices/${row.original.id}`}
          className="font-medium hover:underline"
        >
          {row.getValue('number')}
        </Link>
      ),
    },
    {
      accessorKey: 'customer_name',
      header: 'Customer',
    },
    {
      accessorKey: 'total',
      header: 'Amount',
      cell: ({ row }) => `$${Number(row.getValue('total')).toFixed(2)}`,
    },
    {
      accessorKey: 'status',
      header: 'Status',
      cell: ({ row }) => {
        const status = row.getValue('status') as string
        return (
          <span className={`px-2 py-0.5 text-xs rounded-full ${
            status === 'paid'
              ? 'bg-green-100 text-green-700'
              : status === 'overdue'
              ? 'bg-red-100 text-red-700'
              : 'bg-yellow-100 text-yellow-700'
          }`}>
            {status}
          </span>
        )
      },
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => {
        const invoice = row.original
        return (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-8 w-8">
                <MoreHorizontal className="h-4 w-4" />
                <span className="sr-only">Open menu</span>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem asChild>
                <Link href={`/admin/invoices/${invoice.id}`}>
                  <Eye className="mr-2 h-4 w-4" />
                  View
                </Link>
              </DropdownMenuItem>
              <DropdownMenuItem asChild>
                <Link href={`/admin/invoices/${invoice.id}/edit`}>
                  <Edit className="mr-2 h-4 w-4" />
                  Edit
                </Link>
              </DropdownMenuItem>
              {invoice.status !== 'paid' && (
                <DropdownMenuItem onClick={() => onMarkPaid(invoice.id)}>
                  <CheckCircle className="mr-2 h-4 w-4" />
                  Mark as paid
                </DropdownMenuItem>
              )}
              <DropdownMenuSeparator />
              <DropdownMenuItem
                onClick={() => onDelete(invoice.id)}
                className="text-destructive focus:text-destructive"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )
      },
    },
  ]
}

export function InvoiceTable({ initialInvoices }: { initialInvoices: Invoice[] }) {
  const [invoices, setInvoices] = useState(initialInvoices)
  const [sorting, setSorting] = useState<SortingState>([])

  async function handleMarkPaid(id: string) {
    const result = await markInvoicePaid(id)
    if (result.success) {
      setInvoices(prev => prev.map(inv => inv.id === id ? { ...inv, status: 'paid' } : inv))
      toast.success('Invoice marked as paid')
    } else {
      toast.error('Failed to update invoice')
    }
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this invoice? This cannot be undone.')) return
    const result = await deleteInvoice(id)
    if (result.success) {
      setInvoices(prev => prev.filter(inv => inv.id !== id))
      toast.success('Invoice deleted')
    } else {
      toast.error('Failed to delete invoice')
    }
  }

  const columns = createColumns(handleMarkPaid, handleDelete)

  const table = useReactTable({
    data: invoices,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
    state: { sorting },
  })

  return (
    <Table>
      <TableHeader>
        {table.getHeaderGroups().map(headerGroup => (
          <TableRow key={headerGroup.id}>
            {headerGroup.headers.map(header => (
              <TableHead
                key={header.id}
                onClick={header.column.getToggleSortingHandler()}
                className={header.column.getCanSort() ? 'cursor-pointer select-none' : ''}
              >
                {flexRender(header.column.columnDef.header, header.getContext())}
                {header.column.getIsSorted() === 'asc' && ' ↑'}
                {header.column.getIsSorted() === 'desc' && ' ↓'}
              </TableHead>
            ))}
          </TableRow>
        ))}
      </TableHeader>
      <TableBody>
        {table.getRowModel().rows.length === 0 ? (
          <TableRow>
            <TableCell colSpan={columns.length} className="text-center text-muted-foreground py-8">
              No invoices found
            </TableCell>
          </TableRow>
        ) : (
          table.getRowModel().rows.map(row => (
            <TableRow key={row.id}>
              {row.getVisibleCells().map(cell => (
                <TableCell key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </TableCell>
              ))}
            </TableRow>
          ))
        )}
      </TableBody>
    </Table>
  )
}
```

## Column Definition Outside Component

This is critical: column definitions created inside a component cause an infinite re-render loop because they're new objects on every render. Always define outside:

```typescript
// WRONG: recreated on every render
function InvoiceTable() {
  const columns: ColumnDef<Invoice>[] = [...]  // ← new array every render
  const table = useReactTable({ data, columns })
}

// CORRECT: stable reference
const columns: ColumnDef<Invoice>[] = [...]  // ← defined outside

function InvoiceTable() {
  const table = useReactTable({ data, columns })
}
```

When columns need callbacks (for row actions), use a factory function and `useMemo`:
```typescript
const columns = useMemo(() => createColumns(handleMarkPaid, handleDelete), [])
```
