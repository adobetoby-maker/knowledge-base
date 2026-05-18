# Pattern: Tree View Component

## Overview

Hierarchical tree view for file explorers, category pickers, org charts, or nested navigation. Key requirements: expand/collapse, keyboard navigation, optional multi-select, and lazy-loading deep branches.

## Data Model

```ts
interface TreeNode {
  id: string
  label: string
  icon?: React.ReactNode
  children?: TreeNode[]  // undefined = leaf node; [] = empty folder
  isLoading?: boolean    // for lazy-loaded branches
}
```

## Core Implementation

```tsx
function TreeView({
  nodes,
  selectedId,
  onSelect,
  onExpand,
}: {
  nodes: TreeNode[]
  selectedId?: string
  onSelect: (id: string) => void
  onExpand?: (id: string) => void
}) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set())

  function toggle(id: string) {
    setExpanded(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else {
        next.add(id)
        onExpand?.(id)
      }
      return next
    })
  }

  return (
    <ul role="tree" className="space-y-0.5">
      {nodes.map(node => (
        <TreeNodeItem
          key={node.id}
          node={node}
          depth={0}
          expanded={expanded}
          selectedId={selectedId}
          onSelect={onSelect}
          onToggle={toggle}
        />
      ))}
    </ul>
  )
}

function TreeNodeItem({ node, depth, expanded, selectedId, onSelect, onToggle }) {
  const isExpanded = expanded.has(node.id)
  const isSelected = node.id === selectedId
  const hasChildren = node.children !== undefined
  const indent = depth * 16

  return (
    <li role="treeitem" aria-expanded={hasChildren ? isExpanded : undefined}>
      <div
        style={{ paddingLeft: indent }}
        className={`flex items-center gap-1 py-1 px-2 rounded cursor-pointer text-sm
          ${isSelected ? 'bg-blue-100 text-blue-800' : 'hover:bg-gray-100'}`}
        onClick={() => {
          onSelect(node.id)
          if (hasChildren) onToggle(node.id)
        }}
      >
        {hasChildren ? (
          <span className="w-4 text-gray-400 shrink-0">
            {node.isLoading ? '⋯' : isExpanded ? '▾' : '▸'}
          </span>
        ) : (
          <span className="w-4 shrink-0" />
        )}
        {node.icon && <span className="shrink-0">{node.icon}</span>}
        <span className="truncate">{node.label}</span>
      </div>
      {hasChildren && isExpanded && !node.isLoading && (
        <ul role="group">
          {node.children!.map(child => (
            <TreeNodeItem
              key={child.id}
              node={child}
              depth={depth + 1}
              expanded={expanded}
              selectedId={selectedId}
              onSelect={onSelect}
              onToggle={onToggle}
            />
          ))}
        </ul>
      )}
    </li>
  )
}
```

## Keyboard Navigation

```tsx
function handleKeyDown(e: React.KeyboardEvent, node: TreeNode) {
  switch (e.key) {
    case 'Enter':
    case ' ':
      onSelect(node.id)
      break
    case 'ArrowRight':
      if (!expanded.has(node.id)) onToggle(node.id)
      break
    case 'ArrowLeft':
      if (expanded.has(node.id)) onToggle(node.id)
      break
    case 'ArrowDown':
      // Focus next visible node
      break
    case 'ArrowUp':
      // Focus previous visible node
      break
  }
}
```

## Lazy-Load Deep Branches

```tsx
async function handleExpand(nodeId: string) {
  if (loadedNodes.has(nodeId)) return  // Already loaded

  // Mark as loading
  updateNode(nodeId, { isLoading: true })

  const children = await fetchChildren(nodeId)
  updateNode(nodeId, { children, isLoading: false })
  loadedNodes.add(nodeId)
}
```

## Key Rules

- `role="tree"`, `role="treeitem"`, `role="group"` are the correct ARIA roles.
- Only load children when first expanded — don't prefetch the whole tree.
- `truncate` class prevents long labels from breaking layout.
- Use consistent `id` format so path reconstruction is possible (file explorer breadcrumbs need to know the full path to a selected node).
- For file trees specifically: distinguish between files (leaf, click to open) and folders (branch, click to expand).
