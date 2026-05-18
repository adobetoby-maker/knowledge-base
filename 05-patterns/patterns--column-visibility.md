# Pattern: Column Visibility Toggle

## Overview

Let users show/hide table columns. Essential for tables with 8+ columns — users have different priorities and screen sizes. Persist the preference so it survives page refresh.

## TanStack Table Implementation

```tsx
import {
  useReactTable,
  getCoreRowModel,
  ColumnDef,
  VisibilityState,
} from '@tanstack/react-table'
import { useState, useEffect } from 'react'
import { Settings2 } from 'lucide-react'

const ALL_COLUMNS: ColumnDef<Invoice>[] = [
  { id: 'number', accessorKey: 'number', header: 'Invoice #' },
  { id: 'customer', accessorKey: 'customer', header: 'Customer' },
  { id: 'amount', accessorKey: 'amount', header: 'Amount' },
  { id: 'status', accessorKey: 'status', header: 'Status' },
  { id: 'date', accessorKey: 'date', header: 'Date' },
  { id: 'dueDate', accessorKey: 'dueDate', header: 'Due Date' },
  { id: 'paymentMethod', accessorKey: 'paymentMethod', header: 'Payment' },
  { id: 'notes', accessorKey: 'notes', header: 'Notes' },
]

// Columns that are always visible (can't be hidden)
const REQUIRED_COLUMNS = new Set(['number', 'customer', 'amount'])

function loadVisibility(): VisibilityState {
  try {
    const saved = localStorage.getItem('invoice-table-columns')
    return saved ? JSON.parse(saved) : {}
  } catch {
    return {}
  }
}

export function InvoiceTable({ data }: { data: Invoice[] }) {
  const [columnVisibility, setColumnVisibility] = useState<VisibilityState>(loadVisibility)
  const [pickerOpen, setPickerOpen] = useState(false)

  // Persist to localStorage when visibility changes
  useEffect(() => {
    localStorage.setItem('invoice-table-columns', JSON.stringify(columnVisibility))
  }, [columnVisibility])

  const table = useReactTable({
    data,
    columns: ALL_COLUMNS,
    state: { columnVisibility },
    onColumnVisibilityChange: setColumnVisibility,
    getCoreRowModel: getCoreRowModel(),
  })

  return (
    <div>
      {/* Toolbar with column picker */}
      <div className="flex items-center justify-between mb-3">
        <span className="text-sm text-gray-500">
          {data.length.toLocaleString()} invoices
        </span>

        <div className="relative">
          <button
            onClick={() => setPickerOpen(!pickerOpen)}
            className="flex items-center gap-1.5 rounded-lg border px-3 py-1.5 text-sm hover:bg-gray-50"
          >
            <Settings2 size={14} />
            Columns
            {/* Count of hidden columns */}
            {Object.values(columnVisibility).filter((v) => v === false).length > 0 && (
              <span className="ml-1 rounded-full bg-blue-100 px-1.5 py-0.5 text-xs text-blue-700">
                {Object.values(columnVisibility).filter((v) => v === false).length} hidden
              </span>
            )}
          </button>

          {pickerOpen && (
            <ColumnPicker
              table={table}
              requiredColumns={REQUIRED_COLUMNS}
              onClose={() => setPickerOpen(false)}
            />
          )}
        </div>
      </div>

      {/* Table */}
      <table className="w-full text-sm">
        <thead>
          {table.getHeaderGroups().map((hg) => (
            <tr key={hg.id}>
              {hg.headers.map((h) => (
                <th key={h.id} className="px-3 py-2 text-left font-medium text-gray-700">
                  {h.column.columnDef.header as string}
                </th>
              ))}
            </tr>
          ))}
        </thead>
        <tbody>
          {table.getRowModel().rows.map((row) => (
            <tr key={row.id} className="border-t">
              {row.getVisibleCells().map((cell) => (
                <td key={cell.id} className="px-3 py-2">
                  {cell.getValue() as string}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function ColumnPicker({
  table,
  requiredColumns,
  onClose,
}: {
  table: ReturnType<typeof useReactTable<Invoice>>
  requiredColumns: Set<string>
  onClose: () => void
}) {
  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 z-10" onClick={onClose} />

      {/* Dropdown */}
      <div className="absolute right-0 z-20 mt-1 w-52 rounded-lg border bg-white shadow-lg">
        <div className="border-b px-3 py-2 text-xs font-medium text-gray-500 uppercase tracking-wide">
          Toggle Columns
        </div>
        <div className="p-1">
          {table.getAllLeafColumns().map((column) => {
            const isRequired = requiredColumns.has(column.id)
            return (
              <label
                key={column.id}
                className={`flex cursor-pointer items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-gray-50 ${
                  isRequired ? 'opacity-50 cursor-not-allowed' : ''
                }`}
              >
                <input
                  type="checkbox"
                  checked={column.getIsVisible()}
                  disabled={isRequired}
                  onChange={column.getToggleVisibilityHandler()}
                  className="rounded"
                />
                {column.columnDef.header as string}
              </label>
            )
          })}
        </div>
        <div className="border-t p-2">
          <button
            className="w-full rounded py-1 text-xs text-gray-500 hover:bg-gray-50"
            onClick={() => table.resetColumnVisibility()}
          >
            Reset to default
          </button>
        </div>
      </div>
    </>
  )
}
```

## Key Decisions

**Required columns**: Some columns (like Name or ID) should never be hideable. Track these separately and disable the checkbox for them.

**Persistence**: Always persist column visibility to localStorage. Users expect their configuration to survive navigation. Store per-table with a unique key.

**Show hidden count**: The "2 hidden" badge on the button informs users that they have a custom configuration — prevents confusion when expected data doesn't appear.

**Reset option**: Always provide a "Reset to default" button. Users forget their configurations.
