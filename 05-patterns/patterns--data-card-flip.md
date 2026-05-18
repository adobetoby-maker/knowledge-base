# Pattern: Data Card Flip

## Overview
A flip card uses CSS 3D transform to reveal additional information on the back face. It's appropriate when the front content is a summary and the back is supplementary detail — using it for primary navigation or required actions creates poor UX because the content is hidden by default. The `backface-visibility: hidden` CSS property prevents the back face from showing through the front, which is the most common implementation bug. Users who prefer reduced motion must never see rotation animations.

## Implementation

### CSS Setup
```css
/* Required CSS — works without any library */
.card-scene {
  perspective: 1000px;
}

.card-inner {
  position: relative;
  width: 100%;
  height: 100%;
  transition: transform 0.5s ease;
  transform-style: preserve-3d;
}

.card-inner.is-flipped {
  transform: rotateY(180deg);
}

/* Reduced motion: skip rotation, use fade instead */
@media (prefers-reduced-motion: reduce) {
  .card-inner {
    transition: none;
  }
  .card-back {
    display: none;
  }
  .card-inner.is-flipped .card-front {
    display: none;
  }
  .card-inner.is-flipped .card-back {
    display: block;
  }
}

.card-front,
.card-back {
  position: absolute;
  inset: 0;
  backface-visibility: hidden;   /* Critical — prevents back face bleeding through */
  -webkit-backface-visibility: hidden; /* Safari */
}

.card-back {
  transform: rotateY(180deg);
}
```

### React Component
```tsx
import { useState, useId } from 'react'

interface FlipCardProps {
  front: React.ReactNode
  back: React.ReactNode
  className?: string
  flipTrigger?: 'button' | 'click' // 'button' = explicit button, 'click' = click anywhere
}

function FlipCard({
  front,
  back,
  className = '',
  flipTrigger = 'button',
}: FlipCardProps) {
  const [isFlipped, setIsFlipped] = useState(false)
  const id = useId()
  const frontId = `${id}-front`
  const backId = `${id}-back`

  return (
    // aria-expanded describes the flip state
    <div
      className={`card-scene ${className}`}
      aria-expanded={isFlipped}
      aria-controls={isFlipped ? backId : frontId}
    >
      <div
        className={`card-inner ${isFlipped ? 'is-flipped' : ''}`}
        onClick={flipTrigger === 'click' ? () => setIsFlipped(!isFlipped) : undefined}
      >
        {/* Front face */}
        <div
          id={frontId}
          className="card-front"
          aria-hidden={isFlipped}
        >
          {front}

          {flipTrigger === 'button' && (
            <button
              type="button"
              onClick={() => setIsFlipped(true)}
              aria-label="Show details"
              className="mt-2 text-sm text-blue-600 underline"
            >
              See details
            </button>
          )}
        </div>

        {/* Back face */}
        <div
          id={backId}
          className="card-back"
          aria-hidden={!isFlipped}
        >
          {back}

          {flipTrigger === 'button' && (
            <button
              type="button"
              onClick={() => setIsFlipped(false)}
              aria-label="Return to summary"
              className="mt-2 text-sm text-blue-600 underline"
            >
              ← Back
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
```

### Usage
```tsx
<FlipCard
  className="w-64 h-40"
  front={
    <div className="p-4 bg-white rounded-lg border h-full">
      <h3 className="font-semibold">Product A</h3>
      <p className="text-2xl font-bold mt-2">$49</p>
      <p className="text-gray-500 text-sm">3 variants</p>
    </div>
  }
  back={
    <div className="p-4 bg-blue-50 rounded-lg border h-full">
      <h3 className="font-semibold text-sm mb-2">Specs</h3>
      <dl className="text-xs space-y-1">
        <dt>SKU</dt><dd>PRD-001</dd>
        <dt>Weight</dt><dd>0.5kg</dd>
        <dt>In stock</dt><dd>142 units</dd>
      </dl>
    </div>
  }
/>
```

### Detecting Reduced Motion in JS (for programmatic use)
```tsx
function prefersReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

// When you need to control flip programmatically
function flipWithMotionCheck(setFlipped: (v: boolean) => void, value: boolean) {
  if (prefersReducedMotion()) {
    // Skip animation — just set state
    setFlipped(value)
  } else {
    setFlipped(value)
  }
}
```

## Key Rules
- `backface-visibility: hidden` on BOTH front and back faces — missing it on either causes the opposite face to bleed through on some browsers
- `transform-style: preserve-3d` on the inner container, not the outer wrapper — applying it to the wrong element breaks the 3D context
- `perspective` should be on the outer container, not the flipping element — it needs to be the parent of the 3D-transformed child
- For `prefers-reduced-motion: reduce`, replace rotation with show/hide — never just shorten the animation duration; rotation is the motion itself
- `aria-hidden={isFlipped}` on front, `aria-hidden={!isFlipped}` on back — screen readers must not read both faces simultaneously
- Use `aria-expanded` + `aria-controls` on the container — this is the accessible pattern for showing/hiding content panels
- "Click anywhere to flip" is only appropriate for decorative or non-essential content — primary interactions need explicit buttons
- Card height must be fixed — if front and back have different heights, the layout shifts on flip, which is disorienting
