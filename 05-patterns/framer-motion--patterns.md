# Framer Motion Patterns

**When:** Building animated UI in React. Page transitions, component enter/exit, scroll-triggered reveals, gesture-based interactions.
**Rule:** Framer Motion is the right tool for complex React animations. For simple hover/transition effects, CSS is lighter. Use Framer Motion when you need orchestration, gestures, or shared layout animations.

## Installation and Basic Setup
```bash
npm install framer-motion
```

## Fade In / Slide Up (most common)
```typescript
import { motion } from 'framer-motion'

function Card({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
    >
      {children}
    </motion.div>
  )
}
```

## Staggered List Animation
```typescript
const container = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: {
      staggerChildren: 0.08  // 80ms between each child
    }
  }
}

const item = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.3 } }
}

function ServiceList({ services }: { services: Service[] }) {
  return (
    <motion.ul variants={container} initial="hidden" animate="show">
      {services.map(service => (
        <motion.li key={service.id} variants={item}>
          {service.name}
        </motion.li>
      ))}
    </motion.ul>
  )
}
```

## Scroll-Triggered Animation
```typescript
import { motion, useInView } from 'framer-motion'
import { useRef } from 'react'

function RevealSection({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: '-50px' })
  
  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 40 }}
      animate={inView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.6 }}
    >
      {children}
    </motion.div>
  )
}
```

## Page Transitions (App Router)
```typescript
// components/PageTransition.tsx
'use client'
import { motion, AnimatePresence } from 'framer-motion'
import { usePathname } from 'next/navigation'

export function PageTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  
  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={pathname}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={{ duration: 0.2 }}
      >
        {children}
      </motion.div>
    </AnimatePresence>
  )
}
```

## Hover / Tap Interactions
```typescript
<motion.button
  whileHover={{ scale: 1.05, y: -2 }}
  whileTap={{ scale: 0.98 }}
  transition={{ type: 'spring', stiffness: 400, damping: 17 }}
>
  Book Now
</motion.button>
```

## Shared Layout Animation (smooth transitions between elements)
```typescript
// Both elements have matching layoutId
// Framer Motion animates between them smoothly
<motion.div layoutId="selected-indicator" />
```

## Reduced Motion — Always Add
```typescript
import { useReducedMotion } from 'framer-motion'

function AnimatedCard({ children }) {
  const reducedMotion = useReducedMotion()
  
  return (
    <motion.div
      initial={{ opacity: 0, y: reducedMotion ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reducedMotion ? 0 : 0.4 }}
    >
      {children}
    </motion.div>
  )
}
```

## Where It's Used in This Stack
`orthobiologic-pathways` uses Framer Motion extensively for page animations and 3D transitions. See `components/` for patterns specific to that project.
