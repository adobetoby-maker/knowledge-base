# Failure: useEffect Infinite Loop

**Symptom:** Component re-renders endlessly. Browser freezes or shows "too many re-renders" error. Network tab shows the same API call firing repeatedly.

**Cause:** An object or array in the dependency array is recreated on every render, triggering the effect, which updates state, which re-renders, which recreates the object, which triggers the effect...

## The Five Infinite Loop Patterns

### Pattern 1 — Object in dependency array
```typescript
// WRONG — options is a new object on every render
function Component({ userId }: { userId: string }) {
  const options = { userId, active: true }  // new reference every render
  
  useEffect(() => {
    fetchUser(options)
  }, [options])  // options changes every render → infinite loop
}

// FIX — use primitive values as deps
useEffect(() => {
  fetchUser({ userId, active: true })
}, [userId])  // primitive string, stable reference
```

### Pattern 2 — Array in dependency array
```typescript
// WRONG — array literal creates new reference every render
useEffect(() => {
  processList(items)
}, [items, []])  // [] is new every render

// FIX — move array outside component or use useMemo
const stableList = useMemo(() => [], [])
useEffect(() => {
  processList(items)
}, [items, stableList])
```

### Pattern 3 — setState causes the dependency to change
```typescript
// WRONG — setting state that's in the dependency array
const [count, setCount] = useState(0)
useEffect(() => {
  setCount(count + 1)  // changes count → effect runs again → infinite
}, [count])

// FIX — use functional setState (doesn't need count as dep)
useEffect(() => {
  const timer = setInterval(() => {
    setCount(prev => prev + 1)  // no dependency on count
  }, 1000)
  return () => clearInterval(timer)
}, [])  // empty deps — runs once
```

### Pattern 4 — Function in dependency array
```typescript
// WRONG — function is recreated every render
function Component({ userId }: Props) {
  const fetchUser = async () => { /* ... */ }  // new function each render
  
  useEffect(() => {
    fetchUser()
  }, [fetchUser])  // infinite loop

// FIX — useCallback stabilizes the function reference
  const fetchUser = useCallback(async () => { /* ... */ }, [userId])
  
  useEffect(() => {
    fetchUser()
  }, [fetchUser])  // now stable when userId is stable
}
```

### Pattern 5 — Missing cleanup causes stale state update
```typescript
// WRONG — async effect updates state after unmount, triggers re-mount
useEffect(() => {
  fetchData().then(data => setData(data))  // no cleanup
})

// FIX — cancel effect on cleanup
useEffect(() => {
  let cancelled = false
  fetchData().then(data => {
    if (!cancelled) setData(data)
  })
  return () => { cancelled = true }
}, [id])
```

## Debug Process
1. Add `console.log` inside the effect body — how many times does it fire?
2. Add `console.log` to track which dependency is changing: `console.log({ dep1, dep2 })`
3. Use React DevTools "Why did this render?" to see what prop/state changed
4. The changing dependency is almost always an object or function being recreated
