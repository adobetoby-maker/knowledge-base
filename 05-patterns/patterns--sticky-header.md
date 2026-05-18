# Pattern: Sticky Header with Scroll Behavior

## What This Solves

Headers that hide on scroll-down and reappear on scroll-up ("smart sticky") maximize screen space on mobile. A simpler always-visible sticky header just uses `position: sticky; top: 0`. The smart hide/show version requires scroll direction detection in JS.

## Simple Always-Sticky Header

```tsx
// app/layout.tsx
export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <header className="sticky top-0 z-40 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
          <Nav />
        </header>
        <main>{children}</main>
      </body>
    </html>
  )
}
```

The `backdrop-blur` + semi-transparent background is the standard pattern — gives depth without a hard edge.

## Smart Hide/Show Header

```tsx
'use client'
import { useState, useEffect, useRef } from 'react'
import { cn } from '@/lib/utils'

export function SmartHeader({ children }: { children: React.ReactNode }) {
  const [visible, setVisible] = useState(true)
  const lastScrollY = useRef(0)
  const ticking = useRef(false)

  useEffect(() => {
    const handleScroll = () => {
      if (ticking.current) return
      ticking.current = true

      requestAnimationFrame(() => {
        const currentScrollY = window.scrollY
        const delta = currentScrollY - lastScrollY.current

        if (currentScrollY < 80) {
          // Always show near top of page
          setVisible(true)
        } else if (delta > 8) {
          // Scrolling down — hide
          setVisible(false)
        } else if (delta < -8) {
          // Scrolling up — show
          setVisible(true)
        }

        lastScrollY.current = currentScrollY
        ticking.current = false
      })
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  return (
    <header
      className={cn(
        'fixed top-0 left-0 right-0 z-40 border-b bg-background/95 backdrop-blur transition-transform duration-300',
        visible ? 'translate-y-0' : '-translate-y-full'
      )}
    >
      {children}
    </header>
  )
}
```

## Header Height Compensation

When the header is `fixed` (not `sticky`), the page content starts behind it. Compensate:

```tsx
// Add to body or main:
<main className="pt-16"> {/* match header height */}
```

Or use a CSS variable:
```css
:root { --header-height: 64px; }
main { padding-top: var(--header-height); }
```

## Scroll-Aware Background

Header that's transparent at top, filled after scrolling:

```tsx
const [scrolled, setScrolled] = useState(false)

useEffect(() => {
  const handleScroll = () => setScrolled(window.scrollY > 20)
  window.addEventListener('scroll', handleScroll, { passive: true })
  return () => window.removeEventListener('scroll', handleScroll)
}, [])

return (
  <header className={cn(
    'fixed top-0 w-full z-40 transition-all duration-300',
    scrolled
      ? 'bg-background/95 backdrop-blur border-b shadow-sm'
      : 'bg-transparent'
  )}>
```

Useful for landing pages where the hero section needs the full-bleed look.

## Progress Bar Under Header

```tsx
// Track reading progress
const [progress, setProgress] = useState(0)

useEffect(() => {
  const handleScroll = () => {
    const total = document.documentElement.scrollHeight - window.innerHeight
    setProgress(total > 0 ? (window.scrollY / total) * 100 : 0)
  }
  window.addEventListener('scroll', handleScroll, { passive: true })
  return () => window.removeEventListener('scroll', handleScroll)
}, [])

// In header JSX:
<div
  className="absolute bottom-0 left-0 h-0.5 bg-primary transition-all"
  style={{ width: `${progress}%` }}
/>
```

## requestAnimationFrame Throttling

Scroll events fire many times per second. Always throttle with `requestAnimationFrame` using a `ticking` ref guard — never update state on every scroll event directly. This prevents layout thrashing and excessive re-renders.

## z-index Convention

- Overlay/modals: `z-50` 
- Sticky header: `z-40`
- Floating labels/tooltips: `z-30`
- Dropdowns: `z-20`
- Keep consistent — never set `z-index: 9999` in component code
