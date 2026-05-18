# Failure Pattern: Stale Closures

## Overview

A stale closure captures an outdated value from a previous render. The function runs with old state or props instead of current ones. This causes bugs that are hard to debug because the code "looks right" — the variable name is correct, but the value is from a previous render.

## Classic Case: setTimeout with State

```tsx
// Bug: counter increments once, then stops
function Counter() {
  const [count, setCount] = useState(0)

  function startAutoIncrement() {
    setInterval(() => {
      // This closure captured count=0 at creation time
      // count never updates inside this closure
      setCount(count + 1)  // Always sets to 1
    }, 1000)
  }

  return <button onClick={startAutoIncrement}>{count}</button>
}

// Fix: use functional update form — no closure dependency on count
function Counter() {
  const [count, setCount] = useState(0)

  function startAutoIncrement() {
    setInterval(() => {
      setCount((prev) => prev + 1)  // prev is always current
    }, 1000)
  }
}
```

**Rule**: For state updates in async callbacks (setTimeout, setInterval, event listeners), use the functional update form `setState(prev => ...)` rather than reading state directly.

## Case: useCallback with Missing Dependency

```tsx
// Bug: handler uses stale user data
function UserProfile({ userId }: { userId: string }) {
  const [userData, setUserData] = useState<User | null>(null)

  // Stale! Uses userData from when this was first created (null)
  const handleSave = useCallback(async (values: FormValues) => {
    await saveUser({ ...userData, ...values })  // userData is always null
  }, [])  // Missing dependency

  // Fix: add userData to deps (or use useRef if you want latest without re-creating)
  const handleSave = useCallback(async (values: FormValues) => {
    await saveUser({ ...userData, ...values })
  }, [userData])
}
```

## Case: Event Listener with State

```tsx
// Bug: scroll handler reads stale isActive state
useEffect(() => {
  function handleScroll() {
    if (isActive) {  // Stale — always the initial value
      doSomething()
    }
  }
  window.addEventListener('scroll', handleScroll)
  return () => window.removeEventListener('scroll', handleScroll)
}, [])  // Effect runs once, closure captures initial isActive

// Fix 1: Add isActive to effect deps (re-registers listener when isActive changes)
useEffect(() => {
  function handleScroll() {
    if (isActive) { doSomething() }
  }
  window.addEventListener('scroll', handleScroll)
  return () => window.removeEventListener('scroll', handleScroll)
}, [isActive])  // Re-runs when isActive changes

// Fix 2: Use a ref for the latest value (avoids re-registering)
const isActiveRef = useRef(isActive)
useEffect(() => { isActiveRef.current = isActive }, [isActive])

useEffect(() => {
  function handleScroll() {
    if (isActiveRef.current) { doSomething() }  // Always current
  }
  window.addEventListener('scroll', handleScroll)
  return () => window.removeEventListener('scroll', handleScroll)
}, [])  // Only registers once
```

**Rule**: For event listeners that need current values without re-registering: sync state to a ref in a separate effect, read from the ref inside the listener.

## Case: WebSocket/Subscribe Callback

```tsx
// Bug: WebSocket message handler reads stale state
useEffect(() => {
  const ws = new WebSocket(url)
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data)
    // messages is stale — always [] from initial render
    setMessages([...messages, msg])  // Drops all previous messages
  }
  return () => ws.close()
}, [])

// Fix: functional update
useEffect(() => {
  const ws = new WebSocket(url)
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data)
    setMessages((prev) => [...prev, msg])  // Always current list
  }
  return () => ws.close()
}, [])
```

## Case: useRef for Latest Callback

When you need a stable function reference (e.g., as a prop to a child that uses `React.memo`) but the function body needs current state:

```ts
// Pattern: "latest ref" for callbacks
function useLatestCallback<T extends (...args: unknown[]) => unknown>(fn: T): T {
  const ref = useRef(fn)
  useEffect(() => { ref.current = fn })  // Update every render
  return useCallback((...args) => ref.current(...args), []) as T  // Stable reference
}

// Usage
const handleChange = useLatestCallback((value: string) => {
  // Can read current props/state without stale closure
  console.log(currentValue, value)
})
```

## Detection

`eslint-plugin-react-hooks` catches most stale closure issues via `exhaustive-deps` rule. Enable it:

```json
{
  "rules": {
    "react-hooks/exhaustive-deps": "error"
  }
}
```

When the linter flags a missing dep:
1. Add it to the dependency array (correct if the effect should re-run)
2. Use a ref instead (correct if re-running would be too expensive)
3. Use functional state update (correct for state-reading in updates)

Never add `// eslint-disable-line` — fix the actual issue.
