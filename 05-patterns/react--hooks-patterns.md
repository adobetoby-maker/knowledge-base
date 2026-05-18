# React Hooks — Deep Patterns

**When:** Writing custom hooks, managing effects, or debugging hook-related errors.
**Rule:** Hooks are synchronization tools, not lifecycle methods. The mental model shift: "what external thing does this component stay synchronized with?"

## useEffect — The Synchronization Model
```typescript
// WRONG mental model: "run this code after render"
useEffect(() => {
  fetch('/api/data').then(setData)
}, [])

// RIGHT mental model: "keep this component synchronized with..."
useEffect(() => {
  // Synchronized with: a WebSocket connection
  const ws = new WebSocket('wss://...')
  ws.onmessage = (e) => setMessages(prev => [...prev, e.data])
  
  return () => ws.close()  // cleanup = unsynchronize
}, [])
```

## Dependency Array Rules
```typescript
// [] — run once, no cleanup needed
useEffect(() => { document.title = 'My App' }, [])

// [value] — re-synchronize when value changes
useEffect(() => {
  const sub = subscribe(userId, handler)
  return () => sub.unsubscribe()
}, [userId])  // re-subscribes when userId changes

// no array — runs after EVERY render (rare, usually wrong)
useEffect(() => { ... })
```

## The Stale Closure Trap
```typescript
// WRONG — handler captures stale `count` value
const [count, setCount] = useState(0)
useEffect(() => {
  const id = setInterval(() => {
    setCount(count + 1)  // always adds to original 0
  }, 1000)
  return () => clearInterval(id)
}, [])  // effect never re-runs, count is always 0

// RIGHT — use functional updater to get current value
useEffect(() => {
  const id = setInterval(() => {
    setCount(c => c + 1)  // uses latest value
  }, 1000)
  return () => clearInterval(id)
}, [])
```

## Custom Hook Patterns

### Data Fetching Hook (simple, without TanStack Query)
```typescript
function useLocalData<T>(fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)
  
  useEffect(() => {
    let cancelled = false
    fetcher()
      .then(d => { if (!cancelled) setData(d) })
      .catch(e => { if (!cancelled) setError(e) })
      .finally(() => { if (!cancelled) setLoading(false) })
    return () => { cancelled = true }
  }, [])
  
  return { data, loading, error }
}
```

### Media Query Hook
```typescript
function useMediaQuery(query: string) {
  const [matches, setMatches] = useState(false)
  
  useEffect(() => {
    const mq = window.matchMedia(query)
    setMatches(mq.matches)
    const handler = (e: MediaQueryListEvent) => setMatches(e.matches)
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [query])
  
  return matches
}

const isMobile = useMediaQuery('(max-width: 768px)')
```

### Local Storage Hook
```typescript
function useLocalStorage<T>(key: string, initialValue: T) {
  const [value, setValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key)
      return item ? JSON.parse(item) : initialValue
    } catch { return initialValue }
  })
  
  const setStoredValue = (newValue: T) => {
    setValue(newValue)
    window.localStorage.setItem(key, JSON.stringify(newValue))
  }
  
  return [value, setStoredValue] as const
}
```

## useReducer — When State Logic is Complex
```typescript
type Action = 
  | { type: 'increment' }
  | { type: 'decrement' }
  | { type: 'reset'; payload: number }

function reducer(state: number, action: Action): number {
  switch (action.type) {
    case 'increment': return state + 1
    case 'decrement': return state - 1
    case 'reset': return action.payload
  }
}

const [count, dispatch] = useReducer(reducer, 0)
dispatch({ type: 'increment' })
dispatch({ type: 'reset', payload: 10 })
```
Use `useReducer` when: multiple sub-values, next state depends on previous, complex transitions.
