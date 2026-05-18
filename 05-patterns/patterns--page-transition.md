# Pattern: Page Transition Animations with Framer Motion

Animated transitions between routes. Done correctly: seamless, non-disorienting, and invisible to users who prefer reduced motion. Done wrong: layout shift during animation, double-rendering that causes flicker, and animations that replay on browser back.

## Why It Matters

Bare route changes are instantaneous and disorienting—the brain registers an abrupt scene cut. A 200ms fade or slide contextualizes the navigation direction (forward = slide left, back = slide right) and gives users a moment to orient. The motion must be subtle—transition animations that call attention to themselves are anti-patterns.

## AnimatePresence with `mode="wait"`

```tsx
// app/layout.tsx (Next.js App Router)
// Note: AnimatePresence must wrap the changing child, not the whole layout

'use client';
import { AnimatePresence, motion } from 'framer-motion';
import { usePathname } from 'next/navigation';

const pageVariants = {
  initial:  { opacity: 0, y: 8 },
  animate:  { opacity: 1, y: 0, transition: { duration: 0.2, ease: 'easeOut' } },
  exit:     { opacity: 0, y: -8, transition: { duration: 0.15, ease: 'easeIn' } },
};

export function PageTransitionWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={pathname}
        variants={pageVariants}
        initial="initial"
        animate="animate"
        exit="exit"
      >
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
```

`mode="wait"` makes the exiting page fully animate out before the entering page animates in. Without it, both pages render simultaneously, causing layout doubles and scroll jumps. `initial={false}` on `AnimatePresence` prevents the animation running on the first render (page load).

## Avoiding Layout Shift

The outgoing and incoming page elements occupy the same space during `mode="wait"`. Prevent the exiting page from taking up space during exit:

```tsx
// Exiting element should be position: absolute so it doesn't push content
const pageVariants = {
  exit: {
    opacity: 0,
    position: 'absolute' as const,
    top: 0,
    left: 0,
    right: 0,
  },
};
```

Or use `overflow: hidden` on the transition wrapper with a fixed height during transition:

```css
.transition-wrapper {
  position: relative;
  /* Clip exiting element that's positioned absolute */
  overflow: hidden;
}
```

## Directional Transitions

Slide direction based on navigation depth communicates hierarchy:

```ts
function useNavigationDirection() {
  const pathname = usePathname();
  const prevPathRef = useRef<string | null>(null);
  const [direction, setDirection] = useState<'forward' | 'back'>('forward');

  useEffect(() => {
    if (prevPathRef.current) {
      // Simple depth heuristic: more segments = forward
      const prevDepth = prevPathRef.current.split('/').length;
      const currDepth = pathname.split('/').length;
      setDirection(currDepth >= prevDepth ? 'forward' : 'back');
    }
    prevPathRef.current = pathname;
  }, [pathname]);

  return direction;
}

const slideVariants = (direction: 'forward' | 'back') => ({
  initial:  { x: direction === 'forward' ? 40 : -40, opacity: 0 },
  animate:  { x: 0, opacity: 1 },
  exit:     { x: direction === 'forward' ? -40 : 40, opacity: 0 },
});
```

## Shared Layout Animations

Use `layoutId` to animate shared elements across pages (e.g., a card that expands into a detail view):

```tsx
// In list view
<motion.div layoutId={`card-${item.id}`} className="card">
  <img src={item.image} />
  <h3>{item.title}</h3>
</motion.div>

// In detail view (different route)
<motion.div layoutId={`card-${item.id}`} className="card-detail">
  <img src={item.image} />
  <h1>{item.title}</h1>
  <p>{item.description}</p>
</motion.div>
```

Framer Motion animates the element from its position in the list to its position on the detail page. Both must use the same `layoutId`. Wrap both views in `AnimatePresence`.

## Reduced Motion

```tsx
import { useReducedMotion } from 'framer-motion';

function PageTransitionWrapper({ children }) {
  const shouldReduceMotion = useReducedMotion();
  const pathname = usePathname();

  const variants = shouldReduceMotion
    ? {
        initial: { opacity: 0 },
        animate: { opacity: 1, transition: { duration: 0.01 } },
        exit:    { opacity: 0, transition: { duration: 0.01 } },
      }
    : pageVariants;

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.div key={pathname} variants={variants} initial="initial" animate="animate" exit="exit">
        {children}
      </motion.div>
    </AnimatePresence>
  );
}
```

When `prefers-reduced-motion: reduce` is active, use an instant (near-zero duration) opacity transition instead of disabling animation entirely. A pure instant swap still feels abrupt—a 10ms fade is imperceptible but removes the jarring cut.

## Next.js App Router Caveat

In the App Router, `children` in the root layout can be a React Server Component. The `AnimatePresence` wrapper must be a Client Component. Keep the wrapper minimal—don't pull the whole layout into client territory.

## Key Rules

- **`mode="wait"`** prevents double-rendering of entering and exiting pages simultaneously.
- **`initial={false}`** on `AnimatePresence`—no animation on first page load.
- **`key={pathname}`** triggers re-mount (and therefore animation) on route change.
- **Position exiting element `absolute`** or use `overflow: hidden` to prevent layout shift.
- **Duration ≤200ms**—transitions should enhance, not delay navigation.
- **`useReducedMotion()`** from Framer Motion—respect the OS preference.
- **`layoutId`** for shared element transitions (card → detail)—requires same ID in both routes.
- **Don't animate scroll position**—restore scroll to top on navigation separately from the page fade.
