# Pattern: JSON Tree Viewer

## Overview

Render arbitrary JSON as an interactive collapsible tree. Used in API explorers, debug panels, and data inspection tools. Key challenge: unknown depth and mixed types — handle all JSON primitives and recursively nested structures.

## Core Implementation

```tsx
type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue }

interface JsonNodeProps {
  value: JsonValue
  name?: string
  depth?: number
  defaultExpanded?: boolean
}

function JsonNode({ value, name, depth = 0, defaultExpanded = depth < 2 }: JsonNodeProps) {
  const [expanded, setExpanded] = useState(defaultExpanded)

  const isExpandable = value !== null && typeof value === 'object'
  const indent = depth * 16

  if (!isExpandable) {
    return (
      <div style={{ paddingLeft: indent }} className="flex gap-1 text-sm font-mono">
        {name && <span className="text-purple-600">{name}: </span>}
        <JsonPrimitive value={value} />
      </div>
    )
  }

  const isArray = Array.isArray(value)
  const entries = isArray
    ? value.map((v, i) => [String(i), v] as [string, JsonValue])
    : Object.entries(value)
  const count = entries.length

  return (
    <div>
      <div
        style={{ paddingLeft: indent }}
        className="flex items-center gap-1 text-sm font-mono cursor-pointer hover:bg-gray-50 py-0.5 rounded"
        onClick={() => setExpanded(e => !e)}
      >
        <span className="text-gray-400 w-3">{expanded ? '▾' : '▸'}</span>
        {name && <span className="text-purple-600">{name}: </span>}
        <span className="text-gray-500">
          {isArray ? '[' : '{'}
          {!expanded && (
            <span className="text-gray-400 mx-1">{count} {count === 1 ? 'item' : 'items'}</span>
          )}
          {!expanded && (isArray ? ']' : '}')}
        </span>
      </div>
      {expanded && (
        <>
          {entries.map(([key, val]) => (
            <JsonNode
              key={key}
              name={isArray ? undefined : key}
              value={val}
              depth={depth + 1}
              defaultExpanded={depth + 1 < 2}
            />
          ))}
          <div style={{ paddingLeft: indent }} className="text-sm font-mono text-gray-500">
            {isArray ? ']' : '}'}
          </div>
        </>
      )}
    </div>
  )
}

function JsonPrimitive({ value }: { value: string | number | boolean | null }) {
  if (value === null) return <span className="text-gray-400">null</span>
  if (typeof value === 'boolean') return <span className="text-blue-600">{String(value)}</span>
  if (typeof value === 'number') return <span className="text-green-600">{value}</span>
  // String — truncate long values
  const display = value.length > 100 ? `${value.slice(0, 100)}…` : value
  return <span className="text-red-600">"{display}"</span>
}
```

## Search / Highlight

For API explorers, add path-based search:

```tsx
function searchJson(value: JsonValue, query: string, path: string[] = []): string[][] {
  const paths: string[][] = []
  if (value === null || typeof value !== 'object') {
    if (String(value).toLowerCase().includes(query.toLowerCase())) {
      paths.push(path)
    }
    return paths
  }
  const entries = Array.isArray(value)
    ? value.map((v, i) => [String(i), v] as [string, JsonValue])
    : Object.entries(value)

  for (const [key, val] of entries) {
    if (key.toLowerCase().includes(query.toLowerCase())) {
      paths.push([...path, key])
    }
    paths.push(...searchJson(val, query, [...path, key]))
  }
  return paths
}
```

Expand all ancestors of matched paths, highlight matched keys/values.

## Performance for Large Objects

For deeply nested or very large JSON (>1000 keys at root), virtualize the visible nodes:

```tsx
// Flatten the tree to a list of visible rows, then virtualize
type FlatNode = { path: string[]; key: string; value: JsonValue; depth: number; hasChildren: boolean }

function flatten(value: JsonValue, expanded: Set<string>, path: string[] = []): FlatNode[] {
  // ...recursively build flat list based on expanded set
}
```

This avoids mounting hundreds of nodes at once.

## Usage

```tsx
<JsonNode value={JSON.parse(apiResponse)} defaultExpanded={true} />
```

## Key Rules

- Default expand first 2 levels only — deep objects freeze the browser if all expanded at once.
- Color-code types: strings red, numbers green, booleans blue, null gray — standard expectation from developers.
- Show item count in collapsed state so users know what's inside before expanding.
- Long string values truncate at ~100 chars in collapsed view; full value on expand.
