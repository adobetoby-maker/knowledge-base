# Pattern: Gradient Card

## Overview

Cards with animated gradient borders or text use CSS `@keyframes` and `background-clip` to create visually rich UI without JavaScript. The two biggest failure modes are: using `background-position` animation (forces paint on every frame) and forgetting `prefers-reduced-motion` (makes users with vestibular disorders sick).

## Animated Gradient Border

Wrap the card in a container that holds the animated gradient, then use an inset pseudo-element to create the "hole" that shows the card background.

```tsx
// GradientCard.tsx
export function GradientCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="gradient-card-wrapper">
      <div className="gradient-card-inner">{children}</div>
    </div>
  )
}
```

```css
/* gradient-card.css */
.gradient-card-wrapper {
  position: relative;
  padding: 2px; /* border thickness */
  border-radius: 12px;
  background: linear-gradient(var(--angle), #6366f1, #ec4899, #f59e0b);
  animation: rotate-gradient 4s linear infinite;
}

@property --angle {
  syntax: '<angle>';
  initial-value: 0deg;
  inherits: false;
}

@keyframes rotate-gradient {
  to { --angle: 360deg; }
}

.gradient-card-inner {
  background: #fff;
  border-radius: 10px; /* 2px less than wrapper */
  padding: 1.5rem;
}

@media (prefers-reduced-motion: reduce) {
  .gradient-card-wrapper {
    animation: none;
    background: linear-gradient(135deg, #6366f1, #ec4899);
  }
}
```

**Why `@property --angle` not `background-position`:** Animating a CSS custom property registered with `@property` triggers only composite-layer updates — no layout or paint. Animating `background-position` triggers repaint on every frame, burning GPU cycles. The `@property` approach runs at 60fps even on mid-range mobile.

**Why `2px` padding not `border`:** CSS `border` cannot hold a gradient. The padding gap trick lets the gradient background show through as the "border."

## Gradient Text

```css
.gradient-heading {
  background: linear-gradient(90deg, #6366f1, #ec4899);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: transparent; /* fallback for non-webkit */
}
```

**Why `color: transparent` as fallback:** Some environments don't support `background-clip: text`. Setting `color: transparent` means text disappears (bad) instead of rendering black — include a `@supports` block to gate it:

```css
.gradient-heading {
  color: #6366f1; /* solid fallback */
}

@supports (background-clip: text) or (-webkit-background-clip: text) {
  .gradient-heading {
    background: linear-gradient(90deg, #6366f1, #ec4899);
    -webkit-background-clip: text;
    background-clip: text;
    -webkit-text-fill-color: transparent;
    color: transparent;
  }
}
```

## Hover Glow Effect (no animation)

For a static card that glows on hover — performant because it only touches `opacity` and `box-shadow` (which composites separately):

```css
.glow-card {
  transition: box-shadow 200ms ease;
}

.glow-card:hover {
  box-shadow:
    0 0 0 1px rgba(99, 102, 241, 0.3),
    0 0 20px rgba(99, 102, 241, 0.2),
    0 0 40px rgba(99, 102, 241, 0.1);
}
```

## Performance Rules

| Approach | Composite | Paint | Layout | Verdict |
|---|---|---|---|---|
| `@property` angle | ✓ | ✗ | ✗ | Use |
| `background-position` shift | ✗ | ✓ | ✗ | Avoid |
| `transform` + gradient | ✓ | ✗ | ✗ | Use |
| `filter: hue-rotate` | ✓ | ✗ | ✗ | Use |
| `color` / `background` JS interval | ✗ | ✓ | ✗ | Never |

`transform` and `opacity` are the only properties guaranteed to stay on the compositor thread. Everything else risks paint.

## Tailwind Equivalent

Tailwind doesn't natively support `@property` animations, but you can drop raw CSS in a component file or extend `tailwind.config.ts`:

```ts
// tailwind.config.ts
export default {
  theme: {
    extend: {
      animation: {
        'gradient-spin': 'rotate-gradient 4s linear infinite',
      },
      keyframes: {
        'rotate-gradient': {
          to: { '--angle': '360deg' },
        },
      },
    },
  },
}
```

## Key Rules

- Animate `--angle` via `@property`, not `background-position` — keeps animation off the paint thread
- Always provide `prefers-reduced-motion` fallback — a static gradient, never a frozen mid-animation frame
- Use `padding` not `border` for gradient borders — CSS borders can't hold gradients
- Gate `background-clip: text` with `@supports` — unsupported environments show invisible text otherwise
- Keep border-radius of inner element 2px smaller than wrapper to avoid corner bleed
- `box-shadow` glow on hover is free (compositor) — use it instead of color-shifting backgrounds
