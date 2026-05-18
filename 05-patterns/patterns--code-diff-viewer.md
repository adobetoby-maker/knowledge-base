# Pattern: Code Diff Viewer

## Overview

Side-by-side or inline diff display for showing changes between two versions of code or text. Used in: code review tools, version history, AI-generated suggestions, content editing.

## Library Options

| Library | Bundle | Features | Use When |
|---------|--------|----------|----------|
| `diff` (npm) | Small | Text diff algorithm only | You want to render it yourself |
| `react-diff-viewer-continued` | Medium | Full component, side-by-side | Quick integration needed |
| `monaco-editor` | Large | Full VS Code diff editor | IDE-like experience |

For most use cases: use `diff` for the algorithm + custom render.

## Custom Diff Renderer

```ts
// lib/diff.ts
import { diffWords, diffLines, Change } from 'diff'

interface DiffResult {
  type: 'added' | 'removed' | 'unchanged'
  value: string
}

export function computeWordDiff(before: string, after: string): DiffResult[] {
  return diffWords(before, after).map((change): DiffResult => ({
    type: change.added ? 'added' : change.removed ? 'removed' : 'unchanged',
    value: change.value,
  }))
}

export function computeLineDiff(before: string, after: string): DiffResult[] {
  return diffLines(before, after).map((change): DiffResult => ({
    type: change.added ? 'added' : change.removed ? 'removed' : 'unchanged',
    value: change.value,
  }))
}
```

## Inline Word Diff

```tsx
import { computeWordDiff } from '@/lib/diff'

export function InlineWordDiff({ before, after }: { before: string; after: string }) {
  const changes = computeWordDiff(before, after)

  return (
    <p className="text-sm leading-relaxed">
      {changes.map((change, i) => (
        <span
          key={i}
          className={
            change.type === 'added' ? 'bg-green-100 text-green-800 rounded px-0.5' :
            change.type === 'removed' ? 'bg-red-100 text-red-700 line-through rounded px-0.5' :
            undefined
          }
        >
          {change.value}
        </span>
      ))}
    </p>
  )
}
```

## Side-by-Side Line Diff

```tsx
import { computeLineDiff } from '@/lib/diff'

interface LinePair {
  before?: string
  after?: string
  type: 'added' | 'removed' | 'unchanged'
}

function buildSideBySidePairs(before: string, after: string): LinePair[] {
  const changes = computeLineDiff(before, after)
  const pairs: LinePair[] = []

  let removedBuffer: string[] = []

  for (const change of changes) {
    const lines = change.value.split('\n').filter((_, i, arr) => i < arr.length - 1 || arr[i] !== '')

    if (change.type === 'removed') {
      removedBuffer.push(...lines.map((l) => l))
    } else if (change.type === 'added') {
      const addedLines = lines
      const maxLen = Math.max(removedBuffer.length, addedLines.length)
      for (let i = 0; i < maxLen; i++) {
        pairs.push({
          before: removedBuffer[i],
          after: addedLines[i],
          type: 'unchanged',
        })
      }
      removedBuffer = []
    } else {
      if (removedBuffer.length) {
        removedBuffer.forEach((line) => pairs.push({ before: line, type: 'removed' }))
        removedBuffer = []
      }
      lines.forEach((line) => pairs.push({ before: line, after: line, type: 'unchanged' }))
    }
  }

  removedBuffer.forEach((line) => pairs.push({ before: line, type: 'removed' }))
  return pairs
}

export function SideBySideDiff({ before, after }: { before: string; after: string }) {
  const pairs = buildSideBySidePairs(before, after)

  return (
    <div className="font-mono text-sm grid grid-cols-2 border rounded-lg overflow-hidden">
      <div className="border-r">
        <div className="px-3 py-1 bg-gray-100 text-gray-500 text-xs font-sans border-b">Before</div>
        {pairs.map((pair, i) => (
          <div key={i} className={`px-3 py-0.5 ${pair.before !== pair.after && pair.before ? 'bg-red-50' : ''}`}>
            <span className={pair.before !== pair.after && pair.before ? 'text-red-800' : 'text-gray-700'}>
              {pair.before ?? ''}
            </span>
          </div>
        ))}
      </div>
      <div>
        <div className="px-3 py-1 bg-gray-100 text-gray-500 text-xs font-sans border-b">After</div>
        {pairs.map((pair, i) => (
          <div key={i} className={`px-3 py-0.5 ${pair.before !== pair.after && pair.after ? 'bg-green-50' : ''}`}>
            <span className={pair.before !== pair.after && pair.after ? 'text-green-800' : 'text-gray-700'}>
              {pair.after ?? ''}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}
```

## Diff Stats

```tsx
function DiffStats({ before, after }: { before: string; after: string }) {
  const changes = computeLineDiff(before, after)
  const added = changes.filter((c) => c.type === 'added').length
  const removed = changes.filter((c) => c.type === 'removed').length

  return (
    <div className="flex gap-3 text-sm font-mono">
      <span className="text-green-600">+{added}</span>
      <span className="text-red-600">-{removed}</span>
    </div>
  )
}
```

## Collapsing Unchanged Lines

For large files, collapse unchanged lines to show only the context around changes:

```ts
const CONTEXT_LINES = 3

function collapseUnchanged(pairs: LinePair[]): (LinePair | { type: 'collapsed'; count: number })[] {
  const result = []
  let unchangedRun = 0
  let runStart = -1

  for (let i = 0; i < pairs.length; i++) {
    if (pairs[i].type === 'unchanged') {
      unchangedRun++
      if (runStart === -1) runStart = i
    } else {
      if (unchangedRun > CONTEXT_LINES * 2) {
        result.push(...pairs.slice(runStart, runStart + CONTEXT_LINES))
        result.push({ type: 'collapsed', count: unchangedRun - CONTEXT_LINES * 2 })
        result.push(...pairs.slice(i - CONTEXT_LINES, i))
      } else if (unchangedRun > 0) {
        result.push(...pairs.slice(runStart, i))
      }
      result.push(pairs[i])
      unchangedRun = 0
      runStart = -1
    }
  }
  return result
}
```
