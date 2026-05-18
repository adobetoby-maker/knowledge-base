# Pattern: Persistent Sidebar Drawer (Desktop)

## Overview
Overlay sidebars (drawers that cover content) are appropriate for mobile and temporary actions. On desktop, a persistent sidebar should push the main content area aside instead — overlaying means users can't see what they're navigating to and what their context was at the same time. Without focus management and keyboard shortcuts, power users are forced to reach for the mouse.

## Implementation

```tsx
// usePersistentDrawer.ts — state management with localStorage persistence
import { useCallback, useEffect, useState } from 'react'

const STORAGE_KEY = 'sidebar-open'
const KEYBOARD_SHORTCUT = '['  // Convention from VS Code, Linear, etc.

export function usePersistentDrawer(defaultOpen = true) {
  const [isOpen, setIsOpen] = useState<boolean>(() => {
    if (typeof window === 'undefined') return defaultOpen
    const stored = localStorage.getItem(STORAGE_KEY)
    // Return defaultOpen if no stored value yet
    return stored !== null ? stored === 'true' : defaultOpen
  })

  const toggle = useCallback(() => {
    setIsOpen(prev => {
      const next = !prev
      localStorage.setItem(STORAGE_KEY, String(next))
      return next
    })
  }, [])

  const open = useCallback(() => {
    setIsOpen(true)
    localStorage.setItem(STORAGE_KEY, 'true')
  }, [])

  const close = useCallback(() => {
    setIsOpen(false)
    localStorage.setItem(STORAGE_KEY, 'false')
  }, [])

  // Keyboard shortcut: [ toggles sidebar
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (
        e.key === KEYBOARD_SHORTCUT &&
        !e.metaKey && !e.ctrlKey && !e.altKey &&
        // Don't intercept when user is typing
        document.activeElement?.tagName !== 'INPUT' &&
        document.activeElement?.tagName !== 'TEXTAREA' &&
        !(document.activeElement as HTMLElement)?.isContentEditable
      ) {
        toggle()
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [toggle])

  return { isOpen, toggle, open, close }
}
```

```tsx
// AppLayout.tsx — persistent push layout
const SIDEBAR_WIDTH = 240  // px
const TRANSITION = 'margin-left 200ms ease, width 200ms ease'

export function AppLayout({ children }: { children: React.ReactNode }) {
  const { isOpen, toggle } = usePersistentDrawer()
  const isMobile = useMediaQuery('(max-width: 768px)')

  if (isMobile) {
    // Mobile: overlay mode (sheet), not push mode
    return (
      <div>
        <button onClick={toggle} aria-label="Open menu" aria-expanded={isOpen}>☰</button>
        {/* Mobile drawer as overlay */}
        <MobileSheet open={isOpen} onClose={toggle}>
          <Sidebar onNavigate={toggle} />  {/* close on nav for mobile */}
        </MobileSheet>
        <main>{children}</main>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      {/* Sidebar — always in DOM, width transitions to 0 when closed */}
      <aside
        style={{
          width: isOpen ? SIDEBAR_WIDTH : 0,
          minWidth: isOpen ? SIDEBAR_WIDTH : 0,
          overflow: 'hidden',
          flexShrink: 0,
          // Smooth push transition
          transition: TRANSITION,
        }}
        aria-label="Main navigation"
        // Hidden from accessibility tree when closed
        aria-hidden={!isOpen}
        inert={!isOpen ? '' : undefined}  // prevents focus trap when closed
      >
        <div style={{ width: SIDEBAR_WIDTH }}>  {/* inner div prevents content squish during transition */}
          <Sidebar />
        </div>
      </aside>

      {/* Main content shifts right when sidebar opens — NOT overlaid */}
      <div style={{ flex: 1, overflow: 'auto', display: 'flex', flexDirection: 'column' }}>
        {/* Toggle button in the main content area (always accessible) */}
        <header style={{ display: 'flex', alignItems: 'center', padding: '0 16px', height: 48 }}>
          <button
            onClick={toggle}
            aria-label={isOpen ? 'Close sidebar' : 'Open sidebar'}
            aria-expanded={isOpen}
            aria-controls="main-sidebar"
            title="Toggle sidebar [ ]"
          >
            {isOpen ? '←' : '→'}
          </button>
        </header>

        <main id="main-content" style={{ flex: 1, overflow: 'auto' }}>
          {children}
        </main>
      </div>
    </div>
  )
}
```

```tsx
// Focus management — where does focus go when sidebar opens/closes?
import { useRef, useEffect } from 'react'

function Sidebar({ isOpen }: { isOpen: boolean }) {
  const firstLinkRef = useRef<HTMLAnchorElement>(null)
  const wasOpenRef = useRef(isOpen)

  useEffect(() => {
    const wasOpen = wasOpenRef.current
    wasOpenRef.current = isOpen

    if (isOpen && !wasOpen) {
      // Sidebar just opened: move focus to first nav item
      // Small delay for transition to complete
      setTimeout(() => firstLinkRef.current?.focus(), 210)
    }
    // When closing: focus returns to the toggle button naturally
    // (user just clicked it)
  }, [isOpen])

  return (
    <nav>
      <a ref={firstLinkRef} href="/dashboard">Dashboard</a>
      <a href="/projects">Projects</a>
      {/* ... */}
    </nav>
  )
}
```

```css
/* Smooth transition without flash */
/* The inner content div stays at SIDEBAR_WIDTH during animation */
/* The outer aside clips it with overflow:hidden + width transition */
aside {
  transition: width 200ms ease, min-width 200ms ease;
}

/* Prevent sidebar content from wrapping during transition */
aside > div {
  width: 240px;
  /* Never shrink below full width — the outer clips it */
  flex-shrink: 0;
}
```

## Key Rules
- Desktop persistent sidebar pushes main content, not overlays — users need to see both at the same time.
- Mobile gets a drawer overlay (sheet), not a push layout — the screen isn't wide enough for both.
- Persist open state to localStorage — sidebar state must survive navigation and page refresh.
- Use `inert` attribute on the hidden sidebar to prevent keyboard focus from entering it when closed.
- Set `aria-hidden={true}` on closed sidebar — removes it from the accessibility tree.
- Implement `[` as keyboard shortcut to toggle — this is the convention from VS Code, Linear, and Notion.
- Don't intercept the `[` key when focus is in an input, textarea, or contenteditable.
- The transition is on the outer `<aside>` width (clips content), not the inner content — prevents squishing during animation.
- When sidebar opens, move focus to the first navigation item; when it closes, return focus to the toggle button.
- Show the shortcut hint (`[ ]`) in the toggle button's `title` attribute.
