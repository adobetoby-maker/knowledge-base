# Pattern: Top-of-Page Loading Progress Bar (NProgress Style)

## Overview
A real progress bar for page loads is impossible — the browser doesn't expose accurate load timing to JavaScript. A fake progress bar that rushes to 80%, pauses, then jumps to 100% on completion creates the feeling of speed without requiring data you don't have. Showing it immediately causes a flash on fast navigations — a 300ms delay prevents that artifact.

## Implementation

```tsx
// useTopProgressBar.ts — the fake progress logic
import { useCallback, useRef, useState } from 'react'

const FAST_INTERVAL_MS = 80   // how often to increment during "loading"
const MAX_FAKE_PROGRESS = 92  // never reach 100% until actually done — prevents false "done" signal
const INCREMENT = 3           // how many percent to add per tick (varied with jitter)
const COMPLETE_DELAY_MS = 200 // how long to show 100% before hiding

export function useTopProgressBar() {
  const [progress, setProgress] = useState(0)
  const [visible, setVisible] = useState(false)
  const intervalRef = useRef<ReturnType<typeof setInterval>>()
  const showTimerRef = useRef<ReturnType<typeof setTimeout>>()
  const hideTimerRef = useRef<ReturnType<typeof setTimeout>>()

  const start = useCallback(() => {
    // Clear any existing animation
    clearInterval(intervalRef.current)
    clearTimeout(showTimerRef.current)
    clearTimeout(hideTimerRef.current)

    setProgress(0)

    // Delay showing: fast navigations (< 300ms) show no bar at all
    // This prevents the flash-and-disappear artifact on cached pages
    showTimerRef.current = setTimeout(() => {
      setVisible(true)
      setProgress(10)  // jump to 10% immediately when shown

      intervalRef.current = setInterval(() => {
        setProgress(prev => {
          if (prev >= MAX_FAKE_PROGRESS) {
            // Stall near the top — the bar is stuck until complete() is called
            clearInterval(intervalRef.current)
            return prev
          }

          // Jitter: vary increment to feel organic (not robotic constant rate)
          const jitter = Math.random() * INCREMENT
          return Math.min(prev + INCREMENT + jitter, MAX_FAKE_PROGRESS)
        })
      }, FAST_INTERVAL_MS)
    }, 300)
  }, [])

  const complete = useCallback(() => {
    clearInterval(intervalRef.current)
    clearTimeout(showTimerRef.current)

    // If never shown (fast nav), skip to hidden state immediately
    setProgress(100)

    // Brief pause at 100% so users perceive the completion
    hideTimerRef.current = setTimeout(() => {
      setVisible(false)
      // Reset progress after hidden (prevents flash on next start)
      setTimeout(() => setProgress(0), 300)
    }, COMPLETE_DELAY_MS)
  }, [])

  const cancel = useCallback(() => {
    clearInterval(intervalRef.current)
    clearTimeout(showTimerRef.current)
    clearTimeout(hideTimerRef.current)
    setVisible(false)
    setProgress(0)
  }, [])

  return { progress, visible, start, complete, cancel }
}
```

```tsx
// TopProgressBar.tsx — the visual bar
interface TopProgressBarProps {
  progress: number   // 0–100
  visible: boolean
  color?: string
  height?: number
}

export function TopProgressBar({
  progress,
  visible,
  color = '#3b82f6',
  height = 3,
}: TopProgressBarProps) {
  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        zIndex: 9999,
        height,
        // Fade out when complete
        opacity: visible ? 1 : 0,
        // Opacity transitions separately from progress for clean hide
        transition: visible ? 'none' : 'opacity 300ms ease 200ms',
        pointerEvents: 'none',  // don't block clicks
      }}
    >
      <div
        style={{
          height: '100%',
          width: `${progress}%`,
          backgroundColor: color,
          // CSS transition handles the smooth progress update
          // Use transition not animation — transition responds to value changes smoothly
          transition: progress === 100
            ? 'width 200ms ease'     // fast final jump to 100%
            : 'width 400ms ease',    // slower during fake increments
          // Glow effect on the leading edge (optional but looks premium)
          boxShadow: `0 0 8px ${color}, 0 0 4px ${color}`,
          // Round cap on the right end
          borderRadius: '0 2px 2px 0',
        }}
      />
    </div>
  )
}
```

```tsx
// Integration with Next.js App Router
// app/layout.tsx
'use client'

import { usePathname } from 'next/navigation'
import { useEffect } from 'react'
import { TopProgressBar } from '@/components/TopProgressBar'
import { useTopProgressBar } from '@/hooks/useTopProgressBar'

export function ProgressProvider({ children }: { children: React.ReactNode }) {
  const { progress, visible, start, complete } = useTopProgressBar()
  const pathname = usePathname()

  useEffect(() => {
    // pathname change = navigation completed
    complete()
  }, [pathname, complete])

  // Intercept link clicks to start the bar
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      const link = (e.target as Element).closest('a[href]') as HTMLAnchorElement
      if (!link) return
      // Only trigger for same-origin, non-external links
      if (link.origin === window.location.origin && !link.target) {
        start()
      }
    }

    document.addEventListener('click', handleClick)
    return () => document.removeEventListener('click', handleClick)
  }, [start])

  return (
    <>
      <TopProgressBar progress={progress} visible={visible} />
      {children}
    </>
  )
}
```

```tsx
// Manual usage — trigger from router events or async actions
function SubmitButton() {
  const { start, complete, cancel } = useTopProgressBarContext()

  async function handleSubmit() {
    start()
    try {
      await submitForm()
      complete()
    } catch {
      cancel()
    }
  }
  return <button onClick={handleSubmit}>Submit</button>
}
```

## Key Rules
- Never use actual progress data — you don't have it. Fake progress is the correct pattern.
- Rush to ~80% quickly, stall, then jump to 100% on `complete()` — this matches user mental models of "loading."
- Add a 300ms delay before showing the bar — prevents flash-and-disappear on fast (cached) navigations.
- Use CSS `transition: width` not a CSS animation — transitions respond to value changes; animations run on their own schedule.
- Never set progress to 100% during fake increments — only on `complete()`. Max fake progress is ~92%.
- `cancel()` is needed for navigation failures (network error, 404) — the bar shouldn't stay stuck.
- `z-index: 9999` puts it above modals, drawers, and other overlays.
- `pointer-events: none` — the bar must never block clicks.
- Add jitter to increments (random variation) — constant-rate progress feels mechanical.
- Show the bar `position: fixed; top: 0` — it must stay at the top of the viewport regardless of page scroll.
