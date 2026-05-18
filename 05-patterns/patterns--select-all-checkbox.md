# Pattern: Select-All Checkbox with Indeterminate State

## Overview

A "select all" checkbox in a table or list has three visual states: unchecked (none selected), checked (all selected), and indeterminate (some selected). The indeterminate state is purely visual — it must be set imperatively via a DOM ref because it is not an HTML attribute. Get this wrong and users think they've selected all when they've only selected some.

## Core Implementation

```tsx
import { useRef, useEffect } from 'react'

type SelectAllProps = {
  rows: string[]          // all row IDs
  selected: Set<string>   // currently selected IDs
  onChange: (next: Set<string>) => void
}

export function SelectAllCheckbox({ rows, selected, onChange }: SelectAllProps) {
  const ref = useRef<HTMLInputElement>(null)

  const allSelected = rows.length > 0 && selected.size === rows.length
  const someSelected = selected.size > 0 && !allSelected

  // indeterminate is write-only — can't be set via JSX prop
  useEffect(() => {
    if (ref.current) {
      ref.current.indeterminate = someSelected
    }
  }, [someSelected])

  function handleChange() {
    if (allSelected || someSelected) {
      onChange(new Set())
    } else {
      onChange(new Set(rows))
    }
  }

  return (
    <input
      ref={ref}
      type="checkbox"
      checked={allSelected}
      onChange={handleChange}
      aria-label={
        allSelected ? 'Deselect all rows'
        : someSelected ? 'Select all rows (some selected)'
        : 'Select all rows'
      }
    />
  )
}
```

**Why `ref.current.indeterminate` not a prop:** The HTML `indeterminate` property is not an HTML attribute — it exists only on the DOM `HTMLInputElement` object. React's JSX doesn't sync it. Setting it in a `useEffect` after each render is the correct pattern.

**Why toggle to none on indeterminate click:** Users expect clicking an indeterminate checkbox to either "select all" or "deselect all". "Select all" is more useful when the action is additive; "deselect all" is safer for destructive bulk operations. The convention for data tables (like Google Drive, Gmail) is: indeterminate → select all, checked → deselect all.

## Selecting Visible vs All Pages

When data is paginated, "select all" is ambiguous. Make it explicit:

```tsx
type BulkSelectState =
  | { mode: 'none' }
  | { mode: 'page'; ids: Set<string> }
  | { mode: 'all' }  // signals backend: apply to every record

function BulkSelectionBar({ pageIds, selected, onSelect }: Props) {
  const allPageSelected = pageIds.every(id => selected.has(id))

  return (
    <>
      <SelectAllCheckbox rows={pageIds} selected={selected} onChange={onSelect} />
      {allPageSelected && (
        <button onClick={() => onSelect({ mode: 'all' })}>
          Select all 1,204 items
        </button>
      )}
    </>
  )
}
```

Never silently select across pages — users don't expect destructive bulk actions to apply to records they can't see. Show the count, require an explicit extra click.

## Bulk Action Toolbar

Appear when any rows are selected. Disappear on deselect. Don't displace table headers — overlay or animate in from below:

```tsx
function BulkActionBar({ count, onDelete, onExport }: Props) {
  if (count === 0) return null

  return (
    <div
      role="toolbar"
      aria-label={`${count} item${count !== 1 ? 's' : ''} selected`}
      className="bulk-action-bar"
    >
      <span>{count} selected</span>
      <button onClick={onExport}>Export</button>
      <button onClick={onDelete} className="destructive">Delete</button>
    </div>
  )
}
```

Use `role="toolbar"` so screen readers announce the context. The `aria-label` should include the count so users know what's affected before acting.

## Keyboard Behavior

- Space on the checkbox cycles: none → all → none (standard checkbox)
- Shift+click on row checkboxes should range-select (like file explorers)

```tsx
function RowCheckbox({ id, index, selected, onToggle, onRangeSelect }: Props) {
  return (
    <input
      type="checkbox"
      checked={selected.has(id)}
      aria-label={`Select row ${index + 1}`}
      onChange={e => {
        if (e.nativeEvent instanceof MouseEvent && e.nativeEvent.shiftKey) {
          onRangeSelect(index)
        } else {
          onToggle(id)
        }
      }}
    />
  )
}
```

## Key Rules

- Set `indeterminate` via DOM ref in `useEffect` — it's a property, not an HTML attribute, JSX can't set it
- Include selected count in `aria-label` on bulk toolbar — screen readers need context before destructive actions
- Show a "select all N items" affordance when paginated — never silently act on off-page records
- Clicking indeterminate should select all (not deselect) — matches user expectation from Gmail/Drive
- Bulk action toolbar should not reflow the page — use overlay or sticky positioning
- Shift+click for range selection is expected behavior — implement it or users assume it's broken
