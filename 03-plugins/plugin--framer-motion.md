# Plugin: Framer Motion

## What It Does

Framer Motion is the React animation library. It provides a declarative API for animations, gestures, drag interactions, layout animations, and scroll effects.

## Core Pattern

```typescript
import { motion } from 'framer-motion'

// Simple fade in
<motion.div
  initial={{ opacity: 0 }}
  animate={{ opacity: 1 }}
  transition={{ duration: 0.3 }}
>
  Content
</motion.div>

// Slide up on mount
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.4, ease: 'easeOut' }}
>
  Content
</motion.div>
```

## Exit Animations (AnimatePresence)

For elements that unmount, wrap with `AnimatePresence`:

```typescript
import { AnimatePresence, motion } from 'framer-motion'

<AnimatePresence>
  {isVisible && (
    <motion.div
      key="modal"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.2 }}
    >
      <Modal />
    </motion.div>
  )}
</AnimatePresence>
```

The `key` prop is required for AnimatePresence to track element identity.

## Scroll-Driven Animations

```typescript
import { motion, useScroll, useTransform } from 'framer-motion'
import { useRef } from 'react'

function ParallaxSection() {
  const ref = useRef(null)
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start end', 'end start']
  })
  
  const y = useTransform(scrollYProgress, [0, 1], ['0%', '-20%'])
  
  return (
    <section ref={ref}>
      <motion.div style={{ y }}>
        <img src="/hero.jpg" alt="Hero" />
      </motion.div>
    </section>
  )
}
```

`scrollYProgress` is 0 when the element enters viewport, 1 when it exits. Map it to any CSS property with `useTransform`.

## Viewport Trigger Animations

```typescript
<motion.div
  initial={{ opacity: 0, y: 30 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, amount: 0.3 }}
  transition={{ duration: 0.5 }}
>
  Animates when 30% is visible; once: true means it won't re-animate on scroll back
</motion.div>
```

## Stagger Children

```typescript
const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.1
    }
  }
}

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0 }
}

<motion.ul variants={containerVariants} initial="hidden" animate="visible">
  {items.map(item => (
    <motion.li key={item.id} variants={itemVariants}>
      {item.name}
    </motion.li>
  ))}
</motion.ul>
```

## Gesture Animations

```typescript
<motion.button
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  transition={{ type: 'spring', stiffness: 400, damping: 17 }}
>
  Click me
</motion.button>
```

## Layout Animations

```typescript
// When layout changes (list reordering, size changes), animate the change
<motion.div layout>
  Content that may change size/position
</motion.div>

// Animate shared elements between routes
<motion.div layoutId="hero-image">
  <img src={src} />
</motion.div>
```

`layout` automatically detects and animates position/size changes. No manual calculation needed.

## Reduced Motion — REQUIRED

Always check for reduced motion preference:

```typescript
import { useReducedMotion } from 'framer-motion'

function AnimatedComponent() {
  const shouldReduceMotion = useReducedMotion()
  
  return (
    <motion.div
      initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: shouldReduceMotion ? 0 : 0.4 }}
    >
      Content
    </motion.div>
  )
}
```

This is not optional — vestibular disorders make certain animations physically painful for some users.

## Performance: Use transform, not position

```typescript
// Wrong — triggers layout, expensive
animate={{ left: 100, top: 50 }}

// Right — GPU accelerated, cheap
animate={{ x: 100, y: 50 }}
```

Animate `x`, `y`, `scale`, `rotate`, `opacity`. Avoid animating `width`, `height`, `top`, `left`, `margin`, `padding` — these trigger layout recalculations.

## Video Review for Complex Animations

Screenshots cannot capture animation quality — they freeze mid-transition. Always use video review:
```bash
node ~/record.js 3007            # 30-second scroll review
node ~/record.js 3007 --slow     # 60s for detailed motion review
```
