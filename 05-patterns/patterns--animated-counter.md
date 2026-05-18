# Pattern: Animated Number Counter

## Overview
Linear count-up animations feel robotic — numbers increment at a constant rate until they abruptly stop. Spring physics (fast at first, decelerating to the target) feel natural. A floating-point step size causes the animation to "bounce" around the final value or never land exactly on it. Users with vestibular disorders can be harmed by motion, so `prefers-reduced-motion` is a hard requirement.

## Implementation

```tsx
// useCountUp.ts — custom RAF implementation with spring deceleration
import { useEffect, useRef, useState } from 'react'

interface CountUpOptions {
  from?: number
  to: number
  duration?: number  // ms — ignored when spring is true
  spring?: boolean   // spring physics vs linear
  decimals?: number
}

export function useCountUp({
  from = 0,
  to,
  duration = 1200,
  spring = true,
  decimals = 0,
}: CountUpOptions) {
  const [value, setValue] = useState(from)
  const rafRef = useRef<number>()
  const startRef = useRef<number>()

  useEffect(() => {
    // Respect prefers-reduced-motion — skip animation entirely
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduced) {
      setValue(to)
      return
    }

    if (from === to) {
      setValue(to)
      return
    }

    let current = from
    startRef.current = undefined

    function tick(timestamp: number) {
      if (!startRef.current) startRef.current = timestamp
      const elapsed = timestamp - startRef.current

      if (spring) {
        // Exponential easing: fast start, decelerates to target
        // The "spring constant" 0.008 controls how fast it decelerates
        // Larger = faster spring, smaller = more gentle
        const progress = 1 - Math.exp(-0.008 * elapsed)
        current = from + (to - from) * progress

        // Stop condition: when we're within 0.5 of the target
        // WITHOUT this, floating-point never reaches exactly `to`
        if (Math.abs(to - current) < 0.5) {
          setValue(to)  // snap to exact target
          return
        }
      } else {
        // Linear
        const progress = Math.min(elapsed / duration, 1)
        current = from + (to - from) * progress

        if (progress >= 1) {
          setValue(to)  // snap to exact target
          return
        }
      }

      // Round to specified decimal places for display
      setValue(parseFloat(current.toFixed(decimals)))
      rafRef.current = requestAnimationFrame(tick)
    }

    rafRef.current = requestAnimationFrame(tick)

    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
    }
  }, [from, to, duration, spring, decimals])

  return value
}
```

```tsx
// AnimatedCounter.tsx — only animates when entering the viewport
import { useEffect, useRef, useState } from 'react'
import { useCountUp } from './useCountUp'

interface AnimatedCounterProps {
  value: number
  prefix?: string     // e.g. '$'
  suffix?: string     // e.g. 'K' or '%'
  decimals?: number
  duration?: number
  className?: string
}

export function AnimatedCounter({
  value,
  prefix = '',
  suffix = '',
  decimals = 0,
  duration = 1200,
  className,
}: AnimatedCounterProps) {
  const [hasEntered, setHasEntered] = useState(false)
  const containerRef = useRef<HTMLSpanElement>(null)

  // Only start animation when element enters the viewport
  // Animating off-screen is wasted work — and users miss it
  useEffect(() => {
    const el = containerRef.current
    if (!el) return

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setHasEntered(true)
          observer.disconnect()  // only animate once
        }
      },
      { threshold: 0.1 }  // 10% visible is enough to trigger
    )

    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  // Count from 0 only after element has entered viewport
  const displayValue = useCountUp({
    from: 0,
    to: hasEntered ? value : 0,
    duration,
    spring: true,
    decimals,
  })

  return (
    <span
      ref={containerRef}
      className={className}
      aria-label={`${prefix}${value}${suffix}`}  // Screen readers get the final value immediately
    >
      {prefix}{displayValue.toLocaleString()}{suffix}
    </span>
  )
}
```

```tsx
// react-spring alternative — if already using react-spring in the project
import { useSpring, animated } from '@react-spring/web'
import { useEffect, useRef, useState } from 'react'

export function SpringCounter({ value }: { value: number }) {
  const [inView, setInView] = useState(false)
  const ref = useRef<HTMLSpanElement>(null)

  useEffect(() => {
    const obs = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) { setInView(true); obs.disconnect() }
    }, { threshold: 0.1 })
    if (ref.current) obs.observe(ref.current)
    return () => obs.disconnect()
  }, [])

  const { val } = useSpring({
    val: inView ? value : 0,
    config: { mass: 1, tension: 200, friction: 40 },
    // react-spring handles prefers-reduced-motion via config
  })

  return (
    <animated.span ref={ref}>
      {val.to(v => Math.round(v).toLocaleString())}
    </animated.span>
  )
}
```

## Key Rules
- Check `prefers-reduced-motion` and skip animation entirely — snap directly to the final value instead.
- Use spring (exponential easing), not linear — the deceleration toward the target feels natural.
- Snap to exact target when close enough (`Math.abs(to - current) < 0.5`) — floating-point arithmetic will never reach `to` exactly on its own.
- Only start the animation when the element enters the viewport — use IntersectionObserver with `threshold: 0.1`.
- Set `aria-label` to the final numeric value so screen readers announce it immediately without waiting for animation.
- Cancel the `requestAnimationFrame` in the cleanup function to prevent state updates after unmount.
- Animate only once (disconnect the observer after first intersection) — re-animating every time the user scrolls past is irritating.
- Use `toLocaleString()` for display — it adds thousands separators appropriate for the user's locale.
