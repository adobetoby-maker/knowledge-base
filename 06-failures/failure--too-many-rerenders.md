# Failure: Too Many Re-renders

React throws "Too many re-renders. React limits the number of renders to prevent an infinite loop" when a component triggers its own state update synchronously during render. The error is a hard stop — the component cannot mount or paint until the cycle is broken.

## Root Causes

### 1. Calling setState During Render
The most common form: calling a state setter directly in the function body, not inside an effect or event handler.

```tsx
// WRONG — runs on every render, triggers another render
function Counter() {
  const [count, setCount] = useState(0);
  setCount(count + 1); // called during render
  return <div>{count}</div>;
}
```

Move mutations into `useEffect` with correct deps, or into an event handler. State updates during render are only valid in very narrow cases (derived state correction — and even then, conditional guards are mandatory).

### 2. Effect with Unstable Dependencies Creating a Loop
An effect that runs, updates state, which changes a dep that triggers the effect again:

```tsx
// WRONG — options is recreated on every render, effect fires every render
const options = { page: 1 }; // new object reference each render
useEffect(() => {
  fetchData(options).then(setData);
}, [options]); // options always "changed"
```

The fix: move the object *inside* the effect (no dep needed), or memoize it with `useMemo` outside if it depends on props/state, or use `useRef` if the value never needs to trigger re-renders.

### 3. Object/Array Literals as Effect Dependencies
Referential equality governs `useEffect` deps. `{}` !== `{}` and `[]` !== `[]` even with identical contents. Every render creates a new reference, so the effect sees a "changed" dep every time.

```tsx
// WRONG
useEffect(() => { ... }, [{ id: userId }]); // new object each render

// RIGHT — depend on the primitive
useEffect(() => { ... }, [userId]);
```

### 4. Event Handler Passed as Callback Recreated Each Render
```tsx
// WRONG — child receives new fn ref each render, triggers its own effect
<Child onChange={() => setState(...)} />
```

Wrap with `useCallback` to stabilize the reference. The deps of `useCallback` must be accurate — an empty dep array with stale state is a different bug (stale closure).

## useRef for Stable References

`useRef` holds a mutable value that does not trigger re-renders when changed. Use it when you need to track a value across renders without causing renders — previous values, timer IDs, abort controllers, or DOM nodes.

```tsx
const prevValue = useRef(value);
useEffect(() => {
  prevValue.current = value; // mutate without triggering render
});
```

Never put a ref in a `useEffect` dep array. Refs are intentionally outside the reactive system.

## useMemo/useCallback for Stable Values

`useMemo` computes a value once and returns the same reference until deps change. `useCallback` does the same for functions. Both exist to prevent downstream effects and memoized children from seeing false "changes."

Only add these when you have a measured or obvious instability problem. Premature memoization adds noise and can hide real bugs.

## Key Rules

- Never call state setters in the render body without a conditional guard for derived-state correction.
- Depend on primitives in effect dep arrays, not derived objects/arrays created inline.
- Use `useMemo` to stabilize objects/arrays that flow into effect deps or memoized children.
- Use `useCallback` to stabilize callbacks passed as props to components that use `React.memo` or have their own effects.
- Use `useRef` when you need to remember a value across renders but the value itself should not cause a render.
- When you see the "too many re-renders" error, bisect by commenting out `useEffect` hooks one at a time to isolate the cycle.
