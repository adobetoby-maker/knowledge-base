# Plugin: Embla Carousel

## What It Is

Embla Carousel is a lightweight, performant carousel/slider library. Framework-agnostic core with React hooks wrapper. Supports touch, mouse drag, autoplay, infinite loop, dots, arrows. No opinions on styling — fully custom.

## Installation

```bash
npm install embla-carousel-react embla-carousel-autoplay
```

## Basic Carousel

```tsx
'use client'
import useEmblaCarousel from 'embla-carousel-react'
import { useCallback } from 'react'

interface CarouselProps {
  slides: { id: string; src: string; alt: string }[]
}

export function ImageCarousel({ slides }: CarouselProps) {
  const [emblaRef, emblaApi] = useEmblaCarousel({
    loop: true,
    align: 'start',
  })

  const scrollPrev = useCallback(() => emblaApi?.scrollPrev(), [emblaApi])
  const scrollNext = useCallback(() => emblaApi?.scrollNext(), [emblaApi])

  return (
    <div className="relative">
      {/* Viewport */}
      <div className="overflow-hidden" ref={emblaRef}>
        <div className="flex">
          {slides.map((slide) => (
            <div
              key={slide.id}
              className="flex-none w-full"  // Each slide takes full width
            >
              <img
                src={slide.src}
                alt={slide.alt}
                className="w-full h-64 object-cover"
              />
            </div>
          ))}
        </div>
      </div>

      {/* Controls */}
      <button
        onClick={scrollPrev}
        className="absolute left-2 top-1/2 -translate-y-1/2 bg-white/80 rounded-full p-2"
        aria-label="Previous"
      >
        ←
      </button>
      <button
        onClick={scrollNext}
        className="absolute right-2 top-1/2 -translate-y-1/2 bg-white/80 rounded-full p-2"
        aria-label="Next"
      >
        →
      </button>
    </div>
  )
}
```

The key structure: **outer div** (position relative, clip) → `emblaRef` → inner flex container → slides (`flex-none` + width).

## Options

```ts
const [emblaRef] = useEmblaCarousel({
  loop: true,           // Infinite loop
  align: 'start',       // 'start' | 'center' | 'end'
  slidesToScroll: 1,    // How many slides per scroll
  dragFree: false,      // Momentum scrolling
  containScroll: 'trimSnaps',  // Prevents over-scrolling at edges
  direction: 'ltr',     // 'ltr' | 'rtl'
  breakpoints: {        // Responsive options
    '(min-width: 768px)': { slidesToScroll: 2 },
  },
})
```

## Dots Navigation

```tsx
'use client'
import useEmblaCarousel from 'embla-carousel-react'
import { useState, useEffect, useCallback } from 'react'

export function CarouselWithDots({ slides }: CarouselProps) {
  const [emblaRef, emblaApi] = useEmblaCarousel({ loop: true })
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [scrollSnaps, setScrollSnaps] = useState<number[]>([])

  useEffect(() => {
    if (!emblaApi) return

    setScrollSnaps(emblaApi.scrollSnapList())
    emblaApi.on('select', () => setSelectedIndex(emblaApi.selectedScrollSnap()))
  }, [emblaApi])

  return (
    <div>
      <div className="overflow-hidden" ref={emblaRef}>
        <div className="flex">
          {slides.map((slide) => (
            <div key={slide.id} className="flex-none w-full">
              <img src={slide.src} alt={slide.alt} className="w-full h-64 object-cover" />
            </div>
          ))}
        </div>
      </div>

      <div className="flex justify-center gap-2 mt-3">
        {scrollSnaps.map((_, i) => (
          <button
            key={i}
            onClick={() => emblaApi?.scrollTo(i)}
            className={`w-2 h-2 rounded-full transition-colors ${
              i === selectedIndex ? 'bg-blue-600' : 'bg-gray-300'
            }`}
            aria-label={`Go to slide ${i + 1}`}
          />
        ))}
      </div>
    </div>
  )
}
```

## Autoplay

```tsx
import useEmblaCarousel from 'embla-carousel-react'
import Autoplay from 'embla-carousel-autoplay'

function AutoSlider() {
  const [emblaRef] = useEmblaCarousel({ loop: true }, [
    Autoplay({ delay: 4000, stopOnInteraction: true }),
  ])

  return (
    <div className="overflow-hidden" ref={emblaRef}>
      {/* ... */}
    </div>
  )
}
```

`stopOnInteraction: true` pauses autoplay when user drags — good UX default.

## Multiple Visible Slides

```tsx
// Show 3 slides at once (responsive)
<div
  key={slide.id}
  className="flex-none w-full md:w-1/2 lg:w-1/3 px-2"
>
```

Use fractional widths (`w-1/2`, `w-1/3`) on each slide. Add `px-2` for gaps between slides.

## `emblaApi` Reference

```ts
emblaApi.scrollPrev()          // Previous slide
emblaApi.scrollNext()          // Next slide
emblaApi.scrollTo(index)       // Jump to specific slide
emblaApi.selectedScrollSnap()  // Current index
emblaApi.scrollSnapList()      // Array of snap positions
emblaApi.on('select', cb)      // Subscribe to slide change
emblaApi.off('select', cb)     // Unsubscribe
emblaApi.destroy()             // Cleanup
```

## When NOT to Use Embla

- Static hero images that don't slide: use CSS animation or Framer Motion instead
- Product image zoom: `react-medium-image-zoom` is better suited
- Full-page scroll stories: use `scroll-snap-type` CSS + `IntersectionObserver`
