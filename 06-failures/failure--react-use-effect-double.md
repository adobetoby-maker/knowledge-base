# Failure: React 18 StrictMode Double Effect Invocation

## Overview
React 18 intentionally runs `useEffect` twice in development (StrictMode): mount → cleanup → mount. This reveals effects that don't clean up properly — subscriptions that stack, fetch calls that conflict, timers that double-fire. The double invocation is not a bug; it's a deliberate contract check. The fix is always to write proper cleanup functions, not to work around the double invocation.

## Why This Happens

React StrictMode simulates component unmounting and remounting to expose effects that would cause problems when React adds support for reusable state (e.g., fast refresh, off-screen rendering). In production, effects run once. In development, they run twice to surface issues early.

```
Development (StrictMode):
  1. Mount → effect runs
  2. Unmount → cleanup runs
  3. Remount → effect runs again

Production:
  1. Mount → effect runs
  (cleanup runs only on actual unmount)
```

## Double Subscription (The Classic Bug)

```tsx
// BAD — returns no cleanup, listener accumulates on remount
useEffect(() => {
  const subscription = eventBus.subscribe('update', handleUpdate)
  // Missing cleanup — in dev: two listeners active at once
}, [])

// GOOD
useEffect(() => {
  const subscription = eventBus.subscribe('update', handleUpdate)
  return () => subscription.unsubscribe()  // cleanup on unmount
}, [])
```

## Double Fetch (Race Condition Pattern)

```tsx
// BAD — two concurrent fetches in dev, response may arrive out of order
useEffect(() => {
  fetch('/api/data').then(r => r.json()).then(setData)
}, [])

// GOOD — cancel the previous request on cleanup
useEffect(() => {
  const controller = new AbortController()

  fetch('/api/data', { signal: controller.signal })
    .then(r => r.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') throw err  // ignore intentional abort
    })

  return () => controller.abort()
}, [])
```

## Double Timer

```tsx
// BAD — two timers running simultaneously in dev
useEffect(() => {
  const id = setInterval(tick, 1000)
  // Missing cleanup
}, [])

// GOOD
useEffect(() => {
  const id = setInterval(tick, 1000)
  return () => clearInterval(id)
}, [])
```

## External Store Subscriptions

```tsx
// BAD — double subscription to WebSocket
useEffect(() => {
  const ws = new WebSocket('wss://example.com')
  ws.onmessage = handleMessage
  // Missing cleanup — in dev: two sockets, messages doubled
}, [])

// GOOD
useEffect(() => {
  const ws = new WebSocket('wss://example.com')
  ws.onmessage = handleMessage
  return () => {
    ws.close()
    ws.onmessage = null
  }
}, [])
```

## Wrong Fix: Suppressing the Double Invocation

```tsx
// WRONG — using a ref to "skip" the second run
const hasRun = useRef(false)
useEffect(() => {
  if (hasRun.current) return  // This hides real problems
  hasRun.current = true
  doSetup()
}, [])
```

This pattern masks the problem. The double invocation is React telling you the effect is impure. If the effect runs twice and causes issues, the cleanup is wrong — not the invocation count.

## One-Time Initialization (Legitimate Use Case)

Some things genuinely should run once (e.g., analytics init, library setup). Move them outside the component:

```ts
// lib/analytics.ts — module-level initialization runs once regardless of renders
let initialized = false
export function initAnalytics() {
  if (initialized) return
  initialized = true
  window.analytics.init(process.env.NEXT_PUBLIC_ANALYTICS_KEY!)
}
```

```tsx
// In layout or _app — not in useEffect
initAnalytics()
```

## Key Rules
- Every `useEffect` that sets up a listener, subscription, timer, or connection MUST return a cleanup function
- If the double-run in dev causes errors, the cleanup is wrong — fix the cleanup
- `AbortController` for fetch, `unsubscribe()` for subscriptions, `clearInterval/clearTimeout` for timers, `ws.close()` for WebSocket
- Do not use `useRef` to track "has run" — it defeats StrictMode's purpose
- In production, effects run once — the double-run is development-only
- For true one-time init: module-level code or `useState` initializer function (runs once per component instance)
