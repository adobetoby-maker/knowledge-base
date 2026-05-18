# Pattern: Read More / Expand Text

## Overview

Truncate long text to N lines and show a "Read more" toggle to expand. Use CSS `line-clamp` for truncation rather than JS character counting — CSS handles variable fonts, different screen widths, and renders correctly on first paint without layout shift.

## Component

```tsx
interface ReadMoreProps {
  text: string
  maxLines?: number
  className?: string
}

export function ReadMore({ text, maxLines = 3, className }: ReadMoreProps) {
  const [expanded, setExpanded] = useState(false)
  const [needsClamping, setNeedsClamping] = useState(false)
  const textRef = useRef<HTMLParagraphElement>(null)

  useEffect(() => {
    const el = textRef.current
    if (!el) return
    const isOverflowing = el.scrollHeight > el.clientHeight
    setNeedsClamping(isOverflowing)
  }, [text])

  return (
    <div className={className}>
      <p
        ref={textRef}
        style={!expanded ? {
          WebkitLineClamp: maxLines,
          display: '-webkit-box',
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        } : undefined}
        className="text-sm text-gray-700"
      >
        {text}
      </p>

      {needsClamping && (
        <button
          onClick={() => setExpanded(!expanded)}
          className="mt-1 text-sm text-blue-600 hover:underline"
        >
          {expanded ? 'Show less' : 'Read more'}
        </button>
      )}
    </div>
  )
}
```

Always render `text` as a React text node — never inject raw HTML. For rich content (markdown output), use `react-markdown` which produces a React element tree rather than inserting HTML directly.

## CSS-Only Version

For display-only truncation without a toggle:

```tsx
// Tailwind: line-clamp-2, line-clamp-3, line-clamp-4, line-clamp-6
<p className="line-clamp-3 text-sm text-gray-700">
  {longText}
</p>
```

## With Fade Gradient Overlay

Visual hint that content continues:

```tsx
<div className="relative">
  <p
    ref={textRef}
    style={!expanded ? { maxHeight: `${maxLines * 1.5}rem`, overflow: 'hidden' } : undefined}
    className="text-sm text-gray-700 transition-all duration-300"
  >
    {text}
  </p>

  {!expanded && needsClamping && (
    <div className="absolute bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-white pointer-events-none" />
  )}

  {needsClamping && (
    <button onClick={() => setExpanded(!expanded)} className="text-sm text-blue-600 hover:underline">
      {expanded ? 'Show less' : 'Read more'}
    </button>
  )}
</div>
```

## Animated Expansion with Radix Collapsible

```tsx
import * as Collapsible from '@radix-ui/react-collapsible'

export function ReadMoreAnimated({ text, maxLines = 3 }: ReadMoreProps) {
  const [open, setOpen] = useState(false)
  const [showToggle, setShowToggle] = useState(false)
  const measureRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const el = measureRef.current
    if (!el) return
    const lineHeight = parseFloat(getComputedStyle(el).lineHeight)
    const maxHeight = lineHeight * maxLines
    setShowToggle(el.scrollHeight > maxHeight + 2)
  }, [text, maxLines])

  return (
    <div>
      {/* Hidden element to measure actual height */}
      <p ref={measureRef} className="invisible absolute pointer-events-none">{text}</p>

      <Collapsible.Root open={open} onOpenChange={setOpen}>
        <Collapsible.Content
          style={{ maxHeight: !open ? `${maxLines * 1.5}rem` : undefined, overflow: !open ? 'hidden' : undefined }}
        >
          <p className="text-sm text-gray-700">{text}</p>
        </Collapsible.Content>

        {showToggle && (
          <Collapsible.Trigger className="text-sm text-blue-600 hover:underline mt-1">
            {open ? 'Show less' : 'Read more'}
          </Collapsible.Trigger>
        )}
      </Collapsible.Root>
    </div>
  )
}
```

## Key Rules

- Measure overflow after mount — don't guess based on character count (different fonts render differently).
- `setNeedsClamping` check prevents showing "Read more" when the text fits on its own without truncation.
- `line-clamp` (Tailwind) is the simplest solution when a toggle isn't needed — one class, no JS.
- Avoid hard-coded `max-height` pixel values for the collapsed state — use `${maxLines * measuredLineHeight}px` to stay accurate across fonts.
- Always render text as a plain React text node; for formatted content use `react-markdown` to get a safe element tree.
