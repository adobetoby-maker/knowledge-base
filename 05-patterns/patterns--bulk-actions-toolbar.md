# Pattern: Bulk Actions Toolbar

## What This Solves

When users select multiple items in a list or table, a contextual toolbar should appear to surface batch operations (delete, assign, export, archive). The challenge is: appearing and disappearing without layout shift, communicating selection count clearly, and handling the transition smoothly so users understand what's happening.

## Sticky Bottom Positioning

The toolbar sits at the bottom of the viewport, overlaying the list — it does not push content up. This is important: a toolbar that shifts the layout creates disorienting jumps as selection count changes.

```tsx
import { AnimatePresence, motion } from 'framer-motion'

interface BulkActionsToolbarProps {
  selectedIds: Set<string>
  onClearSelection: () => void
  onDelete: () => void
  onExport: () => void
  onAssign?: () => void
}

export function BulkActionsToolbar({
  selectedIds,
  onClearSelection,
  onDelete,
  onExport,
  onAssign,
}: BulkActionsToolbarProps) {
  const count = selectedIds.size

  return (
    <AnimatePresence>
      {count > 0 && (
        <motion.div
          initial={{ y: 80, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 80, opacity: 0 }}
          transition={{ type: 'spring', damping: 20, stiffness: 300 }}
          className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 w-full max-w-xl px-4"
        >
          <div className="bg-foreground text-background rounded-xl shadow-2xl px-4 py-3 flex items-center gap-3">
            {/* Count badge */}
            <div className="flex items-center gap-2 mr-auto">
              <span className="bg-background/20 text-background text-xs font-semibold rounded-md px-2 py-0.5">
                {count}
              </span>
              <span className="text-sm font-medium">
                {count === 1 ? 'item' : 'items'} selected
              </span>
            </div>

            {/* Actions */}
            {onAssign && (
              <button
                onClick={onAssign}
                className="text-sm text-background/80 hover:text-background transition-colors flex items-center gap-1.5"
              >
                <UserPlusIcon className="h-4 w-4" />
                Assign
              </button>
            )}

            <button
              onClick={onExport}
              className="text-sm text-background/80 hover:text-background transition-colors flex items-center gap-1.5"
            >
              <DownloadIcon className="h-4 w-4" />
              Export
            </button>

            <button
              onClick={onDelete}
              className="text-sm text-red-400 hover:text-red-300 transition-colors flex items-center gap-1.5"
            >
              <TrashIcon className="h-4 w-4" />
              Delete
            </button>

            {/* Divider + deselect */}
            <div className="w-px h-4 bg-background/20" />
            <button
              onClick={onClearSelection}
              aria-label="Clear selection"
              className="text-background/60 hover:text-background transition-colors"
            >
              <XIcon className="h-4 w-4" />
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
```

## Selection State Management

Keep selection as a `Set<string>` of IDs, not an array — O(1) membership checks:

```tsx
const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())

function toggleSelect(id: string) {
  setSelectedIds(prev => {
    const next = new Set(prev)
    if (next.has(id)) next.delete(id); else next.add(id)
    return next
  })
}

function selectAll() {
  setSelectedIds(new Set(items.map(i => i.id)))
}

function clearSelection() {
  setSelectedIds(new Set())
}
```

Clear selection after a bulk action completes (or fails — the user should re-select for retry):

```tsx
async function handleBulkDelete() {
  await deleteMany(Array.from(selectedIds))
  clearSelection()
  refetch()
}
```

## Deselect All Button

The X button in the toolbar closes the toolbar. This is distinct from an "Undo" action. Make it obvious: it clears selection, not the action that was just performed.

## Animation Entering/Leaving

Use a spring animation for enter (feels snappy and intentional) and a simple ease for exit (fast dismiss is less jarring). `AnimatePresence` handles unmounting after the exit animation completes:

```tsx
initial={{ y: 80, opacity: 0 }}
animate={{ y: 0, opacity: 1 }}
exit={{ y: 80, opacity: 0 }}
transition={{ type: 'spring', damping: 20, stiffness: 300 }}
```

## Destructive Action Confirmation

Bulk delete should confirm before executing. Use an inline confirmation within the toolbar rather than a modal — modals over a toolbar are visually noisy:

```tsx
const [confirmingDelete, setConfirmingDelete] = useState(false)

// In the toolbar:
{confirmingDelete ? (
  <>
    <span className="text-sm text-red-400">Delete {count} items?</span>
    <button onClick={handleBulkDelete} className="text-sm text-red-300 font-medium">
      Confirm
    </button>
    <button onClick={() => setConfirmingDelete(false)} className="text-sm text-background/60">
      Cancel
    </button>
  </>
) : (
  <button onClick={() => setConfirmingDelete(true)} className="text-sm text-red-400">
    Delete
  </button>
)}
```

## Key Rules

- Use `fixed bottom` positioning — never push content up with `sticky` or absolute positioning
- Store selection as `Set<string>` — Set membership checks are O(1) vs O(n) for arrays
- Clear selection after any bulk action completes, regardless of success or failure
- Animate the toolbar entrance with a spring; keep the exit fast (200ms or less)
- Confirm destructive bulk actions inline in the toolbar, not in a modal
- The X button clears selection — label it "Clear selection" for screen readers
