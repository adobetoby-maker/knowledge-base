# Pattern: Hierarchical Filter

## Overview
Hierarchical filters (parent/child categories) let users drill into taxonomy while maintaining awareness of structure. The indeterminate parent state is critical UX — a parent checkbox that appears unchecked when some children are selected causes users to think they haven't filtered at all. Applying filters immediately (no "Apply" button) reduces the interaction cost from three clicks to one.

## Implementation

### Data Model
```tsx
interface FilterNode {
  id: string
  label: string
  count: number
  children?: FilterNode[]
}

// Selection state: a flat Set of checked IDs
// Indeterminate state is derived, not stored
type FilterSelection = Set<string>
```

### Selection Logic
```tsx
function getAllChildIds(node: FilterNode): string[] {
  if (!node.children?.length) return [node.id]
  return [node.id, ...node.children.flatMap(getAllChildIds)]
}

function getLeafIds(node: FilterNode): string[] {
  if (!node.children?.length) return [node.id]
  return node.children.flatMap(getLeafIds)
}

function isIndeterminate(node: FilterNode, selected: FilterSelection): boolean {
  if (!node.children?.length) return false
  const leafIds = getLeafIds(node)
  const selectedLeaves = leafIds.filter((id) => selected.has(id))
  return selectedLeaves.length > 0 && selectedLeaves.length < leafIds.length
}

function isChecked(node: FilterNode, selected: FilterSelection): boolean {
  const leafIds = getLeafIds(node)
  return leafIds.length > 0 && leafIds.every((id) => selected.has(id))
}

function toggleNode(
  node: FilterNode,
  selected: FilterSelection
): FilterSelection {
  const next = new Set(selected)
  const leafIds = getLeafIds(node)
  const allChecked = isChecked(node, selected)

  if (allChecked) {
    // Uncheck all children
    leafIds.forEach((id) => next.delete(id))
  } else {
    // Check all children
    leafIds.forEach((id) => next.add(id))
  }

  return next
}
```

### Indeterminate Checkbox (DOM ref required)
```tsx
function IndeterminateCheckbox({
  checked,
  indeterminate,
  onChange,
  label,
}: {
  checked: boolean
  indeterminate: boolean
  onChange: () => void
  label: string
}) {
  const ref = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (ref.current) {
      ref.current.indeterminate = indeterminate
    }
  }, [indeterminate])

  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <input
        ref={ref}
        type="checkbox"
        checked={checked}
        onChange={onChange}
        className="w-4 h-4 rounded"
        aria-label={label}
      />
      <span>{label}</span>
    </label>
  )
}
```

### Recursive Filter Node
```tsx
function FilterTreeNode({
  node,
  selected,
  onToggle,
  depth = 0,
}: {
  node: FilterNode
  selected: FilterSelection
  onToggle: (node: FilterNode) => void
  depth?: number
}) {
  const [expanded, setExpanded] = useState(true)
  const checked = isChecked(node, selected)
  const indeterminate = isIndeterminate(node, selected)
  const hasChildren = !!node.children?.length

  return (
    <div>
      <div
        className="flex items-center gap-1 py-1"
        style={{ paddingLeft: `${depth * 16}px` }}
      >
        {hasChildren && (
          <button
            type="button"
            aria-expanded={expanded}
            onClick={() => setExpanded(!expanded)}
            className="w-4 h-4 text-gray-400"
            aria-label={expanded ? 'Collapse' : 'Expand'}
          >
            {expanded ? '▾' : '▸'}
          </button>
        )}
        <IndeterminateCheckbox
          checked={checked}
          indeterminate={indeterminate}
          onChange={() => onToggle(node)}
          label={`${node.label} (${node.count})`}
        />
        <span className="text-xs text-gray-400 ml-auto">{node.count}</span>
      </div>

      {hasChildren && expanded && (
        <div>
          {node.children!.map((child) => (
            <FilterTreeNode
              key={child.id}
              node={child}
              selected={selected}
              onToggle={onToggle}
              depth={depth + 1}
            />
          ))}
        </div>
      )}
    </div>
  )
}
```

### Filter Panel
```tsx
function HierarchicalFilter({
  tree,
  selected,
  onChange,
}: {
  tree: FilterNode[]
  selected: FilterSelection
  onChange: (next: FilterSelection) => void
}) {
  const handleToggle = (node: FilterNode) => {
    onChange(toggleNode(node, selected))
  }

  const hasAny = selected.size > 0

  return (
    <div>
      <div className="flex items-center justify-between mb-2">
        <span className="text-sm font-medium">Filter</span>
        {hasAny && (
          <button
            type="button"
            onClick={() => onChange(new Set())}
            className="text-xs text-blue-600 hover:underline"
          >
            Reset
          </button>
        )}
      </div>
      {tree.map((node) => (
        <FilterTreeNode
          key={node.id}
          node={node}
          selected={selected}
          onToggle={handleToggle}
        />
      ))}
    </div>
  )
}
```

## Key Rules
- Indeterminate state is derived (not stored) — compute it from selected leaf IDs every render
- `input.indeterminate = true` must be set via a DOM ref; it is not a React-controlled prop
- Checking a parent checks ALL its leaf descendants; unchecking a parent unchecks all leaf descendants
- Unchecking one child makes the parent indeterminate — never leave the parent fully checked when a child is deselected
- "Select all" / "Reset" applies per parent, not per child level — put it next to each collapsible parent header
- Apply filters immediately on change — no "Apply" button; use debounce if the filter operation is expensive
- Show count in brackets next to each option so users know how many items match before clicking
- Counts should reflect the full dataset, not the currently filtered subset (avoids confusion when counts change as filters are added)
