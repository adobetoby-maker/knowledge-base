# Failure: Memory Leaks in React

## The Problem

React memory leaks happen when: subscriptions/timers aren't cleaned up on unmount, closures hold references to large objects, and effects set state after the component unmounts. Symptoms: growing memory over time, "Can't perform state update on unmounted component" warnings.

## Leak 1: Missing Effect Cleanup

```tsx
// WRONG — setInterval never cleared
useEffect(() => {
  const id = setInterval(() => {
    setTime(new Date())
  }, 1000)
  // No cleanup!
}, [])

// CORRECT
useEffect(() => {
  const id = setInterval(() => {
    setTime(new Date())
  }, 1000)
  return () => clearInterval(id)  // Cleanup on unmount
}, [])
```

Every effect that sets up a subscription or timer must return a cleanup function.

## Leak 2: Unsubscribed Supabase Realtime

```tsx
// WRONG — channel never unsubscribed
useEffect(() => {
  const channel = supabase
    .channel('invoices')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, handler)
    .subscribe()
  // No cleanup!
}, [])

// CORRECT
useEffect(() => {
  const channel = supabase
    .channel('invoices')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'invoices' }, handler)
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}, [])
```

Each Supabase channel holds an open WebSocket connection. Without cleanup, every mount creates a new connection that stays open.

## Leak 3: AbortController for Fetch

```tsx
// WRONG — fetch continues after unmount, then tries to set state
useEffect(() => {
  fetch('/api/data').then((r) => r.json()).then(setData)
}, [])

// CORRECT
useEffect(() => {
  const controller = new AbortController()

  fetch('/api/data', { signal: controller.signal })
    .then((r) => r.json())
    .then(setData)
    .catch((err) => {
      if (err.name !== 'AbortError') throw err  // Ignore abort errors
    })

  return () => controller.abort()
}, [])
```

TanStack Query handles this automatically. The `AbortController` pattern is only needed for raw `fetch` calls in effects.

## Leak 4: Event Listener Not Removed

```tsx
// WRONG
useEffect(() => {
  window.addEventListener('resize', handleResize)
}, [handleResize])

// CORRECT
useEffect(() => {
  window.addEventListener('resize', handleResize)
  return () => window.removeEventListener('resize', handleResize)
}, [handleResize])
```

`window.addEventListener` accumulates listeners — each remount adds another. Without cleanup, you end up with dozens of identical listeners.

## Leak 5: ResizeObserver Not Disconnected

```tsx
useEffect(() => {
  const observer = new ResizeObserver(handleResize)
  observer.observe(elementRef.current!)
  return () => observer.disconnect()  // Not just unobserve — disconnect the whole observer
}, [])
```

## Leak 6: Stale Closure Capturing Large Objects

```ts
// WRONG — handler captures the entire `data` array on every render
function ExpensiveList({ data }: { data: Item[] }) {
  const handleKeyDown = (e: KeyboardEvent) => {
    console.log(data.length)  // data is captured here
  }

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [handleKeyDown])  // handleKeyDown changes every render — re-registers listener every render
}

// CORRECT — use ref to avoid closure over data
function ExpensiveList({ data }: { data: Item[] }) {
  const dataRef = useRef(data)
  useEffect(() => { dataRef.current = data }, [data])

  useEffect(() => {
    const handler = (e: KeyboardEvent) => console.log(dataRef.current.length)
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [])  // Only runs once — handler reads from ref
}
```

## Leak 7: setInterval Capturing Old State (Stale Closure)

```tsx
// WRONG — count is captured at 0 and never updates
useEffect(() => {
  const id = setInterval(() => {
    setCount(count + 1)  // Always 0 + 1 = 1
  }, 1000)
  return () => clearInterval(id)
}, [])

// CORRECT — functional update reads current state
useEffect(() => {
  const id = setInterval(() => {
    setCount((prev) => prev + 1)  // Always increments correctly
  }, 1000)
  return () => clearInterval(id)
}, [])  // Empty deps — safe because we use functional update
```

## Leak 8: Third-Party Library Not Destroyed

```tsx
// Chart.js, Mapbox, etc. must be explicitly destroyed
useEffect(() => {
  const chart = new Chart(canvasRef.current!, config)
  return () => chart.destroy()
}, [])

// Leaflet
useEffect(() => {
  const map = L.map(containerRef.current!)
  return () => map.remove()
}, [])
```

Libraries that create canvas contexts, WebGL contexts, or DOM elements outside React's control must be manually destroyed.

## Detecting Leaks

1. Open Chrome DevTools → Memory tab
2. Take a heap snapshot
3. Perform the action that you suspect leaks (navigate to page, navigate away, repeat)
4. Take another heap snapshot
5. Compare: `Comparison` view shows added objects

Also: `Performance → Record → Perform actions → Stop`. Look for steadily climbing memory in the heap graph.
