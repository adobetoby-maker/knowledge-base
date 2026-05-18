# Pattern: Image Sequence / Frame Animation (Scroll-Driven)

## Overview
CSS-based scroll animations can't handle per-frame image swapping. Drawing frames to `<canvas>` on scroll is the correct approach — it keeps the heavy lifting off the DOM and lets `requestAnimationFrame` batch updates. Without preloading all frames, users see blank frames mid-scroll. Without IntersectionObserver, frames load even when the section is off-screen.

## Implementation

```tsx
// useImageSequence.ts — preload frames + scroll-to-frame mapping
import { useEffect, useRef, useState } from 'react'

interface UseImageSequenceOptions {
  frameCount: number
  // Function that returns the URL for frame N (0-indexed)
  getFrameUrl: (index: number) => string
  // Scroll progress 0–1 to start/end of animation
  startProgress?: number
  endProgress?: number
}

export function useImageSequence({
  frameCount,
  getFrameUrl,
  startProgress = 0,
  endProgress = 1,
}: UseImageSequenceOptions) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const framesRef = useRef<HTMLImageElement[]>([])
  const loadedRef = useRef(0)
  const currentFrameRef = useRef(0)
  const [isReady, setIsReady] = useState(false)
  const [isInView, setIsInView] = useState(false)

  // Preload all frames — only after the section enters the viewport
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas || !isInView) return

    const images: HTMLImageElement[] = Array.from({ length: frameCount }, (_, i) => {
      const img = new Image()
      img.src = getFrameUrl(i)
      img.onload = () => {
        loadedRef.current++
        // Draw first frame as soon as it's loaded
        if (loadedRef.current === 1) {
          drawFrame(canvas, img)
        }
        // Mark ready after all frames load
        if (loadedRef.current === frameCount) {
          setIsReady(true)
        }
      }
      return img
    })

    framesRef.current = images

    return () => {
      // Cancel any pending loads on cleanup
      images.forEach(img => { img.src = '' })
    }
  }, [isInView, frameCount, getFrameUrl])

  function drawFrame(canvas: HTMLCanvasElement, img: HTMLImageElement) {
    const ctx = canvas.getContext('2d')
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    // drawImage handles scaling to canvas dimensions
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
  }

  // Update frame based on scroll progress
  function updateFrame(scrollProgress: number) {
    const canvas = canvasRef.current
    const frames = framesRef.current
    if (!canvas || !frames.length || !isReady) return

    // Clamp scroll progress to animation range
    const progress = Math.max(0, Math.min(1,
      (scrollProgress - startProgress) / (endProgress - startProgress)
    ))

    // Map progress to frame index — clamp to valid range
    const frameIndex = Math.min(
      Math.floor(progress * frameCount),
      frameCount - 1
    )

    // Only draw if frame changed — skip redundant canvas operations
    if (frameIndex === currentFrameRef.current) return
    currentFrameRef.current = frameIndex

    const img = frames[frameIndex]
    if (img?.complete) {
      drawFrame(canvas, img)
    }
  }

  return { canvasRef, isReady, setIsInView, updateFrame }
}
```

```tsx
// ScrollImageSequence.tsx — the full component
import { useEffect, useRef } from 'react'
import { useImageSequence } from './useImageSequence'

interface ScrollImageSequenceProps {
  frameCount: number
  getFrameUrl: (i: number) => string
  width: number
  height: number
  // How many viewport heights tall the scroll section is (controls animation speed)
  scrollHeight?: number
}

export function ScrollImageSequence({
  frameCount,
  getFrameUrl,
  width,
  height,
  scrollHeight = 3,
}: ScrollImageSequenceProps) {
  const sectionRef = useRef<HTMLDivElement>(null)
  const rafRef = useRef<number>()
  const { canvasRef, isReady, setIsInView, updateFrame } = useImageSequence({
    frameCount,
    getFrameUrl,
  })

  // Lazy load: only start preloading frames when section is visible
  useEffect(() => {
    const section = sectionRef.current
    if (!section) return

    const observer = new IntersectionObserver(
      ([entry]) => setIsInView(entry.isIntersecting),
      { threshold: 0 }
    )
    observer.observe(section)
    return () => observer.disconnect()
  }, [setIsInView])

  // Scroll listener → RAF → canvas draw
  useEffect(() => {
    function onScroll() {
      const section = sectionRef.current
      if (!section) return

      cancelAnimationFrame(rafRef.current!)

      rafRef.current = requestAnimationFrame(() => {
        const rect = section.getBoundingClientRect()
        const sectionHeight = section.offsetHeight
        const viewportHeight = window.innerHeight

        // Progress: 0 when top of section hits bottom of viewport
        //           1 when bottom of section hits top of viewport
        const scrolled = -rect.top
        const progress = Math.max(0, Math.min(1,
          scrolled / (sectionHeight - viewportHeight)
        ))

        updateFrame(progress)
      })
    }

    window.addEventListener('scroll', onScroll, { passive: true })
    return () => {
      window.removeEventListener('scroll', onScroll)
      cancelAnimationFrame(rafRef.current!)
    }
  }, [updateFrame])

  return (
    // Tall section creates the scroll space for the animation
    <div ref={sectionRef} style={{ height: `${scrollHeight * 100}vh` }}>
      {/* Sticky canvas stays in viewport as user scrolls through the tall section */}
      <div
        style={{
          position: 'sticky',
          top: 0,
          height: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {!isReady && <div aria-label="Loading animation" style={{ opacity: 0.3 }}>Loading…</div>}
        <canvas
          ref={canvasRef}
          width={width}
          height={height}
          style={{
            // will-change hints GPU compositing layer
            willChange: 'transform',
            // Pause hover: freeze current frame while mouse is over
            // (optional UX choice)
          }}
          aria-label="Product animation"
          role="img"
        />
      </div>
    </div>
  )
}
```

```tsx
// Usage
// Frame URLs typically follow a naming pattern
<ScrollImageSequence
  frameCount={120}
  getFrameUrl={i => `/frames/product-${String(i).padStart(4, '0')}.jpg`}
  width={1920}
  height={1080}
  scrollHeight={4}  // 4x viewport height = slower, more deliberate scroll
/>
```

## Key Rules
- Preload ALL frames before allowing scroll-driven animation — blank frames mid-sequence break immersion.
- Only start preloading when the section enters the viewport (IntersectionObserver) — loading 120 images on page load for off-screen content is wasteful.
- Draw to `<canvas>` not `<img>` — swapping `src` on an `<img>` on every scroll event causes reflows; canvas draws don't.
- Use `requestAnimationFrame` inside the scroll handler — don't draw directly in the scroll callback.
- Skip the draw if the frame index hasn't changed — `currentFrameRef.current === frameIndex` check avoids redundant canvas operations.
- Set `will-change: transform` on the canvas to promote it to its own compositor layer.
- Make the section `height: Nrem` (tall) with the canvas `position: sticky; top: 0` — the scroll distance determines animation speed.
- Use `{ passive: true }` on the scroll event listener — prevents blocking scroll performance.
- Clamp the frame index: `Math.min(frameIndex, frameCount - 1)` prevents out-of-bounds access.
- Add `role="img"` and `aria-label` to the canvas for accessibility.
