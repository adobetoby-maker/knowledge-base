# Pattern: File Tree / Nested Navigation

## What This Solves

Recursive tree structures — file browsers, category trees, org charts, nested menus — need a component that can render any depth without knowing the depth at compile time. The tricky parts are: expand/collapse state management, keyboard navigation, and loading children on demand.

## Data Shape

```ts
interface TreeNode {
  id: string
  label: string
  icon?: React.ComponentType<{ className?: string }>
  children?: TreeNode[]   // undefined = leaf, [] = empty folder
  metadata?: Record<string, unknown>
}
```

## Component

```tsx
// components/FileTree.tsx
'use client'
import { useState, useCallback } from 'react'
import { ChevronRight, Folder, FolderOpen, File } from 'lucide-react'
import { cn } from '@/lib/utils'

interface FileTreeProps {
  nodes: TreeNode[]
  onSelect?: (node: TreeNode) => void
  selectedId?: string
  defaultExpanded?: string[]
}

function TreeItem({
  node,
  depth,
  onSelect,
  selectedId,
  expanded,
  onToggle,
}: {
  node: TreeNode
  depth: number
  onSelect?: (node: TreeNode) => void
  selectedId?: string
  expanded: Set<string>
  onToggle: (id: string) => void
}) {
  const isFolder = Array.isArray(node.children)
  const isExpanded = expanded.has(node.id)
  const isSelected = node.id === selectedId

  const handleClick = () => {
    if (isFolder) onToggle(node.id)
    onSelect?.(node)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      handleClick()
    }
  }

  const Icon = node.icon ?? (isFolder ? (isExpanded ? FolderOpen : Folder) : File)

  return (
    <li role="treeitem" aria-expanded={isFolder ? isExpanded : undefined}>
      <button
        className={cn(
          'flex w-full items-center gap-1.5 rounded-sm px-2 py-1.5 text-sm hover:bg-muted/50 transition-colors',
          isSelected && 'bg-muted font-medium'
        )}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
        onClick={handleClick}
        onKeyDown={handleKeyDown}
      >
        {isFolder && (
          <ChevronRight
            className={cn('h-3 w-3 text-muted-foreground transition-transform shrink-0', isExpanded && 'rotate-90')}
          />
        )}
        {!isFolder && <span className="w-3 shrink-0" />}
        <Icon className="h-4 w-4 shrink-0 text-muted-foreground" />
        <span className="truncate">{node.label}</span>
      </button>

      {isFolder && isExpanded && node.children && node.children.length > 0 && (
        <ul role="group">
          {node.children.map(child => (
            <TreeItem
              key={child.id}
              node={child}
              depth={depth + 1}
              onSelect={onSelect}
              selectedId={selectedId}
              expanded={expanded}
              onToggle={onToggle}
            />
          ))}
        </ul>
      )}
    </li>
  )
}

export function FileTree({ nodes, onSelect, selectedId, defaultExpanded = [] }: FileTreeProps) {
  const [expanded, setExpanded] = useState<Set<string>>(new Set(defaultExpanded))

  const onToggle = useCallback((id: string) => {
    setExpanded(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }, [])

  return (
    <ul role="tree" className="space-y-0.5">
      {nodes.map(node => (
        <TreeItem
          key={node.id}
          node={node}
          depth={0}
          onSelect={onSelect}
          selectedId={selectedId}
          expanded={expanded}
          onToggle={onToggle}
        />
      ))}
    </ul>
  )
}
```

## Lazy Loading Children

For large trees where children are fetched on expand:

```tsx
function LazyTreeItem({ node, ...props }) {
  const [children, setChildren] = useState<TreeNode[] | null>(null)
  const [loading, setLoading] = useState(false)

  const handleToggle = async () => {
    if (!isExpanded && children === null) {
      setLoading(true)
      const data = await fetchChildren(node.id)
      setChildren(data)
      setLoading(false)
    }
    onToggle(node.id)
  }

  // Render spinner while loading
}
```

## Search / Filter

To filter tree nodes by search query:

```ts
function filterTree(nodes: TreeNode[], query: string): TreeNode[] {
  return nodes.reduce<TreeNode[]>((acc, node) => {
    const matches = node.label.toLowerCase().includes(query.toLowerCase())
    const filteredChildren = node.children ? filterTree(node.children, query) : undefined

    if (matches || (filteredChildren && filteredChildren.length > 0)) {
      acc.push({ ...node, children: filteredChildren })
    }
    return acc
  }, [])
}
```

After filtering, expand all nodes so matching children are visible.

## Database: Adjacency List

```sql
CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid REFERENCES categories(id),  -- NULL = root
  name text NOT NULL,
  sort_order integer DEFAULT 0
);

-- Fetch full tree recursively
WITH RECURSIVE tree AS (
  SELECT id, parent_id, name, sort_order, 0 AS depth
  FROM categories WHERE parent_id IS NULL
  UNION ALL
  SELECT c.id, c.parent_id, c.name, c.sort_order, tree.depth + 1
  FROM categories c JOIN tree ON c.parent_id = tree.id
)
SELECT * FROM tree ORDER BY depth, sort_order;
```

Convert the flat result to nested TreeNode[] with a single pass using a Map.
