# Pattern: Carousel / Slider

## Overview

Carousels display multiple items in a scrollable container with navigation controls. The key decisions: auto-play (almost always wrong for UX), touch/swipe support, loop behavior, and accessibility. Use Embla Carousel rather than building from scratch — it handles all edge cases.

## Embla Carousel Setup

```tsx
import useEmblaCarousel from 'embla-carousel-react'
import Autoplay from 'embla-carousel-autoplay'

interface CarouselProps {
  slides: React.ReactNode[]
  autoPlay?: boolean
}

export function Carousel({ slides, autoPlay = false }: CarouselProps) {
  const plugins = autoPlay
    ? [Autoplay({ delay: 4000, stopOnInteraction: true })]
    : []

  const [emblaRef, emblaApi] = useEmblaCarousel(
    { loop: true, align: 'start' },
    plugins
  )

  const [selectedIndex, setSelectedIndex] = useState(0)

  useEffect(() => {
    if (!emblaApi) return
    emblaApi.on('select', () => setSelectedIndex(emblaApi.selectedScrollSnap()))
  }, [emblaApi])

  return (
    <div>
      <div ref={emblaRef} className="overflow-hidden">
        <div className="flex">
          {slides.map((slide, i) => (
            <div key={i} className="min-w-0 flex-[0_0_100%]">
              {slide}
            </div>
          ))}
        </div>
      </div>

      {/* Navigation */}
      <div className="flex items-center justify-center gap-4 mt-4">
        <button
          onClick={() => emblaApi?.scrollPrev()}
          aria-label="Previous slide"
        >
          <ChevronLeft />
        </button>

        {/* Dots */}
        {slides.map((_, i) => (
          <button
            key={i}
            onClick={() => emblaApi?.scrollTo(i)}
            aria-label={`Go to slide ${i + 1}`}
            aria-current={i === selectedIndex ? 'true' : undefined}
            className={cn('h-2 w-2 rounded-full', i === selectedIndex ? 'bg-blue-600' : 'bg-gray-300')}
          />
        ))}

        <button
          onClick={() => emblaApi?.scrollNext()}
          aria-label="Next slide"
        >
          <ChevronRight />
        </button>
      </div>
    </div>
  )
}
```

## Multi-Item Carousel (Responsive)

```tsx
// Show 1 item on mobile, 2 on tablet, 3 on desktop
const [emblaRef] = useEmblaCarousel({
  loop: false,
  align: 'start',
  slidesToScroll: 1,
})

// CSS: each slide takes 100% / n of the container
// Tailwind: flex-[0_0_calc(100%-1rem)] sm:flex-[0_0_calc(50%-1rem)] lg:flex-[0_0_calc(33.333%-1rem)]
```

## Touch Swipe (Built-in)

Embla handles touch and mouse drag by default. For custom swipe detection without a library:

```tsx
const touchStartX = useRef(0)

function onTouchStart(e: React.TouchEvent) {
  touchStartX.current = e.touches[0].clientX
}

function onTouchEnd(e: React.TouchEvent) {
  const delta = touchStartX.current - e.changedTouches[0].clientX
  if (Math.abs(delta) > 50) {
    delta > 0 ? goNext() : goPrev()
  }
}
```

## Accessibility

```tsx
// ARIA live region announces slide changes to screen readers
<div
  aria-live={autoPlay ? 'off' : 'polite'}
  aria-atomic="true"
  className="sr-only"
>
  {`Slide ${selectedIndex + 1} of ${slides.length}`}
</div>

// Pause auto-play on hover/focus (WCAG 2.1.2)
emblaApi?.on('pointerDown', () => autoplayPlugin.stop())
emblaApi?.on('pointerUp', () => autoplayPlugin.play())
```

## Key Rules

- Auto-play violates WCAG 2.2.2 if content moves longer than 5 seconds without a pause button. Add a pause control or disable auto-play.
- `stopOnInteraction: true` in Autoplay stops auto-play as soon as the user touches/clicks — critical for usability.
- `aria-live="polite"` announces slide changes; set to `"off"` for auto-play carousels (otherwise it announces every 4 seconds).
- `min-w-0` + `flex-[0_0_100%]` on slides prevents flex children from shrinking — the most common layout bug.
- For SEO: all slides are in the DOM (not hidden with `display:none`) — search engines can crawl all content.
