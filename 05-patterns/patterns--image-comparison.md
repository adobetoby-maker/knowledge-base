# Image Comparison Slider

## Why the Split Reveal Pattern

A draggable divider between two overlaid images is more engaging than toggling or side-by-side layout: the user controls exactly how much of each image is revealed, which makes differences tangible. Two overlapping approaches exist — clip-path and overflow — each with different trade-offs.

## Clip-Path vs Overflow Approach

**Clip-path**: Both images are position:absolute in a shared container. The "after" image gets `clip-path: inset(0 X% 0 0)` where X is derived from divider position. GPU-accelerated, no DOM reflow. Preferred.

**Overflow + transform**: The "after" image is clipped by a wrapper with `overflow:hidden` and a fixed width that shrinks as the divider moves. More browser-compatible but causes layout recalculation on every drag event — avoid on low-end devices.

```tsx
// clip-path approach — both images fill the same container
<div ref={containerRef} className="relative w-full aspect-video overflow-hidden select-none">
  {/* Base image — always fully visible */}
  <img src={before} className="absolute inset-0 w-full h-full object-cover" alt="Before" />
  
  {/* Top image — clipped to reveal portion */}
  <img
    src={after}
    className="absolute inset-0 w-full h-full object-cover"
    style={{ clipPath: `inset(0 ${100 - position}% 0 0)` }}
    alt="After"
  />

  {/* Divider line + handle */}
  <div
    className="absolute top-0 bottom-0 w-0.5 bg-white cursor-ew-resize"
    style={{ left: `${position}%` }}
    onPointerDown={handlePointerDown}
    role="slider"
    aria-valuemin={0}
    aria-valuemax={100}
    aria-valuenow={Math.round(position)}
    aria-label="Comparison slider"
    tabIndex={0}
    onKeyDown={handleKeyDown}
  >
    <div className="absolute top-1/2 -translate-x-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-white shadow-lg flex items-center justify-center">
      {/* ◀ ▶ icon */}
    </div>
  </div>
</div>
```

## Pointer Events for Touch + Mouse

Use `setPointerCapture` so dragging outside the container keeps working. `onPointerMove` fires for both mouse and touch — no separate touch handler needed.

```tsx
const handlePointerDown = (e: React.PointerEvent) => {
  e.currentTarget.setPointerCapture(e.pointerId)
  setDragging(true)
}

const handlePointerMove = (e: React.PointerEvent) => {
  if (!dragging || !containerRef.current) return
  const rect = containerRef.current.getBoundingClientRect()
  const x = Math.max(0, Math.min(e.clientX - rect.left, rect.width))
  setPosition((x / rect.width) * 100)
}

const handlePointerUp = () => setDragging(false)
```

Attach `onPointerMove` and `onPointerUp` to the *container*, not the handle — so the drag continues even if the cursor outpaces the handle element.

## Keyboard Accessibility

The divider handle is a `role="slider"` with `tabIndex={0}`. Arrow keys move it in 1% increments; Shift+Arrow moves 10% at a time. This satisfies WCAG 2.1 for interactive controls.

```tsx
const handleKeyDown = (e: React.KeyboardEvent) => {
  const step = e.shiftKey ? 10 : 1
  if (e.key === 'ArrowLeft') setPosition(p => Math.max(0, p - step))
  if (e.key === 'ArrowRight') setPosition(p => Math.min(100, p + step))
}
```

## Lazy Loading Both Images

Preloading the "after" image eagerly wastes bandwidth if users never scroll to the component. Use `loading="lazy"` on both, but set `fetchpriority="low"` on the hidden-by-default image. Alternatively, use Intersection Observer to start loading only when the container enters the viewport — avoids the browser's built-in lazy load delay on images that are initially clipped out of view.

```tsx
const [shouldLoad, setShouldLoad] = useState(false)
// IntersectionObserver on containerRef → setShouldLoad(true)
// Only render <img> tags once shouldLoad is true
```

## Labels

Add small `<span>` badges (Before / After) anchored to left and right edges. Fade them out after 2 seconds of inactivity so they don't obstruct the content. These help users who don't immediately recognize the pattern.

## Key Rules

- Use `clip-path` over overflow+transform — it's GPU-accelerated and avoids reflow on every drag frame
- `setPointerCapture` is non-negotiable for reliable drag behavior across touch and mouse
- The divider handle must be `role="slider"` with `aria-valuenow` — without it, screen reader users cannot interact with the control
- Never attach `onPointerMove` to the handle itself — attach to the container so fast drags don't "lose" the handler
- Lazy-load both images but use IntersectionObserver rather than relying on `loading="lazy"` for clipped images, since the browser may not treat the clipped image as truly "off-screen"
