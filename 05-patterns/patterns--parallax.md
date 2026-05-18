# Pattern: Parallax Scroll Effects

## Overview

Parallax creates depth by moving elements at different speeds as the user scrolls. Done well: subtle, adds polish, feels premium. Done wrong: causes CLS, jank, performance issues, motion sickness.

## Rule: Always Check prefers-reduced-motion

Before adding any motion effect, check user preference:

```tsx
import { useEffect, useState } from 'react'

function usePrefersReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false)

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    setReduced(mq.matches)
    const handler = (e: MediaQueryListEvent) => setReduced(e.matches)
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [])

  return reduced
}
```

If `prefersReducedMotion` is true, disable all parallax and scroll-triggered motion.

## CSS-Only Parallax (Simplest, Best Performance)

```css
/* For background images */
.hero {
  background-image: url('/hero.jpg');
  background-attachment: fixed;  /* Parallax effect */
  background-position: center;
  background-size: cover;
  height: 60vh;
}

/* Does NOT work on iOS Safari — use JS for cross-platform */
```

CSS `background-attachment: fixed` is a single line but broken on iOS. Only use for desktop-focused sites.

## CSS Transform Parallax (Cross-Browser)

```tsx
import { useEffect, useRef } from 'react'

export function ParallaxHero({ src, alt }: { src: string; alt: string }) {
  const imgRef = useRef<HTMLImageElement>(null)
  const prefersReduced = usePrefersReducedMotion()

  useEffect(() => {
    if (prefersReduced) return

    let rafId: number

    function updateParallax() {
      if (!imgRef.current) return

      const scrollY = window.scrollY
      const speed = 0.4  // 0 = no effect, 1 = moves with scroll (no parallax)
      
      // translateY moves opposite to scroll
      imgRef.current.style.transform = `translateY(${scrollY * speed}px)`
    }

    function onScroll() {
      cancelAnimationFrame(rafId)
      rafId = requestAnimationFrame(updateParallax)
    }

    window.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      window.removeEventListener('scroll', onScroll)
      cancelAnimationFrame(rafId)
    }
  }, [prefersReduced])

  return (
    <div className="relative h-[70vh] overflow-hidden">
      <img
        ref={imgRef}
        src={src}
        alt={alt}
        className="absolute inset-0 h-[130%] w-full -top-[15%] object-cover will-change-transform"
      />
    </div>
  )
}
```

`will-change-transform` promotes the element to its own compositor layer, preventing repaints during scroll.

## Framer Motion Parallax

For React apps with Framer Motion already installed:

```tsx
import { motion, useScroll, useTransform } from 'framer-motion'

export function ParallaxSection({ children }: { children: React.ReactNode }) {
  const prefersReduced = usePrefersReducedMotion()
  const ref = useRef<HTMLDivElement>(null)
  
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start end', 'end start'],
  })

  // Map scroll 0→1 to translateY 50px→-50px
  const y = useTransform(
    scrollYProgress,
    [0, 1],
    prefersReduced ? [0, 0] : [50, -50],
  )

  return (
    <div ref={ref} className="overflow-hidden">
      <motion.div style={{ y }}>
        {children}
      </motion.div>
    </div>
  )
}
```

## Performance Guidelines

**Use will-change-transform**: Promotes element to GPU layer. Only add when actively animating (not on all elements).

**Avoid layout thrashing**: Read scroll position, batch DOM writes. Use `requestAnimationFrame` to batch writes.

**Test on slow devices**: Parallax that runs at 60fps on a MacBook Pro may stutter on an older phone. Test on actual mobile hardware.

**Limit depth**: Only 1-2 layers should move at different speeds. More layers = more confusion + performance cost.

**No parallax on text**: Moving text is harder to read. Only parallax background/decorative elements.

## When NOT to Use Parallax

- News sites, blogs, e-commerce product pages (distraction from content)
- Mobile-first sites (mobile has scroll-inertia that clashes with parallax)
- Accessibility-focused applications
- Pages where CLS score matters (parallax can cause CLS)

Use sparingly: landing pages, portfolios, hero sections.
