# Pattern: Resizable Sidebar

## Overview
A fixed-width sidebar forces users into a one-size-fits-all layout. Some need more space for their content, some less. Without localStorage persistence, the sidebar resets on every page load. On mobile, a draggable sidebar becomes unusable — it must switch to an overlay drawer pattern.

## Implementation

```tsx
// useResizableSidebar.ts
import { useCallback, useEffect, useRef, useState } from 'react'

const MIN_WIDTH = 120
const MAX_WIDTH = 400
const DEFAULT_WIDTH = 240
const STORAGE_KEY = 'sidebar-width'
const COLLAPSED_KEY = 'sidebar-collapsed'

export function useResizableSidebar() {
  const [width, setWidth] = useState<number>(() => {
    if (typeof window === 'undefined') return DEFAULT_WIDTH
    return Number(localStorage.getItem(STORAGE_KEY)) || DEFAULT_WIDTH
  })

  // Collapsed is separate from width: collapsed = hidden, null width = unknown
  // Restoring from collapsed uses the stored width, not 0
  const [collapsed, setCollapsed] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false
    return localStorage.getItem(COLLAPSED_KEY) === 'true'
  })

  const isDragging = useRef(false)
  const startX = useRef(0)
  const startWidth = useRef(width)

  const onMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    isDragging.current = true
    startX.current = e.clientX
    startWidth.current = width

    document.body.style.cursor = 'col-resize'
    // Disable text selection during drag
    document.body.style.userSelect = 'none'
  }, [width])

  useEffect(() => {
    function onMouseMove(e: MouseEvent) {
      if (!isDragging.current) return

      const delta = e.clientX - startX.current
      const newWidth = Math.min(MAX_WIDTH, Math.max(MIN_WIDTH, startWidth.current + delta))
      setWidth(newWidth)
    }

    function onMouseUp() {
      if (!isDragging.current) return
      isDragging.current = false
      document.body.style.cursor = ''
      document.body.style.userSelect = ''

      // Persist only on drag end, not on every mousemove
      setWidth(prev => {
        localStorage.setItem(STORAGE_KEY, String(prev))
        return prev
      })
    }

    window.addEventListener('mousemove', onMouseMove)
    window.addEventListener('mouseup', onMouseUp)
    return () => {
      window.removeEventListener('mousemove', onMouseMove)
      window.removeEventListener('mouseup', onMouseUp)
    }
  }, [])

  const toggle = useCallback(() => {
    setCollapsed(prev => {
      const next = !prev
      localStorage.setItem(COLLAPSED_KEY, String(next))
      return next
    })
  }, [])

  return { width, collapsed, toggle, onMouseDown }
}
```

```tsx
// ResizableSidebar.tsx
import { useResizableSidebar } from './useResizableSidebar'

export function AppLayout({ children }: { children: React.ReactNode }) {
  const { width, collapsed, toggle, onMouseDown } = useResizableSidebar()
  const isMobile = useMediaQuery('(max-width: 640px)')

  // Mobile: use a drawer overlay pattern, not a resizable panel
  if (isMobile) {
    return (
      <div style={{ position: 'relative' }}>
        <MobileDrawer open={!collapsed} onClose={toggle}>
          <SidebarContent />
        </MobileDrawer>
        <main>{children}</main>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      {/* Sidebar — 0 width when collapsed, stored width when open */}
      <aside
        style={{
          width: collapsed ? 0 : width,
          minWidth: collapsed ? 0 : width,
          overflow: 'hidden',
          transition: isDraggingRef.current ? 'none' : 'width 200ms ease',
          flexShrink: 0,
        }}
        aria-hidden={collapsed}
      >
        <SidebarContent />
      </aside>

      {/* Drag handle — only visible when sidebar is open */}
      {!collapsed && (
        <div
          onMouseDown={onMouseDown}
          role="separator"
          aria-orientation="vertical"
          aria-label="Resize sidebar"
          aria-valuenow={width}
          aria-valuemin={MIN_WIDTH}
          aria-valuemax={MAX_WIDTH}
          style={{
            width: 4,
            cursor: 'col-resize',
            background: 'transparent',
            flexShrink: 0,
            // Wider hit area without visible bulk
            margin: '0 -2px',
            zIndex: 10,
          }}
        />
      )}

      <main style={{ flex: 1, overflow: 'auto' }}>{children}</main>
    </div>
  )
}
```

```tsx
// Keyboard toggle support
useEffect(() => {
  function handleKeyDown(e: KeyboardEvent) {
    // [ key toggles sidebar — common IDE convention
    if (e.key === '[' && !e.metaKey && !e.ctrlKey && !e.altKey) {
      // Only if focus is not in an input
      if (document.activeElement?.tagName !== 'INPUT' &&
          document.activeElement?.tagName !== 'TEXTAREA') {
        toggle()
      }
    }
  }
  window.addEventListener('keydown', handleKeyDown)
  return () => window.removeEventListener('keydown', handleKeyDown)
}, [toggle])
```

## Key Rules
- Persist width in localStorage — sidebar width should survive page reloads and navigation.
- Enforce min (120px) and max (400px) constraints on every drag frame, not just on release.
- Collapsed state is separate from width: collapsed hides the sidebar but remembers the width so expand restores it, not a default.
- Disable text selection (`userSelect: none`) on `document.body` during drag — text highlights otherwise.
- Disable the CSS transition during active dragging — the lag creates a sluggish feel.
- Mobile gets a drawer overlay, not a resizable panel — touch-dragging to resize is too imprecise.
- The drag handle's visual width (4px) and hit area should differ — use negative margin or padding for a larger touch target.
- Add ARIA attributes to the separator: `role="separator"`, `aria-valuenow`, `aria-valuemin`, `aria-valuemax`.
