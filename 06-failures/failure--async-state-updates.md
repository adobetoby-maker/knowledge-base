# Failure: Async State Update Bugs

## Overview

Stale closures, race conditions in async functions, and state updates after unmount are the most common async state bugs in React. They produce: UI showing old data after mutation, multiple in-flight requests clobbering each other, and "Can't perform a React state update on an unmounted component" warnings.

## Stale Closure

```tsx
// BAD — handleTimeout captures count = 0, never sees updates
function BadTimer() {
  const [count, setCount] = useState(0)

  useEffect(() => {
    const id = setInterval(() => {
      console.log(count)    // Always logs 0
      setCount(count + 1)   // Always sets 0 + 1 = 1
    }, 1000)
    return () => clearInterval(id)
  }, [])  // Empty deps — closure captures initial count

  // GOOD — use functional update form
  useEffect(() => {
    const id = setInterval(() => {
      setCount(c => c + 1)  // Reads latest value from React
    }, 1000)
    return () => clearInterval(id)
  }, [])
}
```

## Race Condition in Fetch

```tsx
// BAD — fast second response can arrive before slow first response
function BadSearch({ query }: { query: string }) {
  const [results, setResults] = useState([])

  useEffect(() => {
    fetch(`/api/search?q=${query}`)
      .then(r => r.json())
      .then(setResults)  // Race: if query changes quickly, old result can overwrite new
  }, [query])

  // GOOD — cancel previous request with AbortController
  useEffect(() => {
    const controller = new AbortController()

    fetch(`/api/search?q=${query}`, { signal: controller.signal })
      .then(r => r.json())
      .then(setResults)
      .catch(err => {
        if (err.name !== 'AbortError') setResults([])
      })

    return () => controller.abort()  // Cancel on next effect run (new query)
  }, [query])
}
```

## Update After Unmount

```tsx
// BAD — if component unmounts before fetch completes, setState crashes
function BadUserCard({ userId }: { userId: string }) {
  const [user, setUser] = useState(null)

  useEffect(() => {
    fetchUser(userId).then(u => setUser(u))  // Could set after unmount
  }, [userId])

  // GOOD — check mounted state
  useEffect(() => {
    let mounted = true
    fetchUser(userId).then(u => {
      if (mounted) setUser(u)
    })
    return () => { mounted = false }
  }, [userId])
}
```

Note: React 18 suppresses the unmount warning but state updates after unmount are still wasted work.

## Concurrent Mutation Conflict

```tsx
// BAD — two clicks submit two concurrent mutations
function LikeButton({ postId }: { postId: string }) {
  const [liked, setLiked] = useState(false)

  const toggle = async () => {
    setLiked(!liked)            // Optimistic
    await api.post('/api/like', { postId, liked: !liked })
    // If user double-clicks: second call sees stale `liked`
  }

  // GOOD — disable during mutation
  const [pending, setPending] = useState(false)

  const toggle = async () => {
    if (pending) return
    setPending(true)
    const newLiked = !liked
    setLiked(newLiked)
    try {
      await api.post('/api/like', { postId, liked: newLiked })
    } catch {
      setLiked(!newLiked)  // Revert on error
    } finally {
      setPending(false)
    }
  }
}
```

## Stale TanStack Query Cache

```tsx
// BAD — editing and then reading from stale cache
async function onSave(data: FormData) {
  await updateUser(data)
  // queryClient.getQueryData(['user', userId]) still has old data here!
}

// GOOD — invalidate after mutation
const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['user', userId] })
    // Now the cache refetches
  },
})
```

## State Batching (React 18)

```tsx
// React 18: all setStates in async functions are batched (not just in event handlers)
async function fetchAndUpdate() {
  const data = await fetch('/api/data')
  setLoading(false)
  setData(data)  // These two setStates produce ONE re-render in React 18
  setError(null) // Even in an async context
}

// If you need to force separate renders (rare), use flushSync
import { flushSync } from 'react-dom'
flushSync(() => setLoading(false))
setData(data)
```

## Key Rules

- Use functional update form `setState(prev => ...)` whenever new state depends on previous state.
- Always abort fetch requests in `useEffect` cleanup using `AbortController`.
- Track in-flight mutations with a `pending` flag or `useMutation.isPending` — disable the trigger while active.
- `useEffect` cleanup = cancel async work. `mounted = false` prevents post-unmount state updates.
- TanStack Query mutations should always `invalidateQueries` on success — don't read from cache after write.
