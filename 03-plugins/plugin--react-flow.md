# Plugin: @xyflow/react (React Flow)

## What It Does

React Flow renders interactive node-based diagrams — flowcharts, pipelines, canvas editors. Used in `manage-worker-bee` for the blueprint canvas.

## Basic Setup

```typescript
'use client'
import ReactFlow, {
  Node,
  Edge,
  useNodesState,
  useEdgesState,
  Controls,
  Background,
  MiniMap,
} from '@xyflow/react'
import '@xyflow/react/dist/style.css'  // required CSS import

const initialNodes: Node[] = [
  { id: '1', position: { x: 0, y: 0 }, data: { label: 'Start' } },
  { id: '2', position: { x: 200, y: 0 }, data: { label: 'End' } },
]

const initialEdges: Edge[] = [
  { id: 'e1-2', source: '1', target: '2' },
]

export function BlueprintCanvas() {
  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes)
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges)
  
  return (
    <div style={{ width: '100%', height: '600px' }}>
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        fitView
      >
        <Controls />
        <Background />
        <MiniMap />
      </ReactFlow>
    </div>
  )
}
```

The parent container MUST have explicit dimensions. ReactFlow takes 100% of its container.

## Custom Node Types

```typescript
import { Handle, Position, NodeProps } from '@xyflow/react'

interface ServiceNodeData {
  label: string
  status: 'active' | 'inactive'
}

function ServiceNode({ data, selected }: NodeProps<ServiceNodeData>) {
  return (
    <div className={`border rounded p-3 ${selected ? 'border-blue-500' : 'border-gray-300'}`}>
      <Handle type="target" position={Position.Left} />
      <div className="font-medium">{data.label}</div>
      <div className={`text-sm ${data.status === 'active' ? 'text-green-500' : 'text-gray-400'}`}>
        {data.status}
      </div>
      <Handle type="source" position={Position.Right} />
    </div>
  )
}

// Register custom node types
const nodeTypes = { service: ServiceNode }

<ReactFlow nodeTypes={nodeTypes} ... />
```

Custom node types must be defined OUTSIDE the component function to prevent unnecessary re-renders.

## Edge Connection Handler

```typescript
import { addEdge, Connection } from '@xyflow/react'

const onConnect = useCallback(
  (params: Connection) => setEdges(eds => addEdge(params, eds)),
  [setEdges]
)

<ReactFlow onConnect={onConnect} ... />
```

## Saving Canvas State

```typescript
import { useReactFlow } from '@xyflow/react'

function SaveButton() {
  const { getNodes, getEdges } = useReactFlow()
  
  const save = async () => {
    const nodes = getNodes()
    const edges = getEdges()
    
    await fetch('/api/blueprints/save', {
      method: 'POST',
      body: JSON.stringify({ nodes, edges }),
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  return <button onClick={save}>Save</button>
}
```

The `useReactFlow` hook must be used inside a `ReactFlowProvider` context.

## Layout Algorithms

React Flow doesn't include automatic layout. For hierarchical layouts, use dagre:

```typescript
import dagre from 'dagre'

function getLayoutedElements(nodes: Node[], edges: Edge[]) {
  const dagreGraph = new dagre.graphlib.Graph()
  dagreGraph.setDefaultEdgeLabel(() => ({}))
  dagreGraph.setGraph({ rankdir: 'LR' })
  
  nodes.forEach(node => {
    dagreGraph.setNode(node.id, { width: 150, height: 50 })
  })
  
  edges.forEach(edge => {
    dagreGraph.setEdge(edge.source, edge.target)
  })
  
  dagre.layout(dagreGraph)
  
  return nodes.map(node => {
    const nodeWithPosition = dagreGraph.node(node.id)
    return {
      ...node,
      position: {
        x: nodeWithPosition.x - 75,
        y: nodeWithPosition.y - 25,
      }
    }
  })
}
```

## manage-worker-bee Data Model

In manage-worker-bee, the blueprint data structure is:

```typescript
interface Blueprint {
  currentBranch: string
  branches: Record<string, {
    nodes: Node[]
    edges: Edge[]
    updatedAt: string
  }>
  summary: string
}
```

The store (`lib/blueprintStore.ts`) handles reading/writing this to Supabase Storage and legacy migration from the flat `{nodes, edges}` format.

## Performance Considerations

- Define `nodeTypes` and `edgeTypes` outside component (prevents re-registration on every render)
- Use `memo` for custom node components if the canvas has 100+ nodes
- Set `proOptions={{ hideAttribution: true }}` only with a valid Pro license
- `fitView` causes a layout recalculation — avoid calling it repeatedly
