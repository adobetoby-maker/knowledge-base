# Pattern: Image Zoom / Pan

## Overview

Allow users to zoom into images for detail inspection — product photos, maps, medical images, document scans. Two approaches: CSS transform-based (simpler, works for most cases) and canvas-based (needed for very large images). Lightbox is separate — zoom is about examining the current image in-place.

## CSS Transform Zoom

```tsx
function ZoomableImage({ src, alt }: { src: string; alt: string }) {
  const [scale, setScale] = useState(1)
  const [position, setPosition] = useState({ x: 0, y: 0 })
  const [isDragging, setIsDragging] = useState(false)
  const dragStart = useRef({ x: 0, y: 0, posX: 0, posY: 0 })
  const containerRef = useRef<HTMLDivElement>(null)

  function handleWheel(e: React.WheelEvent) {
    e.preventDefault()
    const delta = e.deltaY > 0 ? 0.9 : 1.1
    setScale(prev => Math.max(1, Math.min(8, prev * delta)))
  }

  function handleMouseDown(e: React.MouseEvent) {
    if (scale === 1) return
    setIsDragging(true)
    dragStart.current = { x: e.clientX, y: e.clientY, posX: position.x, posY: position.y }
  }

  function handleMouseMove(e: React.MouseEvent) {
    if (!isDragging) return
    const dx = e.clientX - dragStart.current.x
    const dy = e.clientY - dragStart.current.y
    setPosition({ x: dragStart.current.posX + dx, y: dragStart.current.posY + dy })
  }

  function handleMouseUp() { setIsDragging(false) }

  function reset() {
    setScale(1)
    setPosition({ x: 0, y: 0 })
  }

  return (
    <div
      ref={containerRef}
      className="overflow-hidden relative cursor-zoom-in select-none"
      style={{ cursor: isDragging ? 'grabbing' : scale > 1 ? 'grab' : 'zoom-in' }}
      onWheel={handleWheel}
      onMouseDown={handleMouseDown}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onDoubleClick={scale > 1 ? reset : () => setScale(2)}
    >
      <img
        src={src}
        alt={alt}
        draggable={false}
        className="w-full h-full object-contain transition-transform duration-75"
        style={{
          transform: `scale(${scale}) translate(${position.x / scale}px, ${position.y / scale}px)`,
          transformOrigin: 'center',
        }}
      />
      {scale > 1 && (
        <button
          className="absolute top-2 right-2 bg-black/50 text-white text-xs px-2 py-1 rounded"
          onClick={reset}
        >
          Reset
        </button>
      )}
    </div>
  )
}
```

## Pinch-to-Zoom (Touch)

```tsx
function handleTouchStart(e: React.TouchEvent) {
  if (e.touches.length === 2) {
    const dist = getDistance(e.touches[0], e.touches[1])
    initialPinchDistance.current = dist
    initialScale.current = scale
  }
}

function handleTouchMove(e: React.TouchEvent) {
  if (e.touches.length === 2) {
    e.preventDefault()
    const dist = getDistance(e.touches[0], e.touches[1])
    const ratio = dist / initialPinchDistance.current
    setScale(Math.max(1, Math.min(8, initialScale.current * ratio)))
  }
}

function getDistance(t1: React.Touch, t2: React.Touch) {
  return Math.hypot(t2.clientX - t1.clientX, t2.clientY - t1.clientY)
}
```

## Zoom Buttons for Accessibility

```tsx
<div className="flex items-center gap-2 mt-2">
  <button onClick={() => setScale(s => Math.max(1, s - 0.5))} aria-label="Zoom out">−</button>
  <span className="text-sm w-12 text-center">{Math.round(scale * 100)}%</span>
  <button onClick={() => setScale(s => Math.min(8, s + 0.5))} aria-label="Zoom in">+</button>
  <button onClick={reset} disabled={scale === 1}>Reset</button>
</div>
```

## Using react-zoom-pan-pinch

For production use, this library handles all edge cases:

```tsx
import { TransformWrapper, TransformComponent } from 'react-zoom-pan-pinch'

<TransformWrapper>
  <TransformComponent>
    <img src={src} alt={alt} />
  </TransformComponent>
</TransformWrapper>
```

## Key Rules

- Reset position when scale returns to 1 — zoomed-out images should not retain pan offset.
- Prevent `preventDefault()` on wheel to stop page scrolling while zoomed; requires non-passive listener.
- `draggable={false}` on the `<img>` prevents browser's default drag-ghost behavior.
- Double-click to zoom in / double-click to reset is a universal convention.
- Add zoom button controls — wheel-only zoom is inaccessible for keyboard users.
