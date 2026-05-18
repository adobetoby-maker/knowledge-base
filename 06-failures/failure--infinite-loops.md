# Failure: Infinite Loops

## Overview

Infinite loops in production manifest as CPU spikes, memory exhaustion, or hanging processes. React causes: `useEffect` with a dependency that changes every render, `setState` inside a `useEffect` that watches the state it sets. Node.js causes: recursive functions without base case, `while (true)` without exit, event emitter circular emissions.

## React: useEffect Dependency Loops

```tsx
// BAD — infinite loop
function BadComponent({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    fetchUser(userId).then(setUser)
  }, [user])  // ← depends on user, which is set by this effect → re-runs forever
}

// GOOD — depend on the stable input, not the derived state
function GoodComponent({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null)

  useEffect(() => {
    fetchUser(userId).then(setUser)
  }, [userId])  // ← depends on the prop that triggers the fetch
}
```

## React: Object/Array Dependencies

```tsx
// BAD — new object reference on every render
function BadFilters() {
  const [items, setItems] = useState([])
  const filters = { status: 'active', page: 1 }  // New object each render

  useEffect(() => {
    fetchItems(filters).then(setItems)
  }, [filters])  // Object reference changes every render → infinite loop

  // GOOD — primitive values or useMemo
  const status = 'active'
  const page = 1
  useEffect(() => {
    fetchItems({ status, page }).then(setItems)
  }, [status, page])  // Primitives are stable
}

// Or stabilize with useMemo
const filters = useMemo(() => ({ status, page }), [status, page])
```

## React: setState Triggering Re-render Loop

```tsx
// BAD — derived state update triggers re-render triggers re-update
function BadCart() {
  const [items, setItems] = useState<CartItem[]>([])
  const [total, setTotal] = useState(0)

  useEffect(() => {
    setTotal(items.reduce((sum, item) => sum + item.price, 0))
  }, [items, total])  // total in deps causes infinite loop
  //                     ^^^^ THIS IS THE BUG

  // GOOD — compute derived values directly, no setState
  const total = items.reduce((sum, item) => sum + item.price, 0)
}
```

## Node.js: Recursive Without Base Case

```ts
// BAD — no termination when retries are exhausted
async function fetchWithRetry(url: string): Promise<Response> {
  try {
    return await fetch(url)
  } catch {
    return fetchWithRetry(url)  // No counter → infinite recursion → stack overflow
  }
}

// GOOD — explicit counter with maximum
async function fetchWithRetry(url: string, attempts = 3): Promise<Response> {
  try {
    return await fetch(url)
  } catch (err) {
    if (attempts <= 1) throw err
    await new Promise(r => setTimeout(r, 1000))
    return fetchWithRetry(url, attempts - 1)
  }
}
```

## Circular Event Emissions

```ts
// BAD — A emits → B listens, B emits → A listens → loop
emitter.on('update-a', () => emitter.emit('update-b'))
emitter.on('update-b', () => emitter.emit('update-a'))

// GOOD — break the cycle with a flag
let updating = false
emitter.on('update-a', () => {
  if (updating) return
  updating = true
  emitter.emit('update-b')
  updating = false
})
```

## Database Triggers: Circular Updates

```sql
-- BAD — trigger on orders updates total, update triggers the trigger again
CREATE TRIGGER after_order_update AFTER UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION recalculate_total();

-- recalculate_total also updates orders.total → triggers the trigger again → infinite

-- GOOD — check if the relevant columns actually changed
CREATE OR REPLACE FUNCTION recalculate_total() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.items IS DISTINCT FROM OLD.items THEN
    UPDATE orders SET total = calculate_total(NEW.id) WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## Detection

```bash
# Node.js: detect runaway process
top -pid $(pgrep -f "node server")  # CPU > 90% sustained

# React: React DevTools Profiler shows component re-rendering thousands of times

# Infinite loop in while loop — add iteration guard in dev
let iter = 0
while (condition) {
  if (++iter > 10_000) throw new Error('Iteration limit exceeded — possible infinite loop')
  // ... loop body
}
```

## Key Rules

- In `useEffect`, depend on the values that CAUSE the effect, not the values PRODUCED by the effect.
- Never put objects or arrays inline in `useEffect` dependencies — they create new references on every render.
- Derived state (totals, counts, formatted values) should be computed during render, not stored in `useState`.
- Recursive functions must have a base case and a counter — never rely solely on a condition that could perpetually evaluate to true.
- In database triggers, check `NEW.column IS DISTINCT FROM OLD.column` before executing updates that would re-fire the trigger.
