# Pattern: Horizontal Scroll

## Overview

Horizontally scrollable containers for carousels, chip rows, tab bars, and card decks. The core challenge: hiding the scrollbar on desktop while keeping scrollability, enabling snap-to-card behavior, and making keyboard and touch navigation work correctly.

## Basic Container

```tsx
function HorizontalScroll({ children, className }: { children: React.ReactNode; className?: string }) {
  const scrollRef = useRef<HTMLDivElement>(null)

  return (
    <div
      ref={scrollRef}
      className={cn(
        'flex gap-4 overflow-x-auto',
        // Hide scrollbar cross-browser
        'scrollbar-none',                              // Tailwind plugin
        '[&::-webkit-scrollbar]:hidden',               // Chrome/Safari
        '[-ms-overflow-style:none]',                   // IE/Edge
        '[scrollbar-width:none]',                      // Firefox
        className
      )}
    >
      {children}
    </div>
  )
}
```

Add padding so focus outlines aren't clipped: `px-4 -mx-4 scroll-px-4` — negative margin trick offsets container padding while keeping scroll padding:

```tsx
<div className="overflow-x-auto scroll-smooth">
  <div className="flex gap-4 px-4 w-max">
    {items.map(item => <Card key={item.id} {...item} />)}
  </div>
</div>
```

## Snap-to-Card

```tsx
function CardCarousel({ items }: { items: Item[] }) {
  return (
    <div className="overflow-x-auto snap-x snap-mandatory scroll-smooth scrollbar-none">
      <div className="flex gap-4 px-4">
        {items.map(item => (
          <div
            key={item.id}
            className="snap-start flex-none w-72"  // snap-start = snap left edge to container left
          >
            <Card {...item} />
          </div>
        ))}
      </div>
    </div>
  )
}
```

Use `snap-center` for single-item carousels (item centers in view), `snap-start` for multi-item (left-aligns).

## Arrow Navigation Buttons

```tsx
function ScrollableRow({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const [canScrollLeft, setCanScrollLeft] = useState(false)
  const [canScrollRight, setCanScrollRight] = useState(true)

  const updateScrollState = () => {
    const el = ref.current
    if (!el) return
    setCanScrollLeft(el.scrollLeft > 0)
    setCanScrollRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 1)
  }

  useEffect(() => {
    const el = ref.current
    if (!el) return
    updateScrollState()
    el.addEventListener('scroll', updateScrollState, { passive: true })
    const ro = new ResizeObserver(updateScrollState)
    ro.observe(el)
    return () => { el.removeEventListener('scroll', updateScrollState); ro.disconnect() }
  }, [])

  const scroll = (direction: 'left' | 'right') => {
    const el = ref.current
    if (!el) return
    el.scrollBy({ left: direction === 'right' ? 300 : -300, behavior: 'smooth' })
  }

  return (
    <div className="relative group">
      {canScrollLeft && (
        <button
          onClick={() => scroll('left')}
          className="absolute left-0 top-1/2 -translate-y-1/2 z-10 bg-white shadow rounded-full p-2 opacity-0 group-hover:opacity-100 transition-opacity"
          aria-label="Scroll left"
        >
          ←
        </button>
      )}

      <div
        ref={ref}
        className="flex gap-4 overflow-x-auto scrollbar-none px-4 scroll-smooth"
      >
        {children}
      </div>

      {canScrollRight && (
        <button
          onClick={() => scroll('right')}
          className="absolute right-0 top-1/2 -translate-y-1/2 z-10 bg-white shadow rounded-full p-2 opacity-0 group-hover:opacity-100 transition-opacity"
          aria-label="Scroll right"
        >
          →
        </button>
      )}
    </div>
  )
}
```

## Drag-to-Scroll (Desktop)

```tsx
function useDragScroll(ref: React.RefObject<HTMLDivElement>) {
  const dragging = useRef(false)
  const startX = useRef(0)
  const scrollLeft = useRef(0)

  const onMouseDown = (e: React.MouseEvent) => {
    dragging.current = true
    startX.current = e.pageX - (ref.current?.offsetLeft ?? 0)
    scrollLeft.current = ref.current?.scrollLeft ?? 0
    ref.current!.style.cursor = 'grabbing'
    ref.current!.style.userSelect = 'none'
  }

  const onMouseUp = () => {
    dragging.current = false
    if (ref.current) {
      ref.current.style.cursor = 'grab'
      ref.current.style.userSelect = ''
    }
  }

  const onMouseMove = (e: React.MouseEvent) => {
    if (!dragging.current || !ref.current) return
    e.preventDefault()
    const x = e.pageX - ref.current.offsetLeft
    const delta = (x - startX.current) * 1.5
    ref.current.scrollLeft = scrollLeft.current - delta
  }

  return { onMouseDown, onMouseUp, onMouseMove, onMouseLeave: onMouseUp }
}
```

## Key Rules

- `flex-none` on children prevents them from shrinking — required for horizontal scroll to work.
- `scroll-smooth` on the container makes arrow-button scrolling look polished.
- Fade edges with a gradient mask (`mask-image: linear-gradient(to right, transparent, black 1rem, black calc(100% - 1rem), transparent)`) to hint at off-screen content.
- Never use `width: max-content` on the outer container — use it on the inner flex container to prevent wrapping.
- Touch scrolling works automatically; the drag-to-scroll hook is only for desktop pointer events.
