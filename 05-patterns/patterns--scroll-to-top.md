# Pattern: Scroll-to-Top Button

## Overview

A button that appears when the user scrolls down and jumps back to the top. Simple but with subtle details: smooth scroll vs instant, threshold for showing, and avoiding layout shift. Also needed: programmatic scroll-to-top after form submission or page navigation.

## Component

```tsx
function ScrollToTopButton() {
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    function handleScroll() {
      setVisible(window.scrollY > 400)
    }

    // Passive listener — doesn't block scroll performance
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  function scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  if (!visible) return null

  return (
    <button
      onClick={scrollToTop}
      className="fixed bottom-6 right-6 z-40 p-3 bg-white border border-gray-200 rounded-full shadow-md hover:shadow-lg transition-shadow"
      aria-label="Scroll to top"
    >
      <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 15l7-7 7 7" />
      </svg>
    </button>
  )
}
```

## With Fade Animation

Avoid layout shift on show/hide — use opacity transition rather than conditional render:

```tsx
<button
  onClick={scrollToTop}
  className={`fixed bottom-6 right-6 z-40 p-3 bg-white border rounded-full shadow-md
    transition-opacity duration-200
    ${visible ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}
  aria-label="Scroll to top"
>
```

`pointer-events-none` prevents clicks on the invisible button.

## Programmatic Scroll After Navigation

```tsx
// In Next.js — scroll to top after route change
'use client'
import { usePathname } from 'next/navigation'

function ScrollReset() {
  const pathname = usePathname()
  
  useEffect(() => {
    window.scrollTo(0, 0)  // Instant (no behavior: 'smooth') for navigation
  }, [pathname])
  
  return null
}

// Add to root layout
<ScrollReset />
```

## Scroll to an Element

```tsx
function scrollToSection(id: string, offsetPx = 80) {
  const el = document.getElementById(id)
  if (!el) return
  const top = el.getBoundingClientRect().top + window.scrollY - offsetPx
  window.scrollTo({ top, behavior: 'smooth' })
}
```

The `offsetPx` accounts for sticky headers — without it, the heading lands under the header.

## Scroll to Top of a Scrollable Container

For scrollable divs (not `window`):

```tsx
const containerRef = useRef<HTMLDivElement>(null)

function scrollToTop() {
  containerRef.current?.scrollTo({ top: 0, behavior: 'smooth' })
}
```

## Key Rules

- `{ passive: true }` on the scroll listener — allows the browser to start scrolling immediately, improving performance.
- Show button at ~400px scroll, not at the top — no point showing it before the user has scrolled enough to care.
- Instant scroll (`top: 0, 0`) for programmatic navigation resets, smooth scroll for user-initiated "back to top" — these are different UX contexts.
- The button should be visually separate from content and positioned so it doesn't overlap important UI (account for chat bubbles, cookie banners, etc.)
