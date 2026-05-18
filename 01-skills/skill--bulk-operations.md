# Skill: Bulk Operations

## What This Covers

Multi-select + apply action to many rows: bulk delete, bulk status change, bulk export, bulk assign. Standard pattern for admin dashboards and data management UIs.

## Selection State

```ts
// Selection is pure UI state — useState, not TanStack Query
const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())

function toggleSelect(id: string) {
  setSelectedIds((prev) => {
    const next = new Set(prev)
    next.has(id) ? next.delete(id) : next.add(id)
    return next
  })
}

function selectAll(ids: string[]) {
  setSelectedIds(new Set(ids))
}

function clearSelection() {
  setSelectedIds(new Set())
}

const isSelected = (id: string) => selectedIds.has(id)
const selectionCount = selectedIds.size
```

`Set` is O(1) for add/has/delete. `Array.includes` is O(n) — use Set for selections.

## Selection Column in Table

```tsx
function DataTable({ rows }: { rows: Row[] }) {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const allIds = rows.map((r) => r.id)
  const allSelected = allIds.length > 0 && allIds.every((id) => selectedIds.has(id))

  return (
    <table>
      <thead>
        <tr>
          <th>
            <input
              type="checkbox"
              checked={allSelected}
              onChange={() => allSelected ? clearSelection() : selectAll(allIds)}
              aria-label="Select all"
            />
          </th>
          {/* other headers */}
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr
            key={row.id}
            className={selectedIds.has(row.id) ? 'bg-blue-50' : ''}
          >
            <td>
              <input
                type="checkbox"
                checked={selectedIds.has(row.id)}
                onChange={() => toggleSelect(row.id)}
                aria-label={`Select ${row.name}`}
              />
            </td>
            {/* other cells */}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

## Bulk Action Bar

Show only when items are selected:

```tsx
{selectionCount > 0 && (
  <div className="flex items-center gap-4 px-4 py-2 bg-blue-50 border-b">
    <span className="text-sm font-medium">
      {selectionCount} item{selectionCount !== 1 ? 's' : ''} selected
    </span>
    <button onClick={handleBulkDelete} className="text-sm text-red-600">
      Delete
    </button>
    <button onClick={handleBulkExport} className="text-sm text-gray-700">
      Export
    </button>
    <button onClick={clearSelection} className="ml-auto text-sm text-gray-500">
      Clear selection
    </button>
  </div>
)}
```

## Bulk Server Action

```ts
// app/actions/bulk.ts
'use server'
import { revalidatePath } from 'next/cache'
import { createServerActionClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { z } from 'zod'

const schema = z.object({
  ids: z.array(z.string().uuid()).min(1).max(100),  // Cap to prevent abuse
})

export async function bulkDeleteInvoices(formData: FormData) {
  const raw = JSON.parse(formData.get('ids') as string)
  const { ids } = schema.parse(raw)

  const supabase = createServerActionClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')

  const { error } = await supabase
    .from('invoices')
    .delete()
    .in('id', ids)
    .eq('user_id', user.id)  // RLS also enforces this, but be explicit

  if (error) throw new Error(error.message)

  revalidatePath('/admin/invoices')
}

export async function bulkUpdateStatus(ids: string[], status: string) {
  const supabase = createServerActionClient({ cookies })
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')

  await supabase
    .from('invoices')
    .update({ status, updated_at: new Date().toISOString() })
    .in('id', ids)
    .eq('user_id', user.id)

  revalidatePath('/admin/invoices')
}
```

Always limit the max IDs (100 is reasonable). Without a cap, a malicious user could trigger a query with tens of thousands of IDs.

## Bulk with Progress Feedback

For long-running bulk operations (emails, PDF generation):

```tsx
function BulkEmailButton({ selectedIds }: { selectedIds: string[] }) {
  const [progress, setProgress] = useState<{ done: number; total: number } | null>(null)
  const [errors, setErrors] = useState<string[]>([])

  async function handleSend() {
    setProgress({ done: 0, total: selectedIds.length })
    const errs: string[] = []

    // Process in batches of 10 to avoid timeouts
    const batches = chunk(selectedIds, 10)
    for (const batch of batches) {
      const result = await fetch('/api/invoices/bulk-email', {
        method: 'POST',
        body: JSON.stringify({ ids: batch }),
      }).then((r) => r.json())

      if (result.errors) errs.push(...result.errors)
      setProgress((prev) => prev ? { ...prev, done: prev.done + batch.length } : null)
    }

    setErrors(errs)
    setProgress(null)
  }

  return (
    <div>
      <button onClick={handleSend} disabled={!!progress}>
        {progress ? `Sending ${progress.done}/${progress.total}...` : 'Send all'}
      </button>
      {errors.length > 0 && (
        <p className="text-red-600 text-sm">{errors.length} emails failed</p>
      )}
    </div>
  )
}

function chunk<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = []
  for (let i = 0; i < arr.length; i += size) chunks.push(arr.slice(i, i + size))
  return chunks
}
```

## Confirmation Before Destructive Bulk Actions

```tsx
async function handleBulkDelete() {
  const count = selectedIds.size
  const confirmed = window.confirm(
    `Delete ${count} invoice${count !== 1 ? 's' : ''}? This cannot be undone.`
  )
  if (!confirmed) return

  await bulkDeleteInvoices(Array.from(selectedIds))
  clearSelection()
}
```

Or use a proper `ConfirmDialog` component (see `patterns--confirm-dialog.md`) for better UX.

## After Bulk Action

Always call `clearSelection()` after a bulk action completes — selected items may no longer exist.
