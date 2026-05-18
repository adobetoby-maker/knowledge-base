# Pattern: Confirm Before Delete

## Overview

Destructive actions need confirmation. The approach determines the UX cost: a modal adds friction for every delete (acceptable for rare, high-stakes deletes), an inline confirm expander adds friction but less so (good for medium-risk), and undo-instead-of-confirm (soft delete + toast with undo) is the best experience for frequent low-stakes deletes.

## Approach 1: Modal Confirmation

```tsx
import { useState } from 'react'
import * as Dialog from '@radix-ui/react-dialog'

interface DeleteModalProps {
  itemName: string
  onConfirm: () => Promise<void>
}

export function DeleteModal({ itemName, onConfirm }: DeleteModalProps) {
  const [open, setOpen] = useState(false)
  const [loading, setLoading] = useState(false)

  async function handleConfirm() {
    setLoading(true)
    try {
      await onConfirm()
      setOpen(false)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Trigger asChild>
        <button className="text-red-600 hover:text-red-700 text-sm">Delete</button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 bg-black/50" />
        <Dialog.Content className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-lg p-6 w-full max-w-sm shadow-lg">
          <Dialog.Title className="text-lg font-semibold mb-2">Delete {itemName}?</Dialog.Title>
          <Dialog.Description className="text-gray-600 text-sm mb-6">
            This action cannot be undone.
          </Dialog.Description>
          <div className="flex justify-end gap-3">
            <Dialog.Close asChild>
              <button className="px-4 py-2 border rounded-md text-sm">Cancel</button>
            </Dialog.Close>
            <button
              onClick={handleConfirm}
              disabled={loading}
              className="px-4 py-2 bg-red-600 text-white rounded-md text-sm hover:bg-red-700 disabled:opacity-50"
            >
              {loading ? 'Deleting...' : 'Delete'}
            </button>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
```

## Approach 2: Inline Confirm Expander

```tsx
function InlineDeleteButton({ onDelete }: { onDelete: () => void }) {
  const [confirming, setConfirming] = useState(false)

  if (confirming) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm text-gray-600">Delete?</span>
        <button
          onClick={onDelete}
          className="text-red-600 text-sm font-medium hover:underline"
          autoFocus
        >
          Yes
        </button>
        <button
          onClick={() => setConfirming(false)}
          className="text-gray-500 text-sm hover:underline"
        >
          No
        </button>
      </div>
    )
  }

  return (
    <button
      onClick={() => setConfirming(true)}
      className="text-gray-400 hover:text-red-600 transition-colors"
    >
      <TrashIcon className="w-4 h-4" />
    </button>
  )
}
```

## Approach 3: Soft Delete with Undo Toast (Best UX)

```tsx
// Soft-delete in DB, show undo for 5 seconds, then hard-delete via job
async function deleteItem(id: string) {
  // Mark as deleted (hidden from UI immediately)
  await db.update(items).set({ deletedAt: new Date() }).where(eq(items.id, id))
}

async function undoDelete(id: string) {
  await db.update(items).set({ deletedAt: null }).where(eq(items.id, id))
}

// In component
function ItemRow({ item }: { item: Item }) {
  const { toast } = useToast()

  async function handleDelete() {
    await deleteItem(item.id)  // Immediate soft-delete

    toast({
      title: `"${item.name}" deleted`,
      action: (
        <button
          onClick={async () => {
            await undoDelete(item.id)
            // Invalidate/refetch to show item again
          }}
          className="font-medium underline"
        >
          Undo
        </button>
      ),
      duration: 5000,
    })
  }

  return (
    <div className="flex items-center justify-between p-3">
      <span>{item.name}</span>
      <button onClick={handleDelete} className="text-gray-400 hover:text-red-600">
        <TrashIcon className="w-4 h-4" />
      </button>
    </div>
  )
}
```

## Type-to-Confirm (High-Stakes Deletes)

For deleting accounts, workspaces, or production resources:

```tsx
function TypeToConfirmModal({ resourceName, onConfirm }: { resourceName: string; onConfirm: () => void }) {
  const [input, setInput] = useState('')
  const confirmed = input === resourceName

  return (
    <Dialog.Content ...>
      <p className="text-sm mb-2">
        Type <strong>{resourceName}</strong> to confirm deletion:
      </p>
      <input
        value={input}
        onChange={(e) => setInput(e.target.value)}
        className="input w-full mb-4"
        placeholder={resourceName}
      />
      <button
        onClick={onConfirm}
        disabled={!confirmed}
        className="btn-destructive w-full disabled:opacity-50"
      >
        Delete {resourceName}
      </button>
    </Dialog.Content>
  )
}
```

## Key Rules

- Modal confirmation is best for rare, high-stakes deletes (workspace, account, production data). For everyday list item deletes, use undo-on-toast instead.
- Undo pattern requires soft delete: `deleted_at` column. A background job does the physical delete after the undo window (typically 30 days).
- `autoFocus` on the "Yes" button in inline confirm means pressing Enter after clicking the trash icon confirms immediately — add a brief delay or skip `autoFocus` if this is too risky.
- Type-to-confirm is appropriate when the item name is meaningful (repo name, org name) — don't use it for unnamed items with IDs.
- The Cancel/No button must always be accessible and not require extra interaction — never make "cancel" harder than "confirm".
