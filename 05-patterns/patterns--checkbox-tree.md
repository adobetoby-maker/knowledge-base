# Pattern: Checkbox Tree with Parent/Child State

## Overview

A tree of checkboxes where parent state reflects children: all checked → checked, none checked → unchecked, some checked → indeterminate. The indeterminate state is a visual-only state (not a form submission value) that must be set via the DOM property, not an attribute — `element.indeterminate = true`, not `<input indeterminate="true">`.

## Data Model

```ts
interface TreeNode {
  id: string
  label: string
  children?: TreeNode[]
}

type CheckState = 'checked' | 'unchecked' | 'indeterminate'

// Derive check state for a parent from its children's states
function getParentState(children: TreeNode[], checked: Set<string>): CheckState {
  const childIds = children.map((c) => c.id)
  const checkedCount = childIds.filter((id) => checked.has(id)).length
  if (checkedCount === 0) return 'unchecked'
  if (checkedCount === childIds.length) return 'checked'
  return 'indeterminate'
}
```

## Indeterminate State via useRef

```tsx
function CheckboxTreeItem({ node, checked, onChange }: {
  node: TreeNode
  checked: Set<string>
  onChange: (id: string, newChecked: boolean, children?: string[]) => void
}) {
  const inputRef = useRef<HTMLInputElement>(null)
  const isLeaf = !node.children || node.children.length === 0

  const state: CheckState = isLeaf
    ? (checked.has(node.id) ? 'checked' : 'unchecked')
    : getParentState(node.children!, checked)

  useEffect(() => {
    if (inputRef.current) {
      inputRef.current.checked = state === 'checked'
      // indeterminate is a DOM property, not an HTML attribute
      inputRef.current.indeterminate = state === 'indeterminate'
    }
  }, [state])

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    if (isLeaf) {
      onChange(node.id, e.target.checked)
    } else {
      // Check/uncheck all children
      const childIds = node.children!.map((c) => c.id)
      onChange(node.id, e.target.checked, childIds)
    }
  }

  return (
    <li role="treeitem" aria-expanded={!isLeaf ? state !== 'unchecked' : undefined}>
      <label className="flex items-center gap-2">
        <input
          ref={inputRef}
          type="checkbox"
          onChange={handleChange}
          aria-checked={state === 'indeterminate' ? 'mixed' : state === 'checked'}
        />
        {node.label}
      </label>
      {node.children && (
        <ul role="group">
          {node.children.map((child) => (
            <CheckboxTreeItem
              key={child.id}
              node={child}
              checked={checked}
              onChange={onChange}
            />
          ))}
        </ul>
      )}
    </li>
  )
}
```

`aria-checked="mixed"` is the ARIA value for indeterminate — not `"indeterminate"`.

## State Management

```tsx
function useCheckboxTree(nodes: TreeNode[]) {
  const [checked, setChecked] = useState<Set<string>>(new Set())

  function handleChange(id: string, isChecked: boolean, childIds?: string[]) {
    setChecked((prev) => {
      const next = new Set(prev)
      if (childIds) {
        // Parent toggled — apply to all children
        childIds.forEach((cid) => isChecked ? next.add(cid) : next.delete(cid))
      } else {
        isChecked ? next.add(id) : next.delete(id)
      }
      return next
    })
  }

  return { checked, handleChange }
}
```

Parent nodes are not in the `checked` Set — their state is derived from children. This keeps state minimal: only leaf selections are stored. Deriving parent state is O(n) per render but avoids synchronization bugs where parent and child states drift.

## Keyboard Navigation

Use `role="tree"` on the root, `role="treeitem"` on each item, and handle keyboard:

```tsx
function handleKeyDown(e: React.KeyboardEvent, node: TreeNode) {
  switch (e.key) {
    case 'ArrowDown': // Focus next visible item
    case 'ArrowUp':   // Focus previous visible item
    case 'ArrowRight': // Expand if collapsed, or move to first child
    case 'ArrowLeft':  // Collapse if expanded, or move to parent
    case ' ':          // Toggle check state
    case 'Enter':      // Toggle check state
      e.preventDefault()
      // ... implement focus movement
  }
}
```

Space and Enter should both toggle. Arrow keys navigate without changing checked state.

## Key Rules

- Set `indeterminate` via `element.indeterminate = true` (DOM property), not as an HTML attribute — the attribute does nothing.
- Use `aria-checked="mixed"` for indeterminate, not `aria-checked="indeterminate"`.
- Store only leaf check states; derive parent states. Storing parent states separately leads to sync bugs.
- Toggling a parent checks/unchecks all its direct and indirect descendants, not just direct children.
- `role="tree"` → `role="treeitem"` → `role="group"` is the correct ARIA hierarchy.
- A three-level tree (grandparent/parent/child) should handle grandparent indeterminate correctly: indeterminate if some but not all grandchildren across all children are checked.
