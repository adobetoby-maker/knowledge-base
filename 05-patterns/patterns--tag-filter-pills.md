# Pattern: Tag Filter Pills

## Overview
Tag filter pills are a multi-select filtering mechanism that must communicate selection state at a glance, stay in sync with the URL so filters survive refresh and can be shared, and show match counts so users understand the effect of each selection before committing to it. Single-select behavior (where clicking one tag deselects others) destroys utility for users with complex filtering needs — always use multi-select.

## Implementation

### URL State Sync
```tsx
import { useSearchParams } from 'react-router-dom' // or Next.js useRouter + useSearchParams

function useTagFilter() {
  const [searchParams, setSearchParams] = useSearchParams()

  const activeTags = searchParams.get('tags')?.split(',').filter(Boolean) ?? []

  const toggleTag = (tag: string) => {
    const next = activeTags.includes(tag)
      ? activeTags.filter((t) => t !== tag)
      : [...activeTags, tag]

    setSearchParams(
      (prev) => {
        const updated = new URLSearchParams(prev)
        if (next.length > 0) {
          updated.set('tags', next.join(','))
        } else {
          updated.delete('tags')
        }
        return updated
      },
      { replace: true } // don't push history entry on every tag click
    )
  }

  const clearAll = () =>
    setSearchParams((prev) => {
      const updated = new URLSearchParams(prev)
      updated.delete('tags')
      return updated
    }, { replace: true })

  return { activeTags, toggleTag, clearAll }
}
```

### Match Count Computation
```tsx
// Compute counts before rendering — don't recalculate inside each pill
function computeTagCounts(items: Item[], allTags: string[]): Record<string, number> {
  return Object.fromEntries(
    allTags.map((tag) => [
      tag,
      items.filter((item) => item.tags.includes(tag)).length,
    ])
  )
}

// Filtered results — union logic: item matches if it has ANY active tag
function filterItems(items: Item[], activeTags: string[]): Item[] {
  if (activeTags.length === 0) return items
  return items.filter((item) =>
    activeTags.some((tag) => item.tags.includes(tag))
  )
}
```

### Pill Component
```tsx
function TagPill({
  tag,
  count,
  active,
  onToggle,
}: {
  tag: string
  count: number
  active: boolean
  onToggle: (tag: string) => void
}) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={active}
      aria-label={`Filter by ${tag}, ${count} matches`}
      onClick={() => onToggle(tag)}
      className={[
        'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-sm border transition-colors',
        active
          ? 'bg-blue-600 border-blue-600 text-white'
          : 'bg-white border-gray-300 text-gray-700 hover:border-blue-400',
      ].join(' ')}
    >
      <span>{tag}</span>
      <span
        className={[
          'text-xs rounded-full px-1.5 py-0.5',
          active ? 'bg-blue-500 text-white' : 'bg-gray-100 text-gray-500',
        ].join(' ')}
        aria-hidden="true"
      >
        {count}
      </span>
      {active && (
        <span aria-hidden="true" className="ml-0.5">×</span>
      )}
    </button>
  )
}
```

### Full Filter Bar
```tsx
function TagFilterBar({ items, allTags }: { items: Item[]; allTags: string[] }) {
  const { activeTags, toggleTag, clearAll } = useTagFilter()
  const counts = computeTagCounts(items, allTags)
  const filtered = filterItems(items, activeTags)

  return (
    <div>
      <div
        role="group"
        aria-label="Filter by tag"
        className="flex flex-wrap gap-2 items-center"
      >
        {allTags.map((tag) => (
          <TagPill
            key={tag}
            tag={tag}
            count={counts[tag] ?? 0}
            active={activeTags.includes(tag)}
            onToggle={toggleTag}
          />
        ))}
        {activeTags.length > 0 && (
          <button
            type="button"
            onClick={clearAll}
            className="text-sm text-gray-500 underline hover:text-gray-800"
          >
            Clear all
          </button>
        )}
      </div>

      {filtered.length === 0 && activeTags.length > 0 && (
        <div role="status" className="mt-8 text-center text-gray-500">
          No results match the selected tags.
          <button onClick={clearAll} className="ml-2 underline">
            Clear filters
          </button>
        </div>
      )}
    </div>
  )
}
```

## Key Rules
- Use URL query params (`?tags=a,b`) — filters must survive page refresh and be shareable via link
- Use `replace: true` when updating URL on tag toggle — you don't want 20 history entries from filtering
- Multi-select is non-negotiable; single-select forces users to lose context and restart filtering
- Show count badges on each tag before the user clicks — zero-count tags mean the filter will empty results
- "Clear all" button appears only when at least one tag is active — never show it for an unused state
- Empty state message must include a "Clear filters" action, not just text
- Counts should reflect the current filtered set if stacking filters — OR logic means count = items matching that tag regardless of other active tags; AND logic means count = items matching that tag AND all current active tags
- Use `role="checkbox"` + `aria-checked` on pill buttons — they are toggles, not links or plain buttons
