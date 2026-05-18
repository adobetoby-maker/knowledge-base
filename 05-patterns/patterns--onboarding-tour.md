# Pattern: Onboarding Tour / Guided Walkthrough

A product tour highlights specific UI elements in sequence to orient new users. Done wrong it blocks the UI, repositions on scroll, and re-annoys returning users. Done right it floats precisely over the target, steps forward/back, and never shows again once dismissed.

## Why It Matters

New users scan—they don't read docs. A tour converts ambient confusion into a 5-step guided path. The cost of a bad tour (annoying, mispositioned, re-showing) is higher than no tour—it erodes trust in the product itself.

## Core Implementation

### Step Config

```ts
interface TourStep {
  target: string;        // CSS selector for the anchor element
  title: string;
  body: string;
  placement?: 'top' | 'bottom' | 'left' | 'right';
}

const TOUR_STEPS: TourStep[] = [
  { target: '[data-tour="new-project"]', title: 'Create a project', body: 'Start here to...', placement: 'bottom' },
  { target: '[data-tour="invite"]',      title: 'Invite your team',  body: 'Add members by...', placement: 'right' },
];
```

Assign `data-tour` attributes to target elements—don't rely on class/id selectors that change. This decouples tour logic from component implementation.

### Popover Positioning

Use `floating-ui` (`@floating-ui/react`) for positioning—never compute `getBoundingClientRect()` manually. It handles scroll offsets, viewport collisions, and flip/shift automatically.

```tsx
import { useFloating, offset, flip, shift, arrow } from '@floating-ui/react';

function TourPopover({ step, anchorEl, onNext, onBack, onSkip }) {
  const arrowRef = useRef(null);
  const { refs, floatingStyles, middlewareData } = useFloating({
    placement: step.placement ?? 'bottom',
    middleware: [offset(12), flip(), shift({ padding: 8 }), arrow({ element: arrowRef })],
  });

  useEffect(() => {
    refs.setReference(anchorEl);
  }, [anchorEl]);

  return (
    <div ref={refs.setFloating} style={floatingStyles} className="tour-popover" role="dialog" aria-modal="false">
      <h3>{step.title}</h3>
      <p>{step.body}</p>
      <div className="tour-controls">
        {stepIndex > 0 && <button onClick={onBack}>Back</button>}
        <button onClick={onNext}>Next</button>
        <button onClick={onSkip} className="skip">Skip tour</button>
      </div>
    </div>
  );
}
```

### Highlight Overlay

The overlay creates focus. Use two layers: a full-screen dark backdrop with `pointer-events: none` and a transparent cutout over the target via `clip-path` or `box-shadow`. The `box-shadow` trick is simpler:

```css
.tour-highlight {
  position: fixed;
  pointer-events: none;
  border-radius: 4px;
  box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.55);
  z-index: 999;
  transition: all 200ms ease;
}
```

Position the highlight div by reading the target's `getBoundingClientRect()` and applying as `top/left/width/height`. Re-read on `resize` and `scroll`.

```ts
function getHighlightRect(selector: string) {
  const el = document.querySelector(selector);
  if (!el) return null;
  const { top, left, width, height } = el.getBoundingClientRect();
  return { top: top - 4, left: left - 4, width: width + 8, height: height + 8 };
}
```

### Step Sequence with Back/Skip

```tsx
function useTour(steps: TourStep[]) {
  const [index, setIndex] = useState(0);
  const [active, setActive] = useState(false);

  const next = () => index < steps.length - 1 ? setIndex(i => i + 1) : end();
  const back = () => setIndex(i => Math.max(0, i - 1));
  const skip = () => end();
  const end = () => {
    setActive(false);
    localStorage.setItem('tour_completed', '1');
  };

  return { step: steps[index], index, total: steps.length, active, next, back, skip, start: () => setActive(true) };
}
```

### Persistence — Don't Re-show to Returning Users

```ts
// On app load, check before launching tour
function shouldShowTour(): boolean {
  return !localStorage.getItem('tour_completed');
}

// In your root component or layout
useEffect(() => {
  if (shouldShowTour()) {
    // Small delay so layout is stable before measuring targets
    setTimeout(() => tourState.start(), 600);
  }
}, []);
```

Store completion both in `localStorage` (instant) and in the user's profile in the database so it persists across devices. The localStorage check prevents a flash on first load before the DB response arrives.

### Scroll Target Into View

If a step's target is off-screen, scroll it into view before positioning:

```ts
async function activateStep(selector: string) {
  const el = document.querySelector(selector);
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  // Wait for scroll to settle before measuring
  await new Promise(r => setTimeout(r, 350));
}
```

## Key Rules

- **Use `data-tour` attributes** on targets—not selectors tied to styling.
- **Use `floating-ui`** for popover positioning—never manual rect math.
- **`box-shadow` highlight** is the simplest full-page overlay with cutout.
- **Persist completion** in both localStorage (fast) and DB (cross-device).
- **Delay tour start** by ~600ms so layout renders before measuring targets.
- **Re-measure on resize/scroll**—highlight rect goes stale immediately.
- **Never re-show** to a user who dismissed or completed—check on mount, not on every render.
- **Provide Back, Next, and Skip**—users need an escape hatch at every step.
