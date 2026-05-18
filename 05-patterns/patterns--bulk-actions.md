# Pattern: Bulk Actions

## Overview

Select multiple table rows and apply an action to all of them. Essential for: email management, invoice bulk processing, user administration, content moderation.

## Selection State

```tsx
import { useState, useCallback } from 'react'

type SelectionState = Set<string>  // Set of selected IDs

function useSelection(allIds: string[]) {
  const [selected, setSelected] = useState<SelectionState>(new Set())

  const toggle = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(id)) {
        next.delete(id)
      } else {
        next.add(id)
      }
      return next
    })
  }, [])

  const selectAll = useCallback(() => {
    setSelected(new Set(allIds))
  }, [allIds])

  const deselectAll = useCallback(() => {
    setSelected(new Set())
  }, [])

  const isSelected = useCallback(
    (id: string) => selected.has(id),
    [selected],
  )

  const isAllSelected = selected.size === allIds.length && allIds.length > 0
  const isPartiallySelected = selected.size > 0 && selected.size < allIds.length

  return { selected, toggle, selectAll, deselectAll, isSelected, isAllSelected, isPartiallySelected }
}
```

## Table with Bulk Selection

```tsx
export function InvoiceTable({ invoices }: { invoices: Invoice[] }) {
  const ids = useMemo(() => invoices.map((i) => i.id), [invoices])
  const { selected, toggle, selectAll, deselectAll, isSelected, isAllSelected, isPartiallySelected } = useSelection(ids)

  const [bulkLoading, setBulkLoading] = useState(false)

  async function handleBulkAction(action: 'archive' | 'delete' | 'export') {
    const ids = Array.from(selected)
    setBulkLoading(true)
    
    try {
      if (action === 'archive') await archiveInvoices(ids)
      if (action === 'delete') await deleteInvoices(ids)
      if (action === 'export') await exportInvoices(ids)
      deselectAll()
    } finally {
      setBulkLoading(false)
    }
  }

  return (
    <div>
      {/* Bulk action toolbar — appears when rows selected */}
      {selected.size > 0 && (
        <BulkActionBar
          count={selected.size}
          total={invoices.length}
          loading={bulkLoading}
          onAction={handleBulkAction}
          onDeselect={deselectAll}
        />
      )}

      <table className="w-full text-sm">
        <thead>
          <tr className="border-b">
            <th className="w-10 px-3 py-2">
              {/* Indeterminate checkbox for select-all */}
              <IndeterminateCheckbox
                checked={isAllSelected}
                indeterminate={isPartiallySelected}
                onChange={() => isAllSelected ? deselectAll() : selectAll()}
              />
            </th>
            <th className="px-3 py-2 text-left">Invoice</th>
            <th className="px-3 py-2 text-left">Amount</th>
            <th className="px-3 py-2 text-left">Status</th>
          </tr>
        </thead>
        <tbody>
          {invoices.map((invoice) => (
            <tr
              key={invoice.id}
              className={`border-b ${isSelected(invoice.id) ? 'bg-blue-50' : 'hover:bg-gray-50'}`}
            >
              <td className="px-3 py-2">
                <input
                  type="checkbox"
                  checked={isSelected(invoice.id)}
                  onChange={() => toggle(invoice.id)}
                  className="rounded"
                />
              </td>
              <td className="px-3 py-2 font-medium">{invoice.number}</td>
              <td className="px-3 py-2">${(invoice.amount / 100).toFixed(2)}</td>
              <td className="px-3 py-2">{invoice.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
```

## Indeterminate Checkbox

```tsx
import { useEffect, useRef } from 'react'

function IndeterminateCheckbox({
  checked,
  indeterminate,
  onChange,
}: {
  checked: boolean
  indeterminate: boolean
  onChange: () => void
}) {
  const ref = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (ref.current) {
      ref.current.indeterminate = indeterminate
    }
  }, [indeterminate])

  return (
    <input
      ref={ref}
      type="checkbox"
      checked={checked}
      onChange={onChange}
      className="rounded"
    />
  )
}
```

The `indeterminate` state (dash instead of checkmark) requires a DOM property — can't be set via HTML attribute, must use a ref.

## Bulk Action Bar

```tsx
function BulkActionBar({
  count,
  total,
  loading,
  onAction,
  onDeselect,
}: {
  count: number
  total: number
  loading: boolean
  onAction: (action: 'archive' | 'delete' | 'export') => void
  onDeselect: () => void
}) {
  return (
    <div className="flex items-center gap-3 rounded-lg bg-blue-600 px-4 py-2.5 text-white mb-2">
      <span className="text-sm font-medium">
        {count} of {total} selected
      </span>

      <div className="ml-auto flex items-center gap-2">
        <button
          onClick={() => onAction('export')}
          disabled={loading}
          className="rounded px-3 py-1 text-sm bg-white/20 hover:bg-white/30"
        >
          Export
        </button>
        <button
          onClick={() => onAction('archive')}
          disabled={loading}
          className="rounded px-3 py-1 text-sm bg-white/20 hover:bg-white/30"
        >
          Archive
        </button>
        <button
          onClick={() => onAction('delete')}
          disabled={loading}
          className="rounded px-3 py-1 text-sm bg-red-500 hover:bg-red-600"
        >
          Delete
        </button>
        <button
          onClick={onDeselect}
          className="rounded p-1 hover:bg-white/20"
          aria-label="Clear selection"
        >
          ✕
        </button>
      </div>
    </div>
  )
}
```

## Shift-Click Range Selection

```ts
function useSelection(allIds: string[]) {
  const [selected, setSelected] = useState<SelectionState>(new Set())
  const lastSelected = useRef<string | null>(null)

  const toggle = useCallback((id: string, shiftKey: boolean) => {
    if (shiftKey && lastSelected.current) {
      // Select range between lastSelected and id
      const startIdx = allIds.indexOf(lastSelected.current)
      const endIdx = allIds.indexOf(id)
      const [from, to] = [Math.min(startIdx, endIdx), Math.max(startIdx, endIdx)]
      const rangeIds = allIds.slice(from, to + 1)
      
      setSelected((prev) => {
        const next = new Set(prev)
        rangeIds.forEach((id) => next.add(id))
        return next
      })
    } else {
      setSelected((prev) => {
        const next = new Set(prev)
        if (next.has(id)) next.delete(id)
        else next.add(id)
        return next
      })
    }
    lastSelected.current = id
  }, [allIds])

  // Pass shiftKey from event:
  // onClick={(e) => toggle(id, e.shiftKey)}
}
```

Shift-click range selection matches email client behavior that users already know.
