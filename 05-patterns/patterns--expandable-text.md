# Pattern: Expandable/Collapsible Long Text

## Overview

Long text truncated with a "Show more" toggle is common in product descriptions, comments, bios, and article previews. There are two approaches: CSS `line-clamp` (simpler, good for most cases) and measured-height (precise, needed when you need exact pixel boundaries). The critical accessibility requirement is that the text must be fully available to screen readers even when visually collapsed — never use `display: none` or `visibility: hidden` on the overflow content.

## CSS Line-Clamp Approach

```tsx
import { useState } from 'react'

type ExpandableTextProps = {
  text: string
  maxLines?: number
  className?: string
}

export function ExpandableText({ text, maxLines = 3, className }: ExpandableTextProps) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div className={className}>
      <p
        style={{
          display: '-webkit-box',
          WebkitLineClamp: expanded ? 'unset' : maxLines,
          WebkitBoxOrient: 'vertical',
          overflow: expanded ? 'visible' : 'hidden',
        }}
        // No aria-expanded here — it belongs on the button
      >
        {text}
      </p>
      <button
        type="button"
        onClick={() => setExpanded(prev => !prev)}
        aria-expanded={expanded}
        className="expand-toggle"
      >
        {expanded ? 'Show less' : 'Show more'}
      </button>
    </div>
  )
}
```

**Why `aria-expanded` on the button, not the paragraph:** `aria-expanded` is an ARIA state that communicates the expansion status. It belongs on the interactive control (the button), not the content region. The screen reader announces "Show more, collapsed" or "Show less, expanded."

**Why not `display: none` for the overflow:** `display: none` removes content from the accessibility tree. Screen reader users can't access the hidden text. `-webkit-line-clamp` clips visually but the DOM content is still present and readable.

## Measured Height Approach

For pixel-precise control (e.g., exactly 120px, regardless of font size):

```tsx
import { useState, useRef, useEffect } from 'react'

const COLLAPSED_HEIGHT = 120  // px

export function ExpandableTextMeasured({ text }: { text: string }) {
  const [expanded, setExpanded] = useState(false)
  const [isTruncated, setIsTruncated] = useState(false)
  const contentRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (contentRef.current) {
      setIsTruncated(contentRef.current.scrollHeight > COLLAPSED_HEIGHT)
    }
  }, [text])

  return (
    <div>
      <div
        ref={contentRef}
        style={{
          maxHeight: expanded ? 'none' : `${COLLAPSED_HEIGHT}px`,
          overflow: 'hidden',
          // Smooth animation — see note below
          transition: expanded ? 'max-height 300ms ease' : 'none',
        }}
      >
        {text}
      </div>
      {isTruncated && (
        <button
          type="button"
          aria-expanded={expanded}
          onClick={() => setExpanded(prev => !prev)}
          className="expand-toggle"
        >
          {expanded ? 'Show less' : 'Show more'}
        </button>
      )}
    </div>
  )
}
```

**Why only animate on expand, not collapse:** When collapsing, `max-height: none → 120px` causes the browser to animate from the actual scroll height (say, 800px) down to 120px, taking 2+ seconds if duration is fixed. Apply the transition only when expanding (`expanded ? 'transition...' : 'none'`). Or use `max-height` with a reasonable cap (e.g., `max-height: 2000px`) for the expanded state — the transition runs quickly because 120px → 2000px at 300ms looks instant even though the range is large.

**Why check `scrollHeight > collapsedHeight`:** If the text is short enough to fit in the collapsed height, don't show the toggle button at all. Always measure, never guess.

## Gradient Fade

For a more polished truncation, add a gradient fade over the last few lines:

```css
.expandable-text-wrapper {
  position: relative;
}

.expandable-text-wrapper::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 3rem;
  background: linear-gradient(to bottom, transparent, var(--bg-color));
  pointer-events: none;
  opacity: 1;
  transition: opacity 200ms;
}

.expandable-text-wrapper[data-expanded="true"]::after {
  opacity: 0;
}
```

Set `data-expanded={String(expanded)}` on the wrapper to control the fade.

## "Show less" Scroll Back

After collapsing, if the "Show less" button is now far below the viewport, scroll the top of the component back into view:

```ts
const wrapperRef = useRef<HTMLDivElement>(null)

function handleCollapse() {
  setExpanded(false)
  setTimeout(() => {
    wrapperRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }, 0)
}
```

## Key Rules

- Never use `display: none` or `visibility: hidden` on overflow text — screen readers lose access to the content
- `aria-expanded` belongs on the button, not the content container
- Only show toggle button when content is actually truncated — measure `scrollHeight` before rendering toggle
- Don't animate the `max-height` collapse with `max-height: none` as start — it produces a slow reverse animation
- Add gradient fade over the last few lines to signal more content without an abrupt clip edge
- Scroll collapsed content into view after "Show less" — user may have scrolled far into the expanded text
