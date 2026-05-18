# React Rendering Bugs — Common Failures and Fixes

## Infinite Re-render Loop

**Symptom:** Browser freezes, "Maximum update depth exceeded" error, or component re-renders continuously.

**Cause 1:** Setting state unconditionally in useEffect:
```typescript
// BAD — sets state on every render, causing another render
useEffect(() => {
  setCount(count + 1)
})  // Missing dependency array

// Fixed
useEffect(() => {
  setCount(prev => prev + 1)
}, [])  // Empty array = runs once on mount
```

**Cause 2:** Object/array as useEffect dependency (referential equality issue):
```typescript
// BAD — new object created every render, effect runs every render
const options = { timeout: 1000 }
useEffect(() => {
  fetchData(options)
}, [options])  // options is always a new reference

// Fixed — use primitive values or useMemo
const timeout = 1000
useEffect(() => {
  fetchData({ timeout })
}, [timeout])  // primitive, stable reference
```

**Cause 3:** Calling `setState` during render (not in a handler or effect):
```typescript
// BAD
function Component() {
  const [x, setX] = useState(0)
  setX(1)  // called during render = infinite loop
  
  return <div>{x}</div>
}
```

## Stale Closure

**Symptom:** State or props inside an event handler or setTimeout have an old value.

```typescript
// BAD — count is captured by closure at creation time
const [count, setCount] = useState(0)

useEffect(() => {
  const interval = setInterval(() => {
    console.log(count)  // always prints initial value
  }, 1000)
  return () => clearInterval(interval)
}, [])  // Empty deps — count never updates in closure

// Fixed — use functional update form
setInterval(() => {
  setCount(prev => prev + 1)  // gets current value, not closure value
}, 1000)

// Or include in deps and accept re-creating the interval
useEffect(() => {
  const interval = setInterval(() => {
    console.log(count)  // now up to date
  }, 1000)
  return () => clearInterval(interval)
}, [count])  // re-creates interval when count changes
```

## useEffect Running Twice in Development

**Symptom:** useEffect runs twice on mount in development. Subscriptions or API calls fire twice.

**Cause:** React 18 Strict Mode deliberately double-invokes effects to expose side effects that don't clean up.

**Not a bug.** In production it runs once. The fix is to write proper cleanup functions:

```typescript
useEffect(() => {
  const subscription = subscribe(channel)
  
  return () => {
    subscription.unsubscribe()  // cleanup prevents the second run from accumulating
  }
}, [channel])
```

## Key Prop Misuse

**Symptom:** List items maintain incorrect state after reordering, or all items re-render on any list change.

```typescript
// BAD — index as key: React can't distinguish items when order changes
items.map((item, index) => <ItemComponent key={index} item={item} />)

// Fixed — use stable unique ID
items.map(item => <ItemComponent key={item.id} item={item} />)
```

**Counter-pattern:** When you WANT to force a component to fully reset, intentionally change its key:
```typescript
// Force reset when userId changes (e.g., user switches accounts)
<ProfileForm key={userId} userId={userId} />
```

## Context Value Causing All Consumers to Re-render

**Symptom:** Many components re-render when context changes, even if they don't use the changed value.

**Cause:** Context value is an object, created new on every render of the provider.

```typescript
// BAD — new object on every parent render
<UserContext.Provider value={{ user, setUser }}>

// Fixed — memoize the value
const contextValue = useMemo(() => ({ user, setUser }), [user])
<UserContext.Provider value={contextValue}>
```

Or split contexts — one for read (changes with data) and one for write (stable functions):
```typescript
<UserStateContext.Provider value={user}>
  <UserActionsContext.Provider value={{ setUser }}>
    {children}
  </UserActionsContext.Provider>
</UserStateContext.Provider>
```

## "Cannot update during an existing state transition"

**Symptom:** React warning about updating state during render, typically from Suspense or concurrent mode.

**Cause:** Calling `setState` or `dispatch` directly in render (not inside an event handler or effect).

**Fix:** Wrap in `useEffect`, move to event handler, or use `startTransition` for non-urgent updates:
```typescript
import { startTransition } from 'react'

// For non-urgent state updates that can be deferred
startTransition(() => {
  setFilter(newFilter)
})
```

## Prop Drilling Leading to Bug

**Symptom:** A prop passed through 4+ levels has wrong value; updating it doesn't propagate.

**Diagnosis:** Log the prop at each level. Find where the value changes unexpectedly.

**Fix options:**
- Context (if many components need the same data)
- TanStack Query (if data comes from server)
- Lift state to the actual lowest common ancestor (not always root)
