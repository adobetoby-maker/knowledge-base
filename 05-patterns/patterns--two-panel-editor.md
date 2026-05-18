# Pattern: Two-Panel Editor

## Overview
A two-panel editor (input left, live preview right) must feel instantaneous without hammering the preview renderer on every keystroke. The split ratio, panel state, and scroll sync position are user preferences — losing them on reload breaks the sense of a persistent workspace. Mobile users need to focus on one panel at a time since both panels at 50% width become unusable.

## Implementation

### Debounced Preview Update
```tsx
import { useEffect, useState, useRef } from 'react'

const DEBOUNCE_MS = 300

function useDebouncedValue<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value)
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])
  return debounced
}

function TwoPanelEditor() {
  const [source, setSource] = useState('')
  const debouncedSource = useDebouncedValue(source, DEBOUNCE_MS)
  // debouncedSource drives the preview renderer — not `source` directly
}
```

### Split Ratio Persistence
```tsx
const SPLIT_KEY = 'editor-split-ratio'

function useSplitRatio(defaultRatio = 50) {
  const [ratio, setRatio] = useState(() => {
    const stored = localStorage.getItem(SPLIT_KEY)
    return stored ? Number(stored) : defaultRatio
  })
  const updateRatio = (newRatio: number) => {
    setRatio(newRatio)
    localStorage.setItem(SPLIT_KEY, String(newRatio))
  }
  return [ratio, updateRatio] as const
}
```

### Scroll Sync
```tsx
function useSyncScroll(
  sourceRef: React.RefObject<HTMLElement>,
  previewRef: React.RefObject<HTMLElement>
) {
  const isSyncing = useRef(false)

  useEffect(() => {
    const source = sourceRef.current
    const preview = previewRef.current
    if (!source || !preview) return

    const syncFromSource = () => {
      if (isSyncing.current) return
      isSyncing.current = true
      const pct = source.scrollTop / (source.scrollHeight - source.clientHeight)
      preview.scrollTop = pct * (preview.scrollHeight - preview.clientHeight)
      requestAnimationFrame(() => { isSyncing.current = false })
    }

    source.addEventListener('scroll', syncFromSource, { passive: true })
    return () => source.removeEventListener('scroll', syncFromSource)
  }, [sourceRef, previewRef])
}
```

### Panel Layout + Mobile Collapse
```tsx
function EditorLayout({ ratio }: { ratio: number }) {
  const [mobilePanel, setMobilePanel] = useState<'input' | 'preview'>('input')

  return (
    <>
      {/* Desktop: side-by-side */}
      <div
        className="hidden md:flex h-full"
        style={{ '--split': `${ratio}%` } as React.CSSProperties}
      >
        <div
          style={{ width: 'var(--split)' }}
          aria-label="Markdown source editor"
          role="region"
        >
          <InputPanel />
        </div>
        <div
          style={{ width: `calc(100% - var(--split))` }}
          aria-label="Rendered preview"
          role="region"
        >
          <PreviewPanel />
        </div>
      </div>

      {/* Mobile: toggle */}
      <div className="flex md:hidden h-full flex-col">
        <div role="tablist" className="flex border-b">
          <button
            role="tab"
            aria-selected={mobilePanel === 'input'}
            onClick={() => setMobilePanel('input')}
          >
            Edit
          </button>
          <button
            role="tab"
            aria-selected={mobilePanel === 'preview'}
            onClick={() => setMobilePanel('preview')}
          >
            Preview
          </button>
        </div>
        {mobilePanel === 'input' ? <InputPanel /> : <PreviewPanel />}
      </div>
    </>
  )
}
```

### Full-Screen Mode
```tsx
function useFullScreen(panelRef: React.RefObject<HTMLElement>) {
  const [isFullScreen, setIsFullScreen] = useState(false)

  const toggle = () => {
    if (!isFullScreen) {
      panelRef.current?.requestFullscreen()
    } else {
      document.exitFullscreen()
    }
  }

  useEffect(() => {
    const handler = () => setIsFullScreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', handler)
    return () => document.removeEventListener('fullscreenchange', handler)
  }, [])

  return { isFullScreen, toggle }
}
```

## Key Rules
- Debounce preview updates at 300ms minimum — shorter intervals cause jitter on slow renders (markdown parsing, syntax highlighting)
- Drive preview from debounced value, not raw input state — the input field must update immediately
- Scroll sync is one-directional by default (source → preview); bidirectional sync causes feedback loops unless you guard with a mutex flag
- Store split ratio in `localStorage` — it survives navigation but doesn't pollute the URL
- On mobile, never show both panels at once — 50%/50% on a 375px screen gives each panel 187px, too narrow for any real work
- Each panel needs a distinct `aria-label` and `role="region"` — screen readers cannot distinguish two unnamed scrollable regions
- Full-screen button should appear in panel header, not a global toolbar — users need to know which panel they're maximizing
- The resize handle needs at least 8px tap target width and `cursor: col-resize` on desktop
