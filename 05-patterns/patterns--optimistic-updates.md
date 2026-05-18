# Optimistic Updates Pattern

## What Optimistic Updates Are

An optimistic update assumes the server will succeed and immediately updates the UI, rolling back only if the server returns an error. The UI feels instant — no waiting for the network.

Best used for: mutations with high success rate (delete item, toggle status, add to list). Not suitable for: complex operations that might frequently fail validation.

## TanStack Query Optimistic Updates

The standard pattern with TanStack Query:

```typescript
'use client'
import { useMutation, useQueryClient } from '@tanstack/react-query'

export function useToggleInvoiceStatus(invoiceId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (newStatus: 'pending' | 'paid') =>
      fetch(`/api/invoices/${invoiceId}/status`, {
        method: 'PATCH',
        body: JSON.stringify({ status: newStatus }),
      }).then(r => {
        if (!r.ok) throw new Error('Failed to update status')
        return r.json()
      }),

    onMutate: async (newStatus) => {
      // Cancel any in-flight refetches
      await queryClient.cancelQueries({ queryKey: ['invoices'] })
      
      // Snapshot the current value (for rollback)
      const previousInvoices = queryClient.getQueryData<Invoice[]>(['invoices'])
      
      // Optimistically update the cache
      queryClient.setQueryData<Invoice[]>(['invoices'], (old) =>
        old?.map(inv =>
          inv.id === invoiceId ? { ...inv, status: newStatus } : inv
        )
      )
      
      // Return context for rollback
      return { previousInvoices }
    },

    onError: (err, newStatus, context) => {
      // Rollback on error
      if (context?.previousInvoices) {
        queryClient.setQueryData(['invoices'], context.previousInvoices)
      }
    },

    onSettled: () => {
      // Always refetch after success or error to sync with server
      queryClient.invalidateQueries({ queryKey: ['invoices'] })
    },
  })
}
```

```typescript
// Usage
function InvoiceRow({ invoice }: { invoice: Invoice }) {
  const toggleStatus = useToggleInvoiceStatus(invoice.id)

  return (
    <button
      onClick={() => toggleStatus.mutate(invoice.status === 'paid' ? 'pending' : 'paid')}
      disabled={toggleStatus.isPending}
    >
      {invoice.status} {toggleStatus.isPending && '...'}
    </button>
  )
}
```

## Simple useState Optimistic Pattern

For cases without TanStack Query:

```typescript
'use client'
import { useState, useOptimistic } from 'react'

// React 19 useOptimistic hook
export function InvoiceList({ initialInvoices }: { initialInvoices: Invoice[] }) {
  const [invoices, setInvoices] = useState(initialInvoices)
  const [optimisticInvoices, setOptimisticInvoices] = useOptimistic(invoices)

  async function handleDelete(invoiceId: string) {
    // Optimistically remove
    setOptimisticInvoices(prev => prev.filter(inv => inv.id !== invoiceId))
    
    try {
      await deleteInvoice(invoiceId)
      setInvoices(prev => prev.filter(inv => inv.id !== invoiceId))
    } catch {
      // useOptimistic automatically rolls back when the function resolves
      // The setInvoices call above didn't happen, so optimistic state reverts
    }
  }

  return (
    <ul>
      {optimisticInvoices.map(invoice => (
        <li key={invoice.id}>
          {invoice.customer_name}
          <button onClick={() => handleDelete(invoice.id)}>Delete</button>
        </li>
      ))}
    </ul>
  )
}
```

## Delete with Undo (Toast + Optimistic)

A common pattern: optimistically remove, show "Undo" toast, then actually delete after toast dismisses:

```typescript
'use client'
import { useState } from 'react'
import { toast } from 'sonner'

export function useDeleteWithUndo<T extends { id: string }>(
  items: T[],
  onDelete: (id: string) => Promise<void>
) {
  const [optimisticItems, setOptimisticItems] = useState(items)

  async function deleteWithUndo(id: string) {
    const deletedItem = optimisticItems.find(i => i.id === id)
    if (!deletedItem) return

    // Optimistically remove
    setOptimisticItems(prev => prev.filter(i => i.id !== id))

    let undone = false
    
    toast('Item deleted', {
      action: {
        label: 'Undo',
        onClick: () => {
          undone = true
          setOptimisticItems(prev => [...prev, deletedItem])
        },
      },
      duration: 5000,
      onDismiss: async () => {
        if (!undone) {
          try {
            await onDelete(id)
          } catch {
            // Server delete failed — restore item
            setOptimisticItems(prev => [...prev, deletedItem])
            toast.error('Delete failed')
          }
        }
      },
    })
  }

  return { optimisticItems, deleteWithUndo }
}
```

## When NOT to Use Optimistic Updates

- Operations that frequently fail validation (creating an invoice with invalid data)
- Irreversible operations without confirmation (permanent deletion without undo)
- Operations where the server might return different data than expected (ID generation, calculated fields)
- Low-frequency operations where the UX benefit doesn't justify the complexity
