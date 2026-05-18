# Pattern: Expandable Card

## Overview

A card that expands to show additional content — used for FAQs, product details, team bios, or any "read more" in a grid. The key challenges: animating height from 0 to auto (CSS `height: auto` can't animate), not breaking grid layout when one card expands, and loading expanded content lazily so the page isn't slow on first render.

## Animating Height Auto with CSS

The reliable technique: animate `grid-template-rows` from `0fr` to `1fr`. The inner div has `overflow: hidden` and `min-height: 0`. This avoids the `scrollHeight` JS measurement approach and is pure CSS:

```tsx
function ExpandableCard({ title, summary, children }: {
  title: string
  summary: string
  children: React.ReactNode
}) {
  const [open, setOpen] = useState(false)
  const contentId = useId()

  return (
    <article className="border rounded-lg overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-controls={contentId}
        className="w-full text-left px-4 py-4 flex items-center justify-between"
      >
        <div>
          <h3 className="font-semibold">{title}</h3>
          <p className="text-sm text-gray-500">{summary}</p>
        </div>
        <ChevronDownIcon
          className={`w-5 h-5 flex-shrink-0 transition-transform ${open ? 'rotate-180' : ''}`}
          aria-hidden="true"
        />
      </button>

      {/* grid-template-rows: 0fr → 1fr animates height without JS */}
      <div
        id={contentId}
        style={{
          display: 'grid',
          gridTemplateRows: open ? '1fr' : '0fr',
          transition: 'grid-template-rows 250ms ease',
        }}
        aria-hidden={!open}
      >
        <div style={{ overflow: 'hidden', minHeight: 0 }}>
          <div className="px-4 pb-4">
            {children}
          </div>
        </div>
      </div>
    </article>
  )
}
```

Why `grid-template-rows`: it accepts `fr` units which can animate between `0fr` and `1fr`. The inner div with `overflow: hidden` clips the content during animation. `min-height: 0` on the inner div is required in a grid context — otherwise the minimum intrinsic height of children can prevent full collapse.

## Not Breaking Grid Layout

When a card inside a CSS grid expands, it pushes down cards in the same row, breaking the visual grid. Solutions:

**Option 1: CSS Grid span trick** — expanded card spans to a new row using `grid-column: 1 / -1` on a hidden detail row. Complex to implement.

**Option 2: Independent card layout** — don't put expandable cards in a strict CSS grid where row alignment matters. Use `flex-wrap` or CSS columns, or a masonry layout.

**Option 3: Single-expansion with detail below** — only one card can be expanded at a time. The detail panel is a full-width row inserted after the card's row via absolute positioning or a DOM insertion.

For most use cases, Option 2 (masonry / flex-wrap column layout) is the simplest. Reserve Option 3 for product listing pages where grid alignment is required.

## Lazy Loading Expanded Content

```tsx
function ExpandableCardLazy({ title, summary, fetchDetails }: {
  title: string
  summary: string
  fetchDetails: () => Promise<React.ReactNode>
}) {
  const [open, setOpen] = useState(false)
  const [content, setContent] = useState<React.ReactNode | null>(null)
  const [loading, setLoading] = useState(false)

  async function handleExpand() {
    const next = !open
    setOpen(next)
    if (next && !content) {
      setLoading(true)
      const result = await fetchDetails()
      setContent(result)
      setLoading(false)
    }
  }

  return (
    <article>
      <button type="button" onClick={handleExpand} aria-expanded={open}>
        {title}
        <ChevronDownIcon className={open ? 'rotate-180' : ''} />
      </button>

      <div style={{ display: 'grid', gridTemplateRows: open ? '1fr' : '0fr', transition: 'grid-template-rows 250ms ease' }}>
        <div style={{ overflow: 'hidden', minHeight: 0 }}>
          {loading ? (
            <div className="px-4 pb-4"><Skeleton /></div>
          ) : (
            <div className="px-4 pb-4">{content}</div>
          )}
        </div>
      </div>
    </article>
  )
}
```

Fetch only on first open (`!content` guard). Keep content mounted after first load — don't re-fetch on each toggle.

## Key Rules

- Use `grid-template-rows: 0fr → 1fr` for height animation — it's the only pure-CSS approach that doesn't require JS measurement.
- The inner grid child must have `overflow: hidden` and `min-height: 0` — both are required for full collapse.
- `aria-expanded` on the trigger button and `aria-controls` pointing to the content id are required for screen readers.
- Lazy-load expanded content on first open, then keep it mounted — avoids both initial payload cost and re-fetching on toggle.
- In CSS grid layouts, expandable cards should use `flex-wrap` / masonry rather than strict `grid-template-columns` to avoid row-breaking.
- `aria-hidden={!open}` on the content area prevents screen readers from reading collapsed content.
