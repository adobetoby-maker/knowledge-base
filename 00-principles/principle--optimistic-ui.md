# Principle: Optimistic UI

## The Problem

Server round-trips introduce visible latency. Clicking "mark as paid" triggers a spinner, a network request, a database write, a cache invalidation, and a re-render — typically 200–800ms of perceived waiting. For operations with high confidence of success, this wait is unnecessary friction.

## The Principle

Apply the update to the local UI immediately, send the server request in the background, and roll back if the request fails. The user experience improves because the UI responds instantly; the cost is handling the (rare) failure case.

## When Optimistic UI Is Appropriate

**Good candidates:**
- Toggle operations (like/unlike, mark read, favorite, enable/disable)
- Status changes (mark as paid, mark complete)
- Sorting/reordering (drag to reorder, move to category)
- Adding items to a list when duplicates are unlikely

**Poor candidates:**
- Financial operations (payment processing, refunds)
- Operations that change access or permissions
- Multi-step workflows where partial completion is complex to undo
- Operations where the server frequently rejects (conditional writes)

## With TanStack Query

```ts
const queryClient = useQueryClient()

const { mutate: toggleFavorite } = useMutation({
  mutationFn: ({ id, favorited }: { id: string; favorited: boolean }) =>
    updateInvoiceFavorite(id, favorited),

  // Called immediately, before the server request
  onMutate: async ({ id, favorited }) => {
    // Cancel any outgoing refetches
    await queryClient.cancelQueries({ queryKey: ['invoices'] })

    // Snapshot current state for rollback
    const previousInvoices = queryClient.getQueryData<Invoice[]>(['invoices'])

    // Apply optimistic update
    queryClient.setQueryData<Invoice[]>(['invoices'], prev =>
      prev?.map(inv => inv.id === id ? { ...inv, is_favorite: favorited } : inv) ?? []
    )

    return { previousInvoices }  // Returned as context for onError
  },

  // If server rejects, roll back
  onError: (err, variables, context) => {
    if (context?.previousInvoices) {
      queryClient.setQueryData(['invoices'], context.previousInvoices)
    }
    toast.error('Failed to update — please try again')
  },

  // Always re-sync with server after mutation (success or error)
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['invoices'] })
  },
})
```

## Visual Feedback During Optimistic State

The optimistic state should be visually distinguishable while the request is in flight:

```tsx
function FavoriteButton({ invoice }: { invoice: Invoice }) {
  const { mutate: toggleFavorite, isPending } = useFavoriteToggle()

  return (
    <button
      onClick={() => toggleFavorite({ id: invoice.id, favorited: !invoice.is_favorite })}
      disabled={isPending}
      className={cn(
        'transition-opacity',
        isPending && 'opacity-60'  // Dim while pending
      )}
    >
      <Star
        className={cn(
          'h-4 w-4 transition-colors',
          invoice.is_favorite ? 'fill-amber-400 text-amber-400' : 'text-muted-foreground'
        )}
      />
    </button>
  )
}
```

## Optimistic Reordering (Drag and Drop)

```ts
const { mutate: reorder } = useMutation({
  mutationFn: (newOrder: string[]) => saveOrder(newOrder),

  onMutate: (newOrder) => {
    const prev = queryClient.getQueryData<Item[]>(['items'])

    // Apply new order immediately
    queryClient.setQueryData<Item[]>(['items'], old =>
      newOrder.map(id => old!.find(item => item.id === id)!)
    )

    return { prev }
  },

  onError: (_, __, context) => {
    queryClient.setQueryData(['items'], context?.prev)
    toast.error('Could not save the new order')
  },
})
```

## The Invariant

The server is the source of truth. Optimistic updates are a UX shortcut, not a replacement for server validation. The `onSettled` re-sync ensures that after every mutation (success or failure), the local cache reflects the server's actual state.

Never skip `onSettled` — without it, a temporarily-successful optimistic update that later fails silently leaves the UI in a permanently wrong state.
