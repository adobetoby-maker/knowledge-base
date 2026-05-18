# Which Animation Approach to Use

## Four Options Available

1. **Tailwind CSS transitions** — class-based, simple state changes
2. **Tailwind CSS animations** — keyframe animations via utility classes
3. **Framer Motion** — JavaScript-driven, physics-based, complex sequences
4. **CSS custom keyframes** — raw CSS for specialized performance needs

## Decision Guide

| Situation | Use |
|-----------|-----|
| Hover color change | Tailwind `hover:` + `transition-colors` |
| Button press feedback | Tailwind `active:scale-95 transition-transform` |
| Dropdown open/close | Tailwind `transition` + conditional `opacity-0/100` |
| Element entering viewport | Framer Motion `whileInView` |
| List items stagger in | Framer Motion `variants` with `staggerChildren` |
| Exit animations (unmounting) | Framer Motion `AnimatePresence` |
| Page transitions | Framer Motion `AnimatePresence` |
| Scroll-driven parallax | Framer Motion `useScroll` + `useTransform` |
| Loading spinner | Tailwind `animate-spin` |
| Skeleton pulse | Tailwind `animate-pulse` |
| Complex SVG path animation | CSS custom keyframes or Framer Motion |

## Tailwind Transitions (Simplest)

```typescript
// Hover state change
<button className="bg-blue-500 hover:bg-blue-600 transition-colors duration-200">
  Click me
</button>

// Toggle visibility
<div className={`transition-all duration-300 overflow-hidden ${
  isOpen ? 'max-h-96 opacity-100' : 'max-h-0 opacity-0'
}`}>
  {children}
</div>
```

Tailwind transitions: CSS-only, no JavaScript, zero bundle cost. Use for all simple state-based transitions.

## Framer Motion (Complex Interactions)

```typescript
'use client'
import { motion, AnimatePresence } from 'framer-motion'
import { useReducedMotion } from 'framer-motion'

// ALWAYS check reduced motion preference
const prefersReducedMotion = useReducedMotion()

// Enter/exit animation
<AnimatePresence>
  {isVisible && (
    <motion.div
      initial={{ opacity: 0, y: prefersReducedMotion ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: prefersReducedMotion ? 0 : -20 }}
      transition={{ duration: 0.2 }}
    >
      {content}
    </motion.div>
  )}
</AnimatePresence>
```

Use `useReducedMotion()` and disable/reduce animations for users who prefer reduced motion. This is an accessibility requirement.

## Framer Motion with `whileInView`

For scroll-triggered reveal animations:

```typescript
<motion.div
  initial={{ opacity: 0, y: 30 }}
  whileInView={{ opacity: 1, y: 0 }}
  viewport={{ once: true, margin: '-50px' }}
  transition={{ duration: 0.5 }}
>
  {content}
</motion.div>
```

`once: true` prevents re-triggering when scrolling back up.

## Stagger Children

```typescript
const containerVariants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.1 },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  show: { opacity: 1, y: 0 },
}

<motion.ul variants={containerVariants} initial="hidden" animate="show">
  {items.map(item => (
    <motion.li key={item.id} variants={itemVariants}>
      {item.name}
    </motion.li>
  ))}
</motion.ul>
```

## Performance Rules

- **Use `transform` not position** — `translate`, `scale`, `rotate` are GPU-composited; `top`, `left`, `width` cause layout recalculation
- **`will-change: transform`** only on elements actively animating; don't add it preventively
- **Avoid animating box-shadow** — use opacity on a pseudo-element instead
- **Test on mobile** — animations that look smooth on desktop can be janky on low-end phones

```typescript
// GOOD — GPU composited
<motion.div animate={{ x: 100, opacity: 0.5 }} />

// BAD — causes layout + paint
<motion.div animate={{ left: '100px', width: '200px' }} />
```

## Framer Motion in language-lens-elite (TanStack Start)

TanStack Start uses Vite + Cloudflare Workers. Framer Motion works normally on the client side. Server-side rendering of motion components requires importing from `framer-motion` (not a special build).

## Tailwind v4 Animation Utilities

Tailwind v4 uses CSS-first configuration. Custom animations go in globals.css:

```css
/* globals.css */
@keyframes slide-in {
  from { transform: translateX(-100%); opacity: 0; }
  to { transform: translateX(0); opacity: 1; }
}

@utility animate-slide-in {
  animation: slide-in 0.3s ease-out;
}
```

```html
<div class="animate-slide-in">Content</div>
```
