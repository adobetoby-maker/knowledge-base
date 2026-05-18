# Pattern: Table with Inline Cell Editing

## Overview

An editable table lets users edit cell values in place — double-click to enter edit mode, Tab to move to the next cell, Enter to confirm, Escape to cancel. This is denser and faster than row-level edit modals for bulk data entry. The key technical challenge is managing a "currently editing cell" pointer while keeping all other cells read-only and navigable by keyboard.

## Editing State

```ts
interface CellCoord {
  rowId: string
  columnKey: string
}

// Draft values stored separately from committed data
// so Escape can discard without mutating the source
type DraftValues = Record<string, Record<string, string>> // rowId → columnKey → draft
```

## Table Component

```tsx
function EditableTable<T extends { id: string }>({
  rows,
  columns,
  onCellChange,
}: {
  rows: T[]
  columns: { key: keyof T & string; label: string; editable?: boolean }[]
  onCellChange: (rowId: string, key: string, value: string) => void
}) {
  const [editing, setEditing] = useState<CellCoord | null>(null)
  const [drafts, setDrafts] = useState<DraftValues>({})

  function startEdit(rowId: string, columnKey: string) {
    setEditing({ rowId, columnKey })
  }

  function commitEdit() {
    if (!editing) return
    const value = drafts[editing.rowId]?.[editing.columnKey]
    if (value !== undefined) {
      onCellChange(editing.rowId, editing.columnKey, value)
    }
    setEditing(null)
  }

  function cancelEdit() {
    if (!editing) return
    // Remove draft — don't commit
    setDrafts((prev) => {
      const next = { ...prev }
      if (next[editing.rowId]) {
        const row = { ...next[editing.rowId] }
        delete row[editing.columnKey]
        next[editing.rowId] = row
      }
      return next
    })
    setEditing(null)
  }

  function moveToNextCell(rowId: string, columnKey: string) {
    commitEdit()  // Save current before moving
    const colIdx = columns.findIndex((c) => c.key === columnKey)
    const rowIdx = rows.findIndex((r) => r.id === rowId)
    // Move right across editable columns
    for (let c = colIdx + 1; c < columns.length; c++) {
      if (columns[c].editable !== false) {
        setEditing({ rowId, columnKey: columns[c].key })
        return
      }
    }
    // Wrap to first editable col of next row
    if (rowIdx + 1 < rows.length) {
      const firstEditable = columns.find((c) => c.editable !== false)
      if (firstEditable) setEditing({ rowId: rows[rowIdx + 1].id, columnKey: firstEditable.key })
    }
  }

  return (
    <table>
      <thead>
        <tr>{columns.map((c) => <th key={c.key}>{c.label}</th>)}</tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={row.id}>
            {columns.map((col) => (
              <EditableCell
                key={col.key}
                value={String(row[col.key] ?? '')}
                draftValue={drafts[row.id]?.[col.key]}
                isEditing={editing?.rowId === row.id && editing?.columnKey === col.key}
                editable={col.editable !== false}
                onDoubleClick={() => startEdit(row.id, col.key)}
                onChange={(v) => setDrafts((prev) => ({
                  ...prev,
                  [row.id]: { ...prev[row.id], [col.key]: v }
                }))}
                onCommit={commitEdit}
                onCancel={cancelEdit}
                onTabNext={() => moveToNextCell(row.id, col.key)}
              />
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

## Editable Cell

```tsx
function EditableCell({ value, draftValue, isEditing, editable, onDoubleClick, onChange, onCommit, onCancel, onTabNext }: {
  value: string
  draftValue?: string
  isEditing: boolean
  editable: boolean
  onDoubleClick: () => void
  onChange: (v: string) => void
  onCommit: () => void
  onCancel: () => void
  onTabNext: () => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const displayValue = draftValue ?? value

  useEffect(() => {
    if (isEditing) inputRef.current?.focus()
  }, [isEditing])

  if (!editable) {
    return <td className="px-3 py-2 text-sm">{value}</td>
  }

  return (
    <td
      onDoubleClick={onDoubleClick}
      className={`px-1 py-1 ${isEditing ? '' : 'cursor-default hover:bg-gray-50'}`}
      aria-selected={isEditing}
    >
      {isEditing ? (
        <input
          ref={inputRef}
          value={displayValue}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') { e.preventDefault(); onCommit() }
            if (e.key === 'Escape') { e.preventDefault(); onCancel() }
            if (e.key === 'Tab') { e.preventDefault(); onTabNext() }
          }}
          onBlur={onCommit}
          className="w-full px-2 py-1 border rounded text-sm outline-2 outline-blue-500"
        />
      ) : (
        <span className="block px-2 py-1 text-sm min-w-8">{displayValue || <>&nbsp;</>}</span>
      )}
    </td>
  )
}
```

## Batch Save Button

Instead of saving each cell on blur, collect all changes in `drafts` and save with one button:

```tsx
function BatchSaveButton({ drafts, onSave, onDiscard }: {
  drafts: DraftValues
  onSave: () => void
  onDiscard: () => void
}) {
  const changeCount = Object.values(drafts).reduce((sum, row) => sum + Object.keys(row).length, 0)
  if (changeCount === 0) return null

  return (
    <div role="status" className="flex items-center gap-2 mt-2">
      <span className="text-sm text-gray-600">{changeCount} unsaved change{changeCount !== 1 ? 's' : ''}</span>
      <button type="button" onClick={onSave} className="text-sm font-medium text-blue-600">Save</button>
      <button type="button" onClick={onDiscard} className="text-sm text-gray-500">Discard</button>
    </div>
  )
}
```

## Key Rules

- Store draft values separately from committed values so Escape can always discard without mutation.
- Tab should commit the current cell and move to the next editable cell (not native tab behavior).
- `onBlur` should commit — clicking outside a cell should save it, not leave dangling edits.
- Empty cells need a minimum width (`min-w-8`) and a non-breaking space to remain clickable.
- Double-click is the standard trigger for inline edit — single click is for selection in data tables.
- For bulk edits, offer a "Save N changes" button as an explicit commit point rather than auto-saving on every blur.
