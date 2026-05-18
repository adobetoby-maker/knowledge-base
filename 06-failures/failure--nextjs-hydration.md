# Failure: Next.js Hydration Mismatch

**Symptom:** `Error: Hydration failed because the server rendered HTML didn't match the client.` Console shows mismatched content between server and client.

## Why It Happens
Server renders HTML. Client receives it and "hydrates" (attaches event listeners). If the HTML the client generates during hydration doesn't match what the server sent, React throws.

Common causes:
1. Browser-only APIs used during render (window, document, localStorage)
2. Date/time rendering that differs between server and client timezones
3. Random values in render (Math.random(), crypto.randomUUID())
4. Browser extensions modifying DOM before hydration
5. Conditional rendering based on client-only state

## Fix 1 — Suppress Hydration Warning (cosmetic mismatches only)
```typescript
// For intentional differences (like browser-extension-injected attributes)
<html suppressHydrationWarning>
<body suppressHydrationWarning>
```
Only use for the root HTML element, not deep in the tree.

## Fix 2 — Client-Only Rendering with useEffect
```typescript
'use client'
import { useState, useEffect } from 'react'

function Clock() {
  const [time, setTime] = useState<string | null>(null)
  
  useEffect(() => {
    // Only runs on client — never causes hydration mismatch
    setTime(new Date().toLocaleTimeString())
    const id = setInterval(() => setTime(new Date().toLocaleTimeString()), 1000)
    return () => clearInterval(id)
  }, [])
  
  if (!time) return null  // or a static placeholder
  return <span>{time}</span>
}
```

## Fix 3 — Dynamic Import with ssr: false
```typescript
import dynamic from 'next/dynamic'

// Component uses window/localStorage/browser-only APIs
const BrowserOnlyComponent = dynamic(
  () => import('./MyComponent'),
  { ssr: false, loading: () => <div className="h-10" /> }
)
```
The placeholder height prevents layout shift.

## Fix 4 — useMounted Pattern
```typescript
'use client'
function useIsMounted() {
  const [mounted, setMounted] = useState(false)
  useEffect(() => setMounted(true), [])
  return mounted
}

function ThemeToggle() {
  const mounted = useIsMounted()
  const theme = useTheme()
  
  // Render nothing on server — avoid mismatch
  if (!mounted) return <div className="h-9 w-9" />  // placeholder preserves layout
  
  return <button>{theme === 'dark' ? '☀️' : '🌙'}</button>
}
```

## Fix 5 — Stable IDs Instead of Random
```typescript
// WRONG — different value on server and client
const id = Math.random().toString()
const id = crypto.randomUUID()

// RIGHT — use useId() for stable component IDs
import { useId } from 'react'
function Input({ label }) {
  const id = useId()  // same on server and client
  return <><label htmlFor={id}>{label}</label><input id={id} /></>
}
```

## Diagnostic Approach
1. Add `console.log` in the component to see what value the server renders vs what client renders
2. Check if any browser globals (`window`, `document`, `localStorage`) are accessed at render time
3. Check if any dates/times render differently based on timezone
4. Disable browser extensions temporarily to rule them out
