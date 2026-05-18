# Failure: Framer Motion SSR Issues

## Overview
Framer Motion renders animations client-side, but Next.js and other SSR frameworks render the initial HTML on the server. The mismatch between server-rendered HTML and client-side animation state causes React hydration errors — the DOM doesn't match what the server sent. The most common triggers: `AnimatePresence` with inconsistent keys, `useMotionValue` initialized to a computed value, and `LazyMotion` loaded after first render.

## `AnimatePresence` Hydration Mismatch

`AnimatePresence` requires that keys match between server and client renders. If the key changes between SSR and hydration, React throws.

```tsx
// BAD — key derived from client-only state (different on server vs client)
'use client'
const [isOpen, setIsOpen] = useState(false)  // always false on server

<AnimatePresence>
  {isOpen && (
    <motion.div key={`modal-${Date.now()}`}>  {/* Date.now() differs! */}
      {children}
    </motion.div>
  )}
</AnimatePresence>

// GOOD — stable, predictable key
<AnimatePresence>
  {isOpen && (
    <motion.div key="modal">
      {children}
    </motion.div>
  )}
</AnimatePresence>
```

For list animations where items are added/removed:

```tsx
// Key must be stable across renders — use item ID, not array index
<AnimatePresence>
  {items.map(item => (
    <motion.li
      key={item.id}  // NOT key={index} — index changes when items are removed
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
    >
      {item.name}
    </motion.li>
  ))}
</AnimatePresence>
```

## `useMotionValue` Initialization

`useMotionValue` initializes on the client. If you read it during SSR to derive initial render state, you get a mismatch.

```tsx
// BAD — motionValue read during render
const x = useMotionValue(0)
const displayX = x.get()  // 0 on server, possibly non-zero on client after hydration

return <div style={{ transform: `translateX(${displayX}px)` }} />

// GOOD — use useState with same default for SSR compatibility
const [initialX] = useState(0)
const x = useMotionValue(initialX)  // server and client start at same value
```

## `LazyMotion` Must Load Before First Animation

`LazyMotion` reduces bundle size by loading animation features lazily, but if the features haven't loaded when the first animation triggers, the animation silently skips.

```tsx
// BAD — features may not be loaded when component first renders
import { LazyMotion, m } from 'framer-motion'
import { domAnimation } from 'framer-motion'

function App() {
  return (
    <LazyMotion features={domAnimation}>
      <m.div animate={{ opacity: 1 }}>  {/* may not animate on first load */}
        Content
      </m.div>
    </LazyMotion>
  )
}

// GOOD — load features asynchronously but ensure they're available before render
const loadFeatures = () => import('framer-motion').then(m => m.domAnimation)

function App() {
  return (
    <LazyMotion features={loadFeatures} strict>  {/* strict: warns if m. used before load */}
      <m.div animate={{ opacity: 1 }}>
        Content
      </m.div>
    </LazyMotion>
  )
}
```

## `motion.div` vs `m.div`

With `LazyMotion`, you must use `m.div` (not `motion.div`) — `motion.div` always loads the full bundle:

```tsx
import { LazyMotion, m } from 'framer-motion'  // m = lazy variant
import { motion } from 'framer-motion'           // motion = full bundle (works without LazyMotion)

// With LazyMotion: use m.*
<m.div animate={{ scale: 1.1 }} />

// Without LazyMotion: use motion.*
<motion.div animate={{ scale: 1.1 }} />
```

## Suppressing Hydration Warnings (Last Resort)

For animations driven by browser-only values (viewport, scroll position):

```tsx
function ScrollIndicator() {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])

  if (!mounted) return null  // don't render on server at all

  return <motion.div style={{ scaleX: scrollProgress }} />
}
```

## Key Rules
- `AnimatePresence` children must have stable, predictable keys — never `Date.now()`, `Math.random()`, or array index when items are removed
- `useMotionValue` initial value must be the same on server and client — don't compute from browser APIs
- `LazyMotion` with `strict` mode catches misuse (using `motion.*` instead of `m.*`)
- For browser-only animations: `useState(false)` + `useEffect(() => setMounted(true), [])` + early return `null` until mounted
- Framer Motion 11+ has improved SSR handling — check migration guide when upgrading
