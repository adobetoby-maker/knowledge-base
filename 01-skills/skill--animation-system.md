# Skill: Consistent Animation System

## Overview
Animations without a system produce inconsistent timing — some buttons snap, some fade slowly, some spin forever. A design token system for duration and easing creates visual cohesion. `prefers-reduced-motion` must gate every animation to prevent vestibular disorders and respect user settings. Mixing Framer Motion and CSS transitions creates competing animation stacks — pick one per component.

## Implementation / Key Points

### Design Tokens (CSS Custom Properties)
```css
:root {
  /* Duration */
  --duration-fast: 150ms;     /* micro-interactions: hover state, button press */
  --duration-base: 200ms;     /* standard transitions: dropdowns, reveals */
  --duration-slow: 400ms;     /* page transitions, large reveals */
  --duration-xslow: 700ms;    /* hero animations, onboarding */

  /* Easing */
  --ease-default: cubic-bezier(0.4, 0, 0.2, 1);   /* material standard */
  --ease-in: cubic-bezier(0.4, 0, 1, 1);           /* elements leaving screen */
  --ease-out: cubic-bezier(0, 0, 0.2, 1);          /* elements entering screen */
  --ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1); /* bouncy, for interactive feedback */
}
```

### Reduced Motion Respect
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```
This global rule catches CSS animations. For JavaScript animations, check separately:

```ts
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
```

### Framer Motion Variants Pattern
```tsx
const fadeInUp = {
  hidden: { opacity: 0, y: 16 },
  visible: {
    opacity: 1, y: 0,
    transition: { duration: 0.2, ease: [0.4, 0, 0.2, 1] }
  }
};

function Card({ children }: { children: React.ReactNode }) {
  const prefersReduced = useReducedMotion();  // framer-motion hook
  return (
    <motion.div
      variants={prefersReduced ? {} : fadeInUp}
      initial="hidden"
      animate="visible"
    >
      {children}
    </motion.div>
  );
}
```

### CSS Transitions (for Simple Cases)
```css
.button {
  transition:
    background-color var(--duration-fast) var(--ease-default),
    transform var(--duration-fast) var(--ease-spring);
}

.button:hover {
  transform: scale(1.02);
}

.button:active {
  transform: scale(0.98);
}
```

### Interactive Element Rule (< 400ms)
Any animation triggered by user interaction (click, hover, focus) must complete within 400ms. Animations longer than 400ms feel like lag, not motion. Reserve slow animations (400ms+) for autonomous reveals — page transitions, hero sequences.

### Stagger Children Pattern
```tsx
const containerVariants = {
  visible: { transition: { staggerChildren: 0.05 } }
};

const itemVariants = {
  hidden: { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.15 } }
};

function List({ items }) {
  return (
    <motion.ul variants={containerVariants} initial="hidden" animate="visible">
      {items.map(item => (
        <motion.li key={item.id} variants={itemVariants}>{item.name}</motion.li>
      ))}
    </motion.ul>
  );
}
```

## Key Rules
- All durations and easing values must come from CSS custom properties — never hardcode `200ms`.
- Respect `prefers-reduced-motion` — both via CSS media query and the Framer Motion `useReducedMotion` hook.
- Never mix Framer Motion and CSS transitions on the same element — they fight each other.
- Interactive animations (hover, click) must complete in < 400ms.
- Use `ease-out` for entering elements (deceleration feels natural), `ease-in` for exiting.
- `ease-spring` for interactive feedback (button press, drag release) — it communicates physicality.
- Looping animations (spinners, pulses) must respect reduced motion by stopping.
