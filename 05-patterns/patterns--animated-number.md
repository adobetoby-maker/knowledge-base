# Pattern: Animated Number (Count Up/Down)

## Overview

Numbers that animate when their value changes — metrics, scores, balances — create a strong sense of liveness. The wrong implementation either triggers on every render (causing phantom animations) or uses `setInterval` polling (janky, drops frames). The correct implementation responds only to value changes, uses `requestAnimationFrame` for smoothness, formats the number throughout animation, and stops instantly for users who prefer reduced motion.

## Implementation with `useSpring` (react-spring)

```tsx
import { useSpring, animated } from '@react-spring/web'

type AnimatedNumberProps = {
  value: number
  format?: (n: number) => string
  duration?: number  // ms — if omitted, derived from delta
}

export function AnimatedNumber({
  value,
  format = n => Math.round(n).toLocaleString(),
  duration,
}: AnimatedNumberProps) {
  const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  const spring = useSpring({
    from: { val: 0 },
    to: { val: value },
    config: {
      duration: prefersReduced ? 0 : (duration ?? deriveDuration(value)),
    },
    reset: false,  // don't reset to 0 on re-render, only animate the delta
  })

  return (
    <animated.span aria-live="polite" aria-atomic="true">
      {spring.val.to(n => format(n))}
    </animated.span>
  )
}

function deriveDuration(delta: number): number {
  // Short animation for small changes, longer for dramatic jumps
  if (delta < 100) return 400
  if (delta < 1000) return 800
  if (delta < 10000) return 1200
  return 1800
}
```

**Why duration based on delta:** A counter going from 1 to 2 animating for 2 seconds feels absurd. A counter going from 0 to 1,000,000 animating in 400ms is unreadable. Scaling duration to the magnitude of change makes the animation feel intentional rather than arbitrary.

## Raw Implementation (no external library)

When react-spring isn't available, use `requestAnimationFrame` directly:

```tsx
import { useEffect, useRef, useState } from 'react'

export function AnimatedNumber({ value, format = n => Math.round(n).toLocaleString() }: {
  value: number
  format?: (n: number) => string
}) {
  const [displayed, setDisplayed] = useState(value)
  const prevRef = useRef(value)
  const rafRef = useRef<number>()
  const startRef = useRef<number>()

  useEffect(() => {
    const prefersReduced = matchMedia('(prefers-reduced-motion: reduce)').matches

    if (prefersReduced) {
      setDisplayed(value)
      prevRef.current = value
      return
    }

    const from = prevRef.current
    const to = value
    const delta = Math.abs(to - from)
    const duration = deriveRawDuration(delta)

    function tick(now: number) {
      if (!startRef.current) startRef.current = now
      const elapsed = now - startRef.current
      const progress = Math.min(elapsed / duration, 1)

      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplayed(from + (to - from) * eased)

      if (progress < 1) {
        rafRef.current = requestAnimationFrame(tick)
      } else {
        prevRef.current = to
        startRef.current = undefined
      }
    }

    rafRef.current = requestAnimationFrame(tick)
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current)
      startRef.current = undefined
    }
  }, [value])

  return (
    <span aria-live="polite" aria-atomic="true">
      {format(displayed)}
    </span>
  )
}
```

## Formatting During Animation

Always pass the intermediate float through your formatter. If the number is a dollar amount, pass it through currency formatting so it reads "$1,234.56" mid-animation instead of "1234.5678". The formatter handles the "moving number" look naturally.

```ts
// Currency that counts up from $0 to $2,500.00
const format = (n: number) => new Intl.NumberFormat('en-US', {
  style: 'currency', currency: 'USD'
}).format(n)
```

## Accessibility

Screen readers should announce the final value, not every intermediate frame. `aria-live="polite"` with `aria-atomic="true"` batches announcements — the reader waits for the element to stop changing before reading it aloud.

## Responding Only to Value Changes

The component should not re-animate when a parent re-renders without changing the value. Both implementations above handle this correctly:
- react-spring: `reset: false` prevents animation restart on non-value renders
- Raw: `useEffect` depends only on `[value]`, so it only fires when `value` changes

## Key Rules

- Scale animation duration to the magnitude of the delta — small deltas animate fast, large deltas animate slower
- Use `requestAnimationFrame`, never `setInterval` — rAF syncs to display refresh; intervals drift and drop frames
- Format intermediate values through the final formatter — so "$1,234" appears during animation, not "1234.5"
- Respect `prefers-reduced-motion` — skip animation entirely (set value immediately, no transition)
- Use `aria-live="polite"` + `aria-atomic="true"` — announces the final value once, not every frame
- Animate delta only (`from: prevValue`), not always from 0 — avoids rewinding on partial updates
