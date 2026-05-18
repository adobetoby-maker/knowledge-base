# Pattern: Swipeable Cards (Tinder-style)

## Overview

Cards that can be swiped left/right with gesture recognition. Used for review queues, recommendation feeds, quick decisions. Key challenge: smooth drag tracking, direction detection, snap animation back or off-screen.

## With react-tinder-card

```tsx
import TinderCard from 'react-tinder-card'

function SwipeQueue({ items, onSwipe }: {
  items: Item[]
  onSwipe: (item: Item, direction: 'left' | 'right') => void
}) {
  return (
    <div className="relative h-96 w-72 mx-auto">
      {items.map(item => (
        <TinderCard
          key={item.id}
          onSwipe={dir => onSwipe(item, dir as 'left' | 'right')}
          preventSwipe={['up', 'down']}
          className="absolute w-full"
        >
          <div className="bg-white rounded-2xl shadow-lg p-6 h-96 select-none">
            <h3>{item.title}</h3>
            <p>{item.description}</p>
          </div>
        </TinderCard>
      ))}
    </div>
  )
}
```

## Custom Implementation with @use-gesture/react

```tsx
import { animated, useSpring } from '@react-spring/web'
import { useDrag } from '@use-gesture/react'

function SwipeCard({ item, onSwipe }: { item: Item; onSwipe: (dir: 'left' | 'right') => void }) {
  const SWIPE_THRESHOLD = 120

  const [{ x, y, rotation, opacity }, api] = useSpring(() => ({
    x: 0, y: 0, rotation: 0, opacity: 1,
  }))

  const bind = useDrag(({ down, movement: [mx, my], velocity: [vx], direction: [dx] }) => {
    const trigger = Math.abs(mx) > SWIPE_THRESHOLD || vx > 0.5

    if (!down && trigger) {
      const dir = mx > 0 ? 'right' : 'left'
      // Fly off screen
      api.start({
        x: (200 + window.innerWidth) * dx,
        y: my,
        opacity: 0,
        rotation: mx / 8,
      })
      setTimeout(() => onSwipe(dir), 300)
    } else if (!down) {
      // Spring back to center
      api.start({ x: 0, y: 0, rotation: 0, opacity: 1 })
    } else {
      // Follow finger
      api.start({
        x: mx,
        y: my,
        rotation: mx / 20,
        immediate: true,
      })
    }
  })

  return (
    <animated.div
      {...bind()}
      style={{ x, y, rotateZ: rotation, opacity, touchAction: 'none' }}
      className="absolute w-full cursor-grab active:cursor-grabbing"
    >
      <div className="bg-white rounded-2xl shadow-lg p-6 h-80 select-none">
        {item.title}
      </div>
    </animated.div>
  )
}
```

## Visual Accept/Reject Indicators

Show color feedback as the user drags:

```tsx
// Inside the card during drag
const swipeDirection = mx > 0 ? 'right' : 'left'
const swipeStrength = Math.min(Math.abs(mx) / SWIPE_THRESHOLD, 1)

<div
  className="absolute inset-0 rounded-2xl pointer-events-none transition-none"
  style={{
    backgroundColor: swipeDirection === 'right'
      ? `rgba(34, 197, 94, ${swipeStrength * 0.3})`  // green
      : `rgba(239, 68, 68, ${swipeStrength * 0.3})`,   // red
  }}
/>
{/* Accept / Reject stamp */}
{mx > 40 && <span className="absolute top-8 left-8 text-green-500 font-bold text-2xl rotate-[-20deg] border-2 border-green-500 px-2 py-1 rounded">YES</span>}
{mx < -40 && <span className="absolute top-8 right-8 text-red-500 font-bold text-2xl rotate-[20deg] border-2 border-red-500 px-2 py-1 rounded">NOPE</span>}
```

## Keyboard/Button Fallback

For accessibility — also needed for users who can't swipe:

```tsx
<div className="flex gap-4 justify-center mt-4">
  <button onClick={() => triggerSwipe('left')} className="p-3 rounded-full border-2 border-red-400 hover:bg-red-50">✕</button>
  <button onClick={() => triggerSwipe('right')} className="p-3 rounded-full border-2 border-green-400 hover:bg-green-50">✓</button>
</div>
```

## Key Rules

- `touchAction: 'none'` prevents the browser from intercepting the touch events for scrolling.
- `select-none` prevents text selection during drag.
- Render the entire stack (all cards in `items`) with absolute positioning — cards behind the front are partially visible for depth effect.
- `preventSwipe={['up', 'down']}` is important — users will accidentally swipe vertically on mobile.
