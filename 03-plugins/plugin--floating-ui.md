# Plugin: Floating UI

## Overview

Floating UI positions tooltips, popovers, dropdowns, and any "floating" element relative to a trigger. The main problem it solves: keeping floaters on screen (flip to opposite side when there's no space), detecting overflow, and handling scroll/resize. Use it instead of hand-rolling `getBoundingClientRect` positioning.

## Installation

```bash
npm install @floating-ui/react
```

## Basic Tooltip

```tsx
import {
  useFloating,
  autoUpdate,
  offset,
  flip,
  shift,
  useHover,
  useFocus,
  useDismiss,
  useRole,
  useInteractions,
  FloatingPortal,
} from '@floating-ui/react'

function Tooltip({ children, label }: { children: React.ReactNode; label: string }) {
  const [open, setOpen] = useState(false)

  const { refs, floatingStyles, context } = useFloating({
    open,
    onOpenChange: setOpen,
    placement: 'top',
    whileElementsMounted: autoUpdate,  // Reposition on scroll/resize
    middleware: [
      offset(8),   // Gap between trigger and tooltip
      flip(),      // Switch to bottom if no space at top
      shift(),     // Shift left/right to stay on screen
    ],
  })

  const hover = useHover(context, { delay: { open: 400, close: 100 } })
  const focus = useFocus(context)
  const dismiss = useDismiss(context)
  const role = useRole(context, { role: 'tooltip' })

  const { getReferenceProps, getFloatingProps } = useInteractions([hover, focus, dismiss, role])

  return (
    <>
      <span ref={refs.setReference} {...getReferenceProps()}>
        {children}
      </span>
      <FloatingPortal>
        {open && (
          <div
            ref={refs.setFloating}
            style={floatingStyles}
            {...getFloatingProps()}
            className="z-50 bg-gray-900 text-white text-xs px-2 py-1 rounded"
          >
            {label}
          </div>
        )}
      </FloatingPortal>
    </>
  )
}
```

## Popover (Click to Open)

```tsx
const click = useClick(context)
const dismiss = useDismiss(context)

const { getReferenceProps, getFloatingProps } = useInteractions([click, dismiss])
```

Replace `useHover` with `useClick` — same structure, different interaction.

## Dropdown Menu

```tsx
import { useListNavigation, useTypeahead } from '@floating-ui/react'

const listRef = useRef<(HTMLElement | null)[]>([])
const [activeIndex, setActiveIndex] = useState<number | null>(null)

const listNav = useListNavigation(context, {
  listRef,
  activeIndex,
  onNavigate: setActiveIndex,
  loop: true,
})

// Items in the floating element
{items.map((item, i) => (
  <div
    key={item.id}
    ref={el => { listRef.current[i] = el }}
    role="option"
    tabIndex={activeIndex === i ? 0 : -1}
    aria-selected={activeIndex === i}
    {...getItemProps({
      onClick: () => { selectItem(item); setOpen(false) },
    })}
  >
    {item.label}
  </div>
))}
```

## Arrow

```tsx
import { arrow } from '@floating-ui/react'

const arrowRef = useRef<SVGSVGElement>(null)

// In middleware array:
arrow({ element: arrowRef })

// In floating element (after floatingStyles is available):
<FloatingArrow ref={arrowRef} context={context} className="fill-gray-900" />
```

## Key Rules

- `autoUpdate` is required for correct positioning during scroll and resize — always pass it via `whileElementsMounted`.
- `FloatingPortal` renders to `document.body` — prevents clipping inside `overflow: hidden` containers.
- `flip()` + `shift()` together handle all overflow cases — use both.
- `offset(8)` is the gap between trigger and floater — without it, the floater sits flush against the trigger.
- For dropdowns on mobile: consider using a bottom sheet instead — Floating UI popovers at the top of the viewport are hard to reach.
