# Pattern: Virtual List (Windowed Rendering)

## What This Solves

Rendering 1000+ rows in a list causes severe performance degradation — each DOM node consumes memory and layout time. Virtualization renders only the visible rows plus a small overscan buffer, keeping the DOM lean regardless of dataset size. Use this whenever a list might exceed ~200 items.

## TanStack Virtual (Recommended)

```tsx
// components/VirtualList.tsx
'use client'
import { useVirtualizer } from '@tanstack/react-virtual'
import { useRef } from 'react'

interface VirtualListProps<T> {
  items: T[]
  estimateSize?: number
  renderItem: (item: T, index: number) => React.ReactNode
  className?: string
}

export function VirtualList<T>({
  items,
  estimateSize = 56,
  renderItem,
  className,
}: VirtualListProps<T>) {
  const parentRef = useRef<HTMLDivElement>(null)

  const rowVirtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => estimateSize,
    overscan: 5,
  })

  return (
    <div
      ref={parentRef}
      className={className}
      style={{ overflow: 'auto' }}
    >
      {/* Total height spacer — creates scrollbar proportioned to full list */}
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
        {rowVirtualizer.getVirtualItems().map(virtualRow => (
          <div
            key={virtualRow.index}
            data-index={virtualRow.index}
            ref={rowVirtualizer.measureElement}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              transform: `translateY(${virtualRow.start}px)`,
            }}
          >
            {renderItem(items[virtualRow.index], virtualRow.index)}
          </div>
        ))}
      </div>
    </div>
  )
}
```

Usage:
```tsx
<VirtualList
  items={invoices}
  estimateSize={64}
  className="h-[600px] border rounded-lg"
  renderItem={(invoice) => (
    <div className="flex items-center px-4 py-3 border-b hover:bg-muted/50">
      <span className="font-medium">{invoice.number}</span>
      <span className="ml-auto text-muted-foreground">${(invoice.total_cents / 100).toFixed(2)}</span>
    </div>
  )}
/>
```

## Variable Height Rows

Use `measureElement` ref on each row so the virtualizer learns the actual height as items render. The `estimateSize` is only the initial guess — accuracy improves as the user scrolls.

```tsx
ref={rowVirtualizer.measureElement}
```

Without this, scrolling can jump when estimated heights differ from actual heights.

## With Infinite Query (Combined Pattern)

```tsx
function InfiniteVirtualList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['items'],
    queryFn: ({ pageParam = 0 }) => fetchItems(pageParam),
    getNextPageParam: (last, pages) => last.length === PAGE_SIZE ? pages.length * PAGE_SIZE : undefined,
    initialPageParam: 0,
  })

  const allItems = data?.pages.flat() ?? []

  const rowVirtualizer = useVirtualizer({
    count: hasNextPage ? allItems.length + 1 : allItems.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 56,
    overscan: 5,
  })

  useEffect(() => {
    const [lastItem] = [...rowVirtualizer.getVirtualItems()].reverse()
    if (!lastItem) return
    if (lastItem.index >= allItems.length - 1 && hasNextPage && !isFetchingNextPage) {
      fetchNextPage()
    }
  }, [rowVirtualizer.getVirtualItems(), hasNextPage, isFetchingNextPage])

  return (
    <div ref={parentRef} style={{ height: '600px', overflow: 'auto' }}>
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative' }}>
        {rowVirtualizer.getVirtualItems().map(virtualRow => {
          const isLoader = virtualRow.index > allItems.length - 1
          return (
            <div
              key={virtualRow.index}
              style={{ position: 'absolute', top: 0, width: '100%', transform: `translateY(${virtualRow.start}px)` }}
            >
              {isLoader ? <Skeleton className="h-14" /> : <ItemRow item={allItems[virtualRow.index]} />}
            </div>
          )
        })}
      </div>
    </div>
  )
}
```

## Container Height Is Required

The parent container MUST have an explicit height (CSS `height` or `max-height`). A virtualizer inside a `height: auto` container renders all items — negating the whole point.

## When Not to Virtualize

- Lists under 200 items: not worth the complexity
- Lists where users need Ctrl+F browser search: virtualization hides non-rendered content from browser search
- Grids with very different row heights where layout depends on knowing all heights upfront

## Grid Layout

For virtualized grids (image galleries, product cards), use `@tanstack/react-virtual` with `lanes`:
```ts
const rowVirtualizer = useVirtualizer({
  count: Math.ceil(items.length / COLUMNS),
  // Each virtual row is a grid row
})
```
