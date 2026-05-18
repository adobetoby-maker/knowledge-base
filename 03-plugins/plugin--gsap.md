# Plugin: GSAP (GreenSock Animation Platform)

## Overview

GSAP is the industry standard for complex, performant web animations. Use it when CSS transitions/animations reach their limits: sequenced animations, SVG morphing, scroll-driven effects, or cross-browser issues with CSS animations. The free tier covers most use cases; ScrollTrigger requires GSAP's Club membership for commercial use (verify current licensing).

## Installation

```bash
npm install gsap
```

## Basic Tweens

```ts
import gsap from 'gsap'

// Tween — animate to target
gsap.to('.box', { x: 200, duration: 0.5, ease: 'power2.out' })

// From — animate from starting values to current
gsap.from('.card', { opacity: 0, y: 30, duration: 0.4, ease: 'back.out(1.7)' })

// FromTo — explicit start and end
gsap.fromTo('.badge', { scale: 0 }, { scale: 1, duration: 0.3, ease: 'elastic.out(1, 0.5)' })
```

## Timeline (Sequencing)

The killer feature — chain animations without calculating manual delays:

```ts
const tl = gsap.timeline()

tl.from('.hero-title', { opacity: 0, y: 40, duration: 0.6 })
  .from('.hero-subtitle', { opacity: 0, y: 20, duration: 0.4 }, '-=0.2')  // Start 0.2s before previous ends
  .from('.hero-cta', { opacity: 0, scale: 0.9, duration: 0.3 }, '-=0.1')
  .from('.hero-image', { opacity: 0, x: 60, duration: 0.6 }, '<')  // '<' = start at same time as previous
```

## React Integration

```tsx
import { useRef, useEffect } from 'react'
import gsap from 'gsap'
import { useGSAP } from '@gsap/react'

// Recommended: useGSAP hook (auto-cleanup)
function HeroSection() {
  const containerRef = useRef<HTMLDivElement>(null)

  useGSAP(() => {
    gsap.from('.hero-item', {
      opacity: 0,
      y: 30,
      stagger: 0.1,
      duration: 0.5,
      ease: 'power3.out',
    })
  }, { scope: containerRef })  // Scopes selectors to this container

  return (
    <div ref={containerRef}>
      <h1 className="hero-item">Title</h1>
      <p className="hero-item">Subtitle</p>
      <button className="hero-item">CTA</button>
    </div>
  )
}
```

`useGSAP` kills animations on component unmount and re-runs on dependency change — equivalent to a cleanup-aware `useEffect`.

## ScrollTrigger

```ts
import { ScrollTrigger } from 'gsap/ScrollTrigger'
gsap.registerPlugin(ScrollTrigger)

gsap.from('.section-title', {
  opacity: 0,
  y: 50,
  scrollTrigger: {
    trigger: '.section-title',
    start: 'top 80%',  // When top of element hits 80% down the viewport
    end: 'bottom 20%',
    toggleActions: 'play none none reverse',
  },
})
```

## Reduced Motion Respect

```ts
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

gsap.defaults({
  duration: prefersReduced ? 0.01 : 0.5,
})

// Or skip animations entirely
if (!prefersReduced) {
  gsap.from('.animated', { opacity: 0, y: 30 })
}
```

## Stagger Pattern

```ts
gsap.from('.card', {
  opacity: 0,
  y: 20,
  stagger: {
    each: 0.08,       // Delay between each item
    from: 'start',    // 'start', 'end', 'center', 'random', or index
    ease: 'power1.in',
  },
  duration: 0.4,
  ease: 'power2.out',
})
```

## Key Rules

- Register plugins before use: `gsap.registerPlugin(ScrollTrigger)` — forgetting this causes silent failure.
- Use `useGSAP` in React instead of raw `useEffect` to get automatic cleanup and scope.
- Don't animate `width`/`height` for layout changes — this triggers reflow. Animate `scaleX`/`scaleY` instead (GPU-accelerated).
- GSAP outperforms CSS for complex sequences and JS-driven animations; CSS transitions are fine for simple hover states.
