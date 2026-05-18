# Pattern: Bulk Delete Selected Items

## Overview

Bulk delete has three phases: selection (checkboxes + select all), confirmation (modal showing count), and execution (API calls + feedback). The tricky parts are: "select all" across paginated data (current page vs. all pages), partial failure handling, and undoable delete via soft-delete + toast.

## Selection State

```ts
type SelectionState = {
  selectedIds: Set<string>
  allOnPageSelected: boolean
  allAcrossAllPagesSelected: boolean  // "select all 1,247 items"
}
```

Two levels of "select all" exist when data is paginated. Selecting all on the current page is always available. Selecting all across all pages requires a server-side operation (the client doesn't have all IDs).

## Selection Hook

```tsx
function useSelection(items: { id: string }[], totalCount: number) {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [selectAll, setSelectAll] = useState(false)  // true = server-side "all"

  const pageIds = items.map((i) => i.id)
  const allOnPageSelected = pageIds.length > 0 && pageIds.every((id) => selectedIds.has(id))

  function toggleItem(id: string) {
    setSelectAll(false)
    setSelectedIds((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function togglePageSelection() {
    if (allOnPageSelected) {
      setSelectedIds((prev) => {
        const next = new Set(prev)
        pageIds.forEach((id) => next.delete(id))
        return next
      })
    } else {
      setSelectedIds((prev) => new Set([...prev, ...pageIds]))
    }
  }

  function selectAllItems() {
    setSelectAll(true)
    setSelectedIds(new Set(pageIds))  // Visually select current page
  }

  function clearSelection() {
    setSelectedIds(new Set())
    setSelectAll(false)
  }

  return {
    selectedIds,
    selectedCount: selectAll ? totalCount : selectedIds.size,
    allOnPageSelected,
    selectAll,
    toggleItem,
    togglePageSelection,
    selectAllItems,
    clearSelection,
  }
}
```

## Bulk Action Bar

Shows when something is selected, with "Delete X items" action:

```tsx
function BulkActionBar({ selectedCount, onDelete, onClearSelection }: {
  selectedCount: number
  onDelete: () => void
  onClearSelection: () => void
}) {
  if (selectedCount === 0) return null

  return (
    <div
      role="toolbar"
      aria-label="Bulk actions"
      className="flex items-center gap-3 px-4 py-2 bg-blue-50 border-b"
    >
      <span className="text-sm font-medium">
        {selectedCount} item{selectedCount !== 1 ? 's' : ''} selected
      </span>
      <button
        type="button"
        onClick={onDelete}
        className="text-sm text-red-600 font-medium hover:text-red-800"
      >
        Delete {selectedCount} item{selectedCount !== 1 ? 's' : ''}
      </button>
      <button
        type="button"
        onClick={onClearSelection}
        className="text-sm text-gray-500 ml-auto"
      >
        Clear selection
      </button>
    </div>
  )
}
```

## Confirmation Modal

The modal must repeat the count so users know what they're confirming:

```tsx
function BulkDeleteConfirmModal({ count, onConfirm, onCancel }: {
  count: number
  onConfirm: () => void
  onCancel: () => void
}) {
  return (
    <Dialog open onOpenChange={(v) => !v && onCancel()}>
      <DialogContent>
        <DialogTitle>Delete {count} item{count !== 1 ? 's' : ''}?</DialogTitle>
        <DialogDescription>
          This will permanently delete {count} item{count !== 1 ? 's' : ''}. This cannot be undone.
        </DialogDescription>
        <div className="flex gap-2 justify-end mt-4">
          <button type="button" onClick={onCancel}>Cancel</button>
          <button type="button" onClick={onConfirm} className="bg-red-600 text-white px-4 py-2 rounded">
            Delete {count} item{count !== 1 ? 's' : ''}
          </button>
        </div>
      </DialogContent>
    </Dialog>
  )
}
```

## Execution with Partial Failure Handling

```tsx
async function executeBulkDelete(ids: string[], selectAll: boolean) {
  try {
    if (selectAll) {
      // Server deletes everything matching current filters
      await api.bulkDeleteAll({ filters: currentFilters })
      toast.success('All items deleted')
    } else {
      const result = await api.bulkDelete({ ids: [...ids] })
      const { deleted, failed } = result

      if (failed.length === 0) {
        toast.success(`${deleted} item${deleted !== 1 ? 's' : ''} deleted`)
      } else {
        toast.warning(
          `${deleted} deleted, ${failed.length} failed. ` +
          `Failed items have been deselected.`
        )
        // Keep failed items selected so user can retry
        setSelectedIds(new Set(failed))
        return
      }
    }
    clearSelection()
    refetchItems()
  } catch {
    toast.error('Delete failed. Please try again.')
  }
}
```

On partial failure: show how many succeeded and how many failed. Keep the failed items selected so the user can retry just those or investigate. Don't silently succeed on the partial set.

## Key Rules

- Distinguish between "select all on this page" and "select all N items across all pages" — the latter requires a server-side delete.
- The confirmation modal must show the exact count being deleted, not just "Delete selected?".
- On partial failure, keep failed items selected so users can retry, and clearly report the split (X deleted, Y failed).
- The bulk action bar should vanish when selection count drops to zero.
- Use `role="toolbar"` with `aria-label` on the action bar for screen readers.
- Don't start the delete without confirmation — even for small counts. Accidental bulk deletes are very hard to recover from.
