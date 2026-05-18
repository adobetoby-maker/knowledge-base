# Failure: React Stale Closure

**Symptom:** Event handler or effect uses an outdated value — shows old data, updates don't reflect latest state, or counter always increments from the same starting value.

## Why It Happens
When a function is created inside a component, it "closes over" the current values of state and props. If that function is reused across renders without being recreated, it still sees the OLD values from when it was created — a stale closure.

```typescript
// WRONG — setInterval closes over initial `count` value (0)
const [count, setCount] = useState(0)

useEffect(() => {
  const id = setInterval(() => {
    setCount(count + 1)  // `count` is always 0 — stale closure
  }, 1000)
  return () => clearInterval(id)
}, [])  // Empty deps = effect never re-runs = closure never refreshes
// Result: count stays at 1, never goes higher
```

## Fix 1 — Functional State Updater
Use the function form of setState which receives the current value:
```typescript
useEffect(() => {
  const id = setInterval(() => {
    setCount(c => c + 1)  // `c` is always current value — no stale closure
  }, 1000)
  return () => clearInterval(id)
}, [])
```
This is the fix for any situation where you're updating state based on its previous value.

## Fix 2 — Add to Dependencies (re-create the effect)
```typescript
// WRONG — stale closure on `user`
useEffect(() => {
  socket.on('message', (msg) => {
    setMessages(prev => [...prev, { ...msg, sender: user.name }])  // user is stale
  })
}, [])

// RIGHT — include user in deps, effect re-runs when user changes
useEffect(() => {
  socket.on('message', (msg) => {
    setMessages(prev => [...prev, { ...msg, sender: user.name }])
  })
  return () => socket.off('message')
}, [user.name])  // now user.name is fresh when it changes
```

## Fix 3 — useRef for Mutable Values Without Re-render
When you need the latest value in a callback but don't want the effect to re-run:
```typescript
// Pattern: keep a ref that mirrors state
const [user, setUser] = useState<User>(...)
const userRef = useRef(user)
useEffect(() => { userRef.current = user }, [user])

// The callback always reads from the ref — always fresh
useEffect(() => {
  socket.on('message', (msg) => {
    const currentUser = userRef.current  // always latest value
    setMessages(prev => [...prev, { ...msg, sender: currentUser.name }])
  })
  return () => socket.off('message')
}, [])  // effect doesn't need to re-run when user changes
```

## Fix 4 — useCallback with Correct Dependencies
```typescript
// WRONG — handleSubmit closes over stale formData
const handleSubmit = useCallback(() => {
  sendForm(formData)
}, [])

// RIGHT — include formData in deps
const handleSubmit = useCallback(() => {
  sendForm(formData)
}, [formData])  // recreated when formData changes
```

## Diagnostic: Is This a Stale Closure?
Add a debug log inside the handler:
```typescript
useEffect(() => {
  const id = setInterval(() => {
    console.log('current count in closure:', count)  // if this stays at 0, it's stale
    setCount(count + 1)
  }, 1000)
  return () => clearInterval(id)
}, [])
```
If the log shows the same value every time while the UI shows a different value, it's stale.

## The ESLint Rule That Prevents This
```json
// .eslintrc
"react-hooks/exhaustive-deps": "error"
```
This rule forces you to include all dependencies — the most common cause of stale closures is a missing dependency.
