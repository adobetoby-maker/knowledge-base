# Failure: Premature React.memo Usage

## Overview
`React.memo` is a performance optimization that prevents a component from re-rendering when its props have not changed. But it is not free — every render of the parent invokes a shallow comparison of all props. When applied indiscriminately ("wrap everything in memo to make it faster"), the comparison overhead can exceed the cost of the re-renders being prevented. Premature `React.memo` makes code harder to read and can actually slow down the application.

## How `React.memo` Works (and Its Cost)

```typescript
const MyComponent = React.memo(({ name, onClick }: Props) => {
  return <button onClick={onClick}>{name}</button>;
});
```

On every parent render, React runs:
```typescript
// Shallow comparison executed for each prop
Object.is(prevProps.name, nextProps.name) &&
Object.is(prevProps.onClick, nextProps.onClick)
// If ALL return true → skip re-render
// If ANY returns false → re-render anyway
```

The comparison is `O(props.length)` work done unconditionally. If the component is cheap to render (a `<button>` with a few classes), the comparison costs more than just re-rendering.

## When `React.memo` Is Worth Using

All three conditions should be true:
1. **The component is expensive to render** — large list, complex calculation, deep tree
2. **The parent re-renders frequently** — high-frequency events (scroll, animation tick, rapid state changes)
3. **Props rarely change** — if props change on every parent render, memo never prevents a re-render

```typescript
// Good candidate: expensive chart with stable data, parent re-renders from unrelated state
const ExpensiveChart = React.memo(({ data, config }: ChartProps) => {
  // Renders a complex D3 visualization — takes ~50ms
  return <canvas ref={chartRef} />;
});

// Bad candidate: cheap button in a form that re-renders on every keystroke
const SubmitButton = React.memo(({ disabled }: { disabled: boolean }) => {
  return <button disabled={disabled}>Submit</button>; // renders in <1ms
});
// The comparison costs as much as the render — no benefit
```

## The Reference Equality Trap

`React.memo` uses shallow comparison. Object and function props are compared by reference. If the parent creates a new object or function on every render, `memo` is always bypassed:

```typescript
// Wrong: new object every render → memo never prevents re-render
function Parent() {
  return (
    <MemoizedChild
      config={{ theme: "dark", size: "lg" }} // ← new object every render
      onClick={() => handleClick(id)} // ← new function every render
    />
  );
}

// Right: stable references with useMemo and useCallback
function Parent() {
  const config = useMemo(() => ({ theme: "dark", size: "lg" }), []);
  const handleClick = useCallback(() => onClick(id), [id, onClick]);
  return <MemoizedChild config={config} onClick={handleClick} />;
}
```

Now `useMemo` and `useCallback` are also overhead — you've added two hooks to enable one `memo`. Measure whether this chain of optimizations actually helps.

## `useMemo` — Same Principle

`useMemo` memoizes the result of an expensive calculation:

```typescript
// Worthwhile: genuinely expensive filter + sort on large array
const sortedVisibleItems = useMemo(
  () => items.filter(i => i.active).sort(byDate),
  [items]
);
// Only when: items has 10,000+ entries AND the component re-renders frequently

// Not worthwhile: cheap operation that takes <1ms
const displayName = useMemo(
  () => `${user.firstName} ${user.lastName}`,
  [user.firstName, user.lastName]
);
// Just write: const displayName = `${user.firstName} ${user.lastName}`;
```

## How to Decide: Measure First

```
1. Identify a performance problem (profiler shows slow renders)
2. Open React DevTools Profiler
3. Record a user interaction
4. Find components with high self-time (not children time)
5. Apply memo/useMemo to those specific components
6. Record again — verify the optimization actually helped
7. If not measurably better → revert
```

The React DevTools "Record why each component rendered" option shows what changed to cause a render — use this to confirm props are actually stable before adding `memo`.

## Key Rules
- Never apply `React.memo` speculatively — apply only after profiler identifies a real problem
- `React.memo` requires all props to have stable references — objects/functions need `useMemo`/`useCallback`
- If you need `useMemo` + `useCallback` + `React.memo` together for one optimization, measure carefully — the overhead compounds
- Small, cheap components (`<div>`, `<button>`, icon wrappers) should not be memoized
- The question is not "could this re-render be prevented?" but "is preventing this re-render faster than the comparison?"
- Context consumers re-render on any context value change regardless of memo — memo does not help here
- List items benefit from memo when the list is large and parent updates frequently with stable item props
