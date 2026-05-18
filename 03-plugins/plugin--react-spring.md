# Plugin: React Spring

## Overview

Physics-based animation library for React. Unlike CSS transitions (duration + easing), spring animations feel natural because they simulate mass and tension. Use `@react-spring/web` for DOM/SVG, not the base package. Prefer `useSpring` for single elements, `useTransition` for lists entering/leaving, `useTrail` for staggered groups.

## Installation

```bash
npm install @react-spring/web
```

## useSpring — Single Element

```tsx
import { useSpring, animated } from '@react-spring/web'

// Toggle animation
function FadeToggle({ visible, children }: { visible: boolean; children: React.ReactNode }) {
  const springs = useSpring({
    opacity: visible ? 1 : 0,
    transform: visible ? 'translateY(0px)' : 'translateY(-10px)',
    config: { tension: 300, friction: 25 },
  })

  return (
    <animated.div style={springs}>
      {children}
    </animated.div>
  )
}
```

`animated.div` is the key — it receives animated values and applies them without re-rendering React.

## Imperative Control with useSpring

```tsx
function HoverCard() {
  const [springs, api] = useSpring(() => ({
    scale: 1,
    shadow: 0,
    config: { tension: 400, friction: 20 },
  }))

  return (
    <animated.div
      style={{
        scale: springs.scale,
        boxShadow: springs.shadow.to(s => `0 ${s}px ${s * 2}px rgba(0,0,0,0.15)`),
      }}
      onMouseEnter={() => api.start({ scale: 1.05, shadow: 20 })}
      onMouseLeave={() => api.start({ scale: 1, shadow: 0 })}
      className="rounded-xl p-6 bg-white cursor-pointer"
    >
      Content
    </animated.div>
  )
}
```

## useTransition — Enter/Leave Animations

```tsx
import { useTransition, animated } from '@react-spring/web'

function NotificationList({ notifications }: { notifications: Notification[] }) {
  const transitions = useTransition(notifications, {
    keys: n => n.id,
    from:  { opacity: 0, transform: 'translateX(100%)', height: 0 },
    enter: { opacity: 1, transform: 'translateX(0%)',   height: 72 },
    leave: { opacity: 0, transform: 'translateX(100%)', height: 0 },
    config: { tension: 280, friction: 22 },
  })

  return (
    <div className="fixed top-4 right-4 space-y-2">
      {transitions((style, item) => (
        <animated.div style={style} key={item.id} className="overflow-hidden">
          <NotificationItem notification={item} />
        </animated.div>
      ))}
    </div>
  )
}
```

## useTrail — Staggered List

```tsx
import { useTrail, animated } from '@react-spring/web'

function FeatureList({ items }: { items: string[] }) {
  const trail = useTrail(items.length, {
    from: { opacity: 0, x: -20 },
    to:   { opacity: 1, x: 0 },
    config: { tension: 200, friction: 20 },
    delay: 100,
  })

  return (
    <ul>
      {trail.map((style, i) => (
        <animated.li key={i} style={style} className="flex items-center gap-2 py-2">
          <span>✓</span> {items[i]}
        </animated.li>
      ))}
    </ul>
  )
}
```

## Config Presets

```ts
import { config } from '@react-spring/web'

config.default   // { tension: 170, friction: 26 }
config.gentle    // { tension: 120, friction: 14 }
config.wobbly    // { tension: 180, friction: 12 }
config.stiff     // { tension: 210, friction: 20 }
config.slow      // { tension: 280, friction: 60 }
config.molasses  // { tension: 280, friction: 120 }
```

## Respecting reduced-motion

```tsx
import { useReducedMotion } from '@react-spring/web'

function AnimatedModal({ open, children }) {
  const prefersReduced = useReducedMotion()

  const springs = useSpring({
    opacity: open ? 1 : 0,
    transform: open ? 'scale(1)' : 'scale(0.95)',
    config: prefersReduced ? { duration: 0 } : config.gentle,
  })

  // ...
}
```

## Key Rules

- Always use `animated.*` elements — regular `<div>` doesn't receive animated values.
- Spring animations don't have a fixed duration — they settle when velocity reaches near-zero. Use `config.duration` to force a fixed time (but this loses the physics feel).
- `useTransition` requires a `keys` function — without it, React Spring can't track which items are entering vs leaving.
- Don't animate `height: auto` directly — animate to a measured pixel value or use `useResizeObserver` + `useSpring`.
- `api.stop()` halts mid-animation; `api.set()` jumps without animating — useful for position sync.
