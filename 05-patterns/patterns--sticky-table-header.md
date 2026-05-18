# Pattern: Sticky Table Header on Scroll

## Overview
Long tables without sticky headers force users to scroll back to the top to understand column labels. The most common implementation mistake is omitting a background color, causing table content to bleed through the translucent header. Sticky first columns require additional z-index layering to avoid overlap bugs.

## Implementation

```css
/* Base sticky header styles */
.table-wrapper {
  /* Required: table must scroll inside a bounded container */
  overflow: auto;
  max-height: 600px;
  position: relative;
}

table {
  border-collapse: separate;  /* Required for sticky + borders to work */
  border-spacing: 0;
  width: 100%;
}

thead th {
  position: sticky;
  top: 0;
  z-index: 10;

  /* CRITICAL: transparent background causes content to bleed through */
  background-color: var(--color-surface, #ffffff);

  /* Subtle shadow appears on scroll via JS (see below) */
  box-shadow: none;
  transition: box-shadow 120ms ease;
}

thead th.scrolled {
  /* Applied by JS when table has scrolled */
  box-shadow: 0 2px 4px rgba(0,0,0,0.12);
}

/* Sticky first column — for wide tables that scroll horizontally */
td:first-child,
th:first-child {
  position: sticky;
  left: 0;
  background-color: var(--color-surface, #ffffff);
  /* Higher z-index than body cells, but lower than header */
  z-index: 5;
}

thead th:first-child {
  /* Corner cell: must be above both sticky column AND sticky header */
  z-index: 15;
}
```

```tsx
// StickyTable.tsx — shadow on scroll via IntersectionObserver
import { useEffect, useRef } from 'react'

export function StickyTable({ children }: { children: React.ReactNode }) {
  const wrapperRef = useRef<HTMLDivElement>(null)
  const theadRef = useRef<HTMLTableSectionElement>(null)

  useEffect(() => {
    const wrapper = wrapperRef.current
    if (!wrapper) return

    // Sentinel element at the top of the scroll area
    // When it leaves the viewport (scrolled past), the header is now sticky
    const sentinel = document.createElement('div')
    sentinel.style.height = '1px'
    sentinel.style.pointerEvents = 'none'
    wrapper.prepend(sentinel)

    const observer = new IntersectionObserver(
      ([entry]) => {
        // sentinel leaving view = table has scrolled = show shadow
        theadRef.current?.querySelectorAll('th').forEach(th => {
          th.classList.toggle('scrolled', !entry.isIntersecting)
        })
      },
      {
        root: wrapper,  // observe within the scroll container, not the page
        threshold: 0,
      }
    )

    observer.observe(sentinel)

    return () => {
      observer.disconnect()
      sentinel.remove()
    }
  }, [])

  return (
    <div
      ref={wrapperRef}
      className="table-wrapper"
      // Accessibility: tables inside scroll containers need explicit role
      role="region"
      aria-label="Data table"
      tabIndex={0}  // Make the scroll container keyboard-focusable
    >
      <table>
        <thead ref={theadRef}>
          {/* header rows */}
        </thead>
        <tbody>
          {children}
        </tbody>
      </table>
    </div>
  )
}
```

```tsx
// Horizontal scroll with sticky first column
// The key is keeping background-color consistent across themes

// Tailwind version
<th className="sticky top-0 left-0 z-[15] bg-white dark:bg-gray-900">
  Name
</th>

// When using CSS variables, ensure the variable resolves to a solid color
// :root { --surface: #fff; }
// .dark { --surface: #1a1a2e; }
// Never use rgba with alpha < 1 for sticky backgrounds
```

```tsx
// Handling sticky header height when there's a fixed app navbar above
// Use top: var(--navbar-height) instead of top: 0
<th style={{ top: 'var(--navbar-height, 0px)' }}>
  Column
</th>
```

## Key Rules
- `position: sticky` on `<th>` requires a bounded scroll container — it won't work if the page itself scrolls and `overflow: visible` on all ancestors.
- Always set a solid `background-color` on sticky cells — transparent background = content bleeds through.
- Use `border-collapse: separate` (not `collapse`) when combining sticky positioning with cell borders.
- Add a scrolled shadow via IntersectionObserver on a sentinel element, not via `scroll` events — IntersectionObserver is more performant.
- Sticky first column requires `left: 0` and its own background color.
- The corner cell (top-left) needs a higher `z-index` than both the sticky column and sticky header.
- Make the scroll container keyboard-focusable (`tabIndex={0}`) so keyboard users can scroll horizontally.
- If a fixed navbar exists above the table, set `top` to the navbar height, not 0.
- Test sticky headers in dark mode — the background variable must resolve to a solid dark color, not transparent.
