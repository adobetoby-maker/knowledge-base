# Pattern: Staggered List Animation

## Overview

Staggered animations reveal list items one after another with a small delay, creating a cascade effect. Used in: landing page feature lists, navigation menus, search results appearing. Avoids the "wall of content" that appears all at once.

## CSS-Only Stagger (Simplest)

```tsx
interface Feature {
  icon: string
  title: string
  description: string
}

export function FeatureList({ features }: { features: Feature[] }) {
  return (
    <ul className="space-y-4">
      {features.map((feature, i) => (
        <li
          key={feature.title}
          className="opacity-0 translate-y-4 animate-fade-in-up"
          style={{ animationDelay: `${i * 100}ms`, animationFillMode: 'forwards' }}
        >
          <div className="flex gap-3">
            <span>{feature.icon}</span>
            <div>
              <h3 className="font-medium">{feature.title}</h3>
              <p className="text-gray-600">{feature.description}</p>
            </div>
          </div>
        </li>
      ))}
    </ul>
  )
}
```

```css
/* globals.css */
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in-up {
  animation: fadeInUp 0.4s ease-out;
}
```

Limitation: animates on every render. Use only for initial page load, not for dynamic lists.

## Intersection Observer Stagger (Animates When Visible)

```tsx
import { useEffect, useRef, useState } from 'react'

export function StaggeredList({ items }: { items: React.ReactNode[] }) {
  const containerRef = useRef<HTMLUListElement>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true)
          observer.disconnect()
        }
      },
      { threshold: 0.1 },
    )

    if (containerRef.current) observer.observe(containerRef.current)
    return () => observer.disconnect()
  }, [])

  return (
    <ul ref={containerRef} className="space-y-3">
      {items.map((item, i) => (
        <li
          key={i}
          className="transition-all duration-500"
          style={{
            opacity: visible ? 1 : 0,
            transform: visible ? 'translateY(0)' : 'translateY(20px)',
            transitionDelay: visible ? `${i * 80}ms` : '0ms',
          }}
        >
          {item}
        </li>
      ))}
    </ul>
  )
}
```

The delay only applies on entry (not exit) — the section appears staggered when scrolled into view, but disappears all at once when scrolled away.

## Framer Motion Stagger

Most flexible — handles mount/unmount and repeated animations:

```tsx
import { motion } from 'framer-motion'

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.08,     // Delay between children
      delayChildren: 0.2,        // Initial delay before first child
    },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: 'easeOut' },
  },
}

export function AnimatedList({ items }: { items: React.ReactNode[] }) {
  return (
    <motion.ul
      variants={containerVariants}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: '-50px' }}
    >
      {items.map((item, i) => (
        <motion.li key={i} variants={itemVariants}>
          {item}
        </motion.li>
      ))}
    </motion.ul>
  )
}
```

`whileInView` + `once: true` means the stagger plays once when the list scrolls into view, then doesn't replay.

## Stagger Timing Guidelines

| List size | Delay per item |
|-----------|---------------|
| 3-5 items | 80-120ms |
| 6-10 items | 50-80ms |
| 11-20 items | 30-50ms |
| 20+ items | 10-20ms (or skip stagger) |

For large lists (20+), stagger becomes too slow — last items take 2+ seconds to appear. Use a smaller delay or group items in batches of 3.

## Reduced Motion

```tsx
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

const itemVariants = {
  hidden: prefersReduced ? {} : { opacity: 0, y: 16 },
  visible: prefersReduced ? {} : { opacity: 1, y: 0, transition: { duration: 0.4 } },
}
```

When reduced motion is preferred, render items immediately at full opacity with no transform — skip animation entirely rather than "slow it down".
