# Pattern: Masonry Grid

## Overview

Pinterest-style layout where items are different heights but columns align at the top, filling vertical space efficiently. CSS Grid and Flexbox can't do this natively — items are either fixed-height (grid) or one-per-row (flex column). Three approaches: CSS column layout (simple, limited), JavaScript column assignment (full control), or `react-masonry-css` (easiest for React).

## CSS Columns (Simplest)

```css
.masonry {
  column-count: 3;
  column-gap: 1rem;
}

.masonry-item {
  break-inside: avoid;  /* Prevent item from splitting across columns */
  margin-bottom: 1rem;
  display: inline-block;  /* Required for break-inside to work */
  width: 100%;
}
```

**Limitation**: items flow top-to-bottom within each column, so chronological order reads left-to-right across columns at the same level but order is inconsistent. Not suitable for ordered lists.

## react-masonry-css (Recommended)

```tsx
import Masonry from 'react-masonry-css'

const breakpointColumns = {
  default: 4,
  1100: 3,
  700: 2,
  500: 1,
}

function PhotoGrid({ photos }: { photos: Photo[] }) {
  return (
    <Masonry
      breakpointCols={breakpointColumns}
      className="flex -ml-4 w-auto"
      columnClassName="pl-4 bg-clip-padding"
    >
      {photos.map(photo => (
        <div key={photo.id} className="mb-4">
          <img
            src={photo.url}
            alt={photo.alt}
            width={photo.width}
            height={photo.height}
            className="rounded w-full"
          />
        </div>
      ))}
    </Masonry>
  )
}
```

This uses CSS columns under the hood but applies the negative-margin pattern to avoid double-gap at edges.

## JavaScript Column Assignment (Most Control)

For dynamic loading, animations, or when item order must be preserved:

```tsx
function useColumns<T>(items: T[], columnCount: number) {
  const columns = Array.from({ length: columnCount }, () => [] as T[])
  const heights = new Array(columnCount).fill(0)

  // Distribute items to shortest column
  items.forEach((item, i) => {
    if (i < columnCount) {
      // First row: fill left to right
      columns[i].push(item)
    } else {
      const shortest = heights.indexOf(Math.min(...heights))
      columns[shortest].push(item)
      heights[shortest] += getItemHeight(item)  // Requires known heights
    }
  })

  return columns
}
```

The catch: you need to know item heights ahead of time to distribute optimally. For images, use the aspect ratio from metadata. For variable-height cards, render offscreen first.

## Loading More (Infinite Scroll)

New items should go to the shortest column, not just appended to the end. Track column heights as state:

```tsx
function addItem(item: Item) {
  const shortest = columnHeights.indexOf(Math.min(...columnHeights))
  setColumns(prev => prev.map((col, i) => i === shortest ? [...col, item] : col))
  setColumnHeights(prev => prev.map((h, i) => i === shortest ? h + estimateHeight(item) : h))
}
```

## Key Rules

- Always provide `width` and `height` attributes on images to prevent CLS as images load.
- `break-inside: avoid` is required on each item, not the container.
- CSS columns are fine for static galleries; JavaScript column assignment is needed if you're animating new items in or need stable ordering.
- For performance: virtualize off-screen items using `react-window` or similar if the list is very long. Masonry is hard to virtualize — consider pagination instead.
