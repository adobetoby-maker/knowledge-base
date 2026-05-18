# Pattern: Collapsible Section

## Overview

Expand/collapse a section of content with smooth animation. Used for FAQs, settings groups, sidebar filters. Distinct from Accordion (one-at-a-time) — Collapsible is standalone. Key challenge: animating to `height: auto` — CSS can't transition to `auto`, so several workarounds exist.

## CSS Max-Height Trick

Simple but imprecise — max-height must be set large enough:

```tsx
function CollapsibleSection({ title, children, defaultOpen = false }: {
  title: string
  children: React.ReactNode
  defaultOpen?: boolean
}) {
  const [open, setOpen] = useState(defaultOpen)

  return (
    <div className="border rounded-lg">
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between px-4 py-3 text-left font-medium"
        aria-expanded={open}
      >
        <span>{title}</span>
        <span className={`transition-transform duration-200 ${open ? 'rotate-180' : ''}`}>
          ▾
        </span>
      </button>
      <div
        className={`overflow-hidden transition-all duration-300 ease-in-out ${
          open ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
        }`}
      >
        <div className="px-4 pb-4">
          {children}
        </div>
      </div>
    </div>
  )
}
```

**Limitation**: `max-h-96` (384px) must be larger than your content. If content varies, this causes timing issues — the animation finishes before content is fully visible.

## Measured Height Approach (Precise)

```tsx
function CollapsibleSection({ title, children, defaultOpen = false }: {
  title: string
  children: React.ReactNode
  defaultOpen?: boolean
}) {
  const [open, setOpen] = useState(defaultOpen)
  const contentRef = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState<number | 'auto'>(defaultOpen ? 'auto' : 0)

  function toggle() {
    if (!open) {
      // Opening: measure then animate
      const contentHeight = contentRef.current?.scrollHeight ?? 0
      setHeight(contentHeight)
      setOpen(true)
      // After animation, set to auto for responsive resizing
      setTimeout(() => setHeight('auto'), 300)
    } else {
      // Closing: fix height then animate to 0
      const contentHeight = contentRef.current?.scrollHeight ?? 0
      setHeight(contentHeight)
      // Trigger reflow, then animate to 0
      requestAnimationFrame(() => {
        requestAnimationFrame(() => setHeight(0))
      })
      setOpen(false)
    }
  }

  return (
    <div className="border rounded-lg">
      <button
        onClick={toggle}
        className="w-full flex items-center justify-between px-4 py-3 text-left font-medium"
        aria-expanded={open}
      >
        <span>{title}</span>
        <svg className={`w-4 h-4 transition-transform duration-200 ${open ? 'rotate-180' : ''}`} viewBox="0 0 20 20" fill="currentColor">
          <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" />
        </svg>
      </button>
      <div
        ref={contentRef}
        style={{ height: typeof height === 'number' ? `${height}px` : height }}
        className="overflow-hidden transition-[height] duration-300 ease-in-out"
      >
        <div className="px-4 pb-4">
          {children}
        </div>
      </div>
    </div>
  )
}
```

## Using Radix Collapsible

```tsx
import * as Collapsible from '@radix-ui/react-collapsible'

<Collapsible.Root>
  <Collapsible.Trigger className="...">Toggle</Collapsible.Trigger>
  <Collapsible.Content className="overflow-hidden data-[state=open]:animate-slideDown data-[state=closed]:animate-slideUp">
    <div className="px-4 pb-4">{children}</div>
  </Collapsible.Content>
</Collapsible.Root>
```

Add CSS animations:

```css
@keyframes slideDown {
  from { height: 0; }
  to { height: var(--radix-collapsible-content-height); }
}
@keyframes slideUp {
  from { height: var(--radix-collapsible-content-height); }
  to { height: 0; }
}
```

Radix exposes `--radix-collapsible-content-height` CSS variable — this solves the `height: auto` problem correctly.

## Key Rules

- `aria-expanded` on the trigger is required for accessibility.
- For FAQ pages, wrap in schema.org FAQPage markup in addition to this component.
- `transition-[height]` in Tailwind — extend `transitionProperty` in config if not in v3.3+.
- Use Radix Collapsible for the cleanest implementation. Roll your own only if you can't add the dependency.
