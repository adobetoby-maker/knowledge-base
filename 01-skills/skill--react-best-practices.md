# Skill: react-best-practices

**Trigger:** Writing React 19 components, hooks, context, effects, refs, or optimizing renders.
**Invoke:** `/react-best-practices`
**Returns:** React 19 patterns, hooks best practices, performance optimization, composition patterns, common mistake prevention.

## When to Invoke
- Writing a component with complex state
- Struggling with re-render performance
- Setting up context providers
- Using useEffect and unsure about cleanup
- Working with refs
- Need optimistic UI patterns
- React 19 `use()` hook questions

## State Placement Rules
Start at `useState`, promote up only when needed:
1. `useState` — component only uses it
2. Lift to parent — sibling components need to share
3. Context — deeply nested tree needs same data
4. External store (Zustand) — context causes too many re-renders

## useEffect Rules
```typescript
// WRONG — fetching in useEffect
useEffect(() => {
  fetch('/api/data').then(setData)
}, [])

// RIGHT — TanStack Query for server data
const { data } = useQuery({ queryKey: ['data'], queryFn: fetchData })

// CORRECT useEffect — synchronizing with external system
useEffect(() => {
  const subscription = external.subscribe(handler)
  return () => subscription.unsubscribe()  // ALWAYS cleanup
}, [handler])
```

## React 19 Features
```typescript
// use() hook — unwraps promises and context
function Profile({ userPromise }) {
  const user = use(userPromise)  // suspends until resolved
  return <div>{user.name}</div>
}

// useOptimistic — instant UI feedback before server confirms
const [optimisticLikes, addLike] = useOptimistic(
  serverLikes,
  (state, increment) => state + increment
)

// useFormStatus — knows if parent form is submitting
function SubmitButton() {
  const { pending } = useFormStatus()
  return <button disabled={pending}>Submit</button>
}

// useActionState — server action + state in one
const [state, formAction] = useActionState(serverAction, null)
```

## Memoization — Use Sparingly
```typescript
// useMemo — expensive calculation, not re-run on every render
const sorted = useMemo(() => items.sort(compareFn), [items])

// useCallback — stable function reference for child components
const handleClick = useCallback(() => doThing(id), [id])

// React.memo — skip re-render if props unchanged
const Card = memo(function Card({ title }) {
  return <div>{title}</div>
})

// RULE: Profile first, memoize after. Most components don't need it.
```

## Composition Over Props Drilling
```typescript
// WRONG — prop drilling
<Parent data={data}><Child data={data}><GrandChild data={data}/></Child></Parent>

// RIGHT — children composition (no context needed)
<Parent>
  <Child>
    <GrandChild data={data}/>  {/* only component that needs it gets it */}
  </Child>
</Parent>
```

## Ref Patterns
```typescript
// Access DOM element
const inputRef = useRef<HTMLInputElement>(null)
inputRef.current?.focus()

// Store mutable value that doesn't cause re-render
const timerRef = useRef<NodeJS.Timeout>()
timerRef.current = setTimeout(() => {}, 1000)

// Forward ref for reusable components
const Input = forwardRef<HTMLInputElement, Props>((props, ref) => (
  <input ref={ref} {...props} />
))
```

## What Skill Returns
Full React 19 API reference, concurrent features, Suspense patterns, error boundaries, performance profiling, and form patterns.
