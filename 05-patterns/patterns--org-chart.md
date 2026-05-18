# Pattern: Org Chart / Reporting Hierarchy

## What This Solves

An organizational chart visualizes reporting relationships as a tree. The challenges are: laying out a tree without overlapping nodes, handling variable depths (a CEO with 50 direct reports vs a 10-level deep hierarchy), expand/collapse subtrees, search with highlight, and performance when the org has thousands of people.

## React Flow for Org Charts

React Flow (`@xyflow/react`) handles: auto-layout, pan/zoom, edge rendering, and custom node types. Use it over hand-rolled SVG unless the org chart is purely decorative.

```bash
npm i @xyflow/react dagre
```

Auto-layout with `dagre`:

```ts
// lib/org-layout.ts
import dagre from 'dagre'
import type { Node, Edge } from '@xyflow/react'

export function applyOrgLayout(nodes: Node[], edges: Edge[]): Node[] {
  const g = new dagre.graphlib.Graph()
  g.setGraph({ rankdir: 'TB', nodesep: 80, ranksep: 60 })
  g.setDefaultEdgeLabel(() => ({}))

  const NODE_WIDTH = 220
  const NODE_HEIGHT = 80

  nodes.forEach(node => g.setNode(node.id, { width: NODE_WIDTH, height: NODE_HEIGHT }))
  edges.forEach(edge => g.setEdge(edge.source, edge.target))

  dagre.layout(g)

  return nodes.map(node => {
    const pos = g.node(node.id)
    return {
      ...node,
      position: {
        x: pos.x - NODE_WIDTH / 2,
        y: pos.y - NODE_HEIGHT / 2,
      },
    }
  })
}
```

## Custom Person Node

```tsx
import { Handle, Position, type NodeProps } from '@xyflow/react'

interface PersonData {
  name: string
  title: string
  department: string
  avatar_url?: string
  isHighlighted?: boolean
  isCollapsed?: boolean
  childCount?: number
  onToggleCollapse?: (id: string) => void
}

export function PersonNode({ id, data }: NodeProps<PersonData>) {
  return (
    <div className={cn(
      'bg-background border-2 rounded-xl px-4 py-3 w-[220px] shadow-sm',
      data.isHighlighted ? 'border-primary bg-primary/5' : 'border-border',
    )}>
      <Handle type="target" position={Position.Top} className="!bg-border" />

      <div className="flex items-center gap-3">
        <UserAvatar user={{ id, name: data.name, avatar_url: data.avatar_url }} size="md" />
        <div className="flex-1 min-w-0">
          <p className="font-medium text-sm truncate">{data.name}</p>
          <p className="text-xs text-muted-foreground truncate">{data.title}</p>
        </div>
      </div>

      {data.childCount && data.childCount > 0 && (
        <button
          onClick={() => data.onToggleCollapse?.(id)}
          className="mt-2 w-full text-xs text-center text-muted-foreground hover:text-foreground border-t pt-2"
        >
          {data.isCollapsed
            ? `Show ${data.childCount} report${data.childCount === 1 ? '' : 's'}`
            : 'Collapse'}
        </button>
      )}

      <Handle type="source" position={Position.Bottom} className="!bg-border" />
    </div>
  )
}
```

## Expand/Collapse Subtrees

Rather than removing nodes from the React Flow nodes array (which resets positions), mark them hidden:

```tsx
function toggleCollapse(nodeId: string) {
  const descendants = getDescendants(nodeId, edges)

  setNodes(prev => prev.map(node =>
    descendants.has(node.id)
      ? { ...node, hidden: !node.hidden }
      : node
  ))
  setEdges(prev => prev.map(edge =>
    descendants.has(edge.target)
      ? { ...edge, hidden: !edge.hidden }
      : edge
  ))
}

function getDescendants(nodeId: string, edges: Edge[]): Set<string> {
  const result = new Set<string>()
  const queue = [nodeId]
  while (queue.length) {
    const current = queue.shift()!
    edges.forEach(e => {
      if (e.source === current && !result.has(e.target)) {
        result.add(e.target)
        queue.push(e.target)
      }
    })
  }
  return result
}
```

## Search and Highlight

```tsx
function searchAndHighlight(query: string) {
  const lowerQuery = query.toLowerCase()
  setNodes(prev => prev.map(node => ({
    ...node,
    data: {
      ...node.data,
      isHighlighted: query.length > 0 &&
        (node.data.name.toLowerCase().includes(lowerQuery) ||
         node.data.title.toLowerCase().includes(lowerQuery)),
    },
  })))

  // Fit view to show highlighted nodes
  const matches = nodes.filter(n => n.data.isHighlighted)
  if (matches.length && reactFlowInstance) {
    reactFlowInstance.fitView({ nodes: matches, padding: 0.3, duration: 400 })
  }
}
```

## Large Organizations (Virtual Rendering)

For orgs with 500+ people, React Flow's built-in viewport culling handles most cases — nodes outside the viewport are not rendered. If performance is still poor:

1. Start the tree collapsed to root + direct reports only
2. Load children on-demand when expanding a node (fetch from API)
3. Use React Flow's `nodeTypes` to memoize node renders with `React.memo`

```tsx
const nodeTypes = useMemo(() => ({
  person: PersonNode,
}), [])  // Stable reference prevents all nodes re-rendering
```

## Key Rules

- Use dagre for layout — manual positioning of org trees is a maintenance nightmare
- Mark nodes `hidden` for collapse/expand rather than removing them from the array — preserves positions
- Memoize `nodeTypes` and `edgeTypes` with `useMemo` — unstable references cause full re-renders on every state change
- Load children lazily on expand for orgs > 200 people
- Highlight search matches by setting node data, not by adding/removing nodes — keep the stable node array
- Always call `fitView` after initial layout so the chart is visible in the viewport
