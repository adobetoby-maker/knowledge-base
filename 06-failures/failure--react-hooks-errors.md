# Failure Patterns: React Hooks Errors

## "Rules of Hooks" Violations

React hooks must be called:
1. At the top level of a function component (not inside if/loops/callbacks)
2. Only inside function components or custom hooks (not in class components or utility functions)

```typescript
// WRONG — conditional hook:
function Component({ isLoggedIn }) {
  if (isLoggedIn) {
    const data = useData()  // violates rules of hooks
  }
}

// CORRECT — call unconditionally, use the value conditionally:
function Component({ isLoggedIn }) {
  const data = useData()
  
  if (!isLoggedIn) return null
  return <div>{data}</div>
}
```

## "Cannot read properties of null (reading 'useState')" 

Cause: Multiple versions of React in the project (monorepo issues, or plugin using different React version).

Fix:
```bash
# Check for duplicate React:
npm ls react
# Should show only one version

# In monorepo, alias React in vite/webpack config:
resolve: {
  alias: {
    react: path.resolve('./node_modules/react'),
  },
}
```

## useEffect Infinite Loop

```typescript
// WRONG — dependency changes on every render:
useEffect(() => {
  setData(processData(rawData))
}, [processData])  // processData is recreated each render → infinite loop

// WRONG — object/array dependency:
useEffect(() => {
  fetchData(config)
}, [config])  // config = { key: 'value' } recreated each render → infinite loop

// CORRECT — primitive dependency:
useEffect(() => {
  fetchData(userId)
}, [userId])  // string/number compares by value — stable

// CORRECT — memoize function:
const processData = useCallback((data) => {
  return data.map(transform)
}, [transform])  // only recreates when transform changes

// CORRECT — memoize object/array dependency:
const config = useMemo(() => ({ key: value }), [value])
```

## stale closure in useEffect

```typescript
// WRONG — count is captured at effect creation time:
useEffect(() => {
  const interval = setInterval(() => {
    setCount(count + 1)  // stale closure — always 0 + 1 = 1
  }, 1000)
  return () => clearInterval(interval)
}, [])  // empty deps = never re-runs = count is always 0

// CORRECT — use functional update:
useEffect(() => {
  const interval = setInterval(() => {
    setCount(c => c + 1)  // uses current value
  }, 1000)
  return () => clearInterval(interval)
}, [])  // empty deps fine with functional update
```

## useContext Returns undefined

```typescript
// WRONG — using context outside its provider:
function ComponentOutsideProvider() {
  const user = useContext(UserContext)  // undefined
}

// Component must be inside the Provider:
function App() {
  return (
    <UserProvider>
      <ComponentOutsideProvider />  {/* now has access */}
    </UserProvider>
  )
}

// Add a safety check:
export function useUser() {
  const context = useContext(UserContext)
  if (context === undefined) {
    throw new Error('useUser must be used within UserProvider')
  }
  return context
}
```

## useRef vs useState for Non-Reactive Values

```typescript
// WRONG — using useState for a value that shouldn't trigger re-renders:
const [timerId, setTimerId] = useState<NodeJS.Timeout | null>(null)
// Changing timerId triggers re-render — unnecessary

// CORRECT — use useRef for values that don't affect rendering:
const timerRef = useRef<NodeJS.Timeout | null>(null)
timerRef.current = setTimeout(...)  // no re-render
```

## "Can't perform state update on unmounted component"

```typescript
// WRONG — setting state after component unmounts:
useEffect(() => {
  fetchData().then(data => setState(data))  // might unmount during fetch
}, [])

// CORRECT — check if still mounted:
useEffect(() => {
  let mounted = true
  fetchData().then(data => {
    if (mounted) setState(data)
  })
  return () => { mounted = false }
}, [])

// OR — use AbortController:
useEffect(() => {
  const controller = new AbortController()
  fetch('/api/data', { signal: controller.signal })
    .then(r => r.json())
    .then(data => setState(data))
    .catch(e => { if (e.name !== 'AbortError') console.error(e) })
  return () => controller.abort()
}, [])
```

## Custom Hook Not Updating After Prop Change

```typescript
// WRONG — hook doesn't react to prop changes:
function useInvoice(id: string) {
  const [invoice, setInvoice] = useState(null)
  
  useEffect(() => {
    fetchInvoice(id).then(setInvoice)
  }, [])  // empty deps — only runs once even if id changes
  
  return invoice
}

// CORRECT — include id in deps:
useEffect(() => {
  fetchInvoice(id).then(setInvoice)
}, [id])  // re-runs when id changes
```
