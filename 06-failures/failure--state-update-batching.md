# failure--state-update-batching.md

React batches state updates to avoid unnecessary re-renders. In React 18, this was extended to cover all updates — including those inside async callbacks, `setTimeout`, and native event handlers — not just React synthetic events. This is almost always what you want, but it produces surprises when code assumes a state value is immediately available after calling `setState`.

## The Core Misconception

Calling `setState` schedules an update. It does not apply that update to the current variable. Reading the state variable immediately after calling `setState` returns the old value:

```ts
const [count, setCount] = useState(0);

function handleClick() {
  setCount(count + 1);
  console.log(count); // still 0 — the update hasn't applied yet
}
```

This is not a batching issue — it's a closure issue. `count` was captured at render time. Even without batching, `count` would still be `0` in this function. The new value only exists in the next render's closure.

## React 18 Automatic Batching

Before React 18, updates inside `setTimeout`, `fetch` callbacks, and native event listeners triggered a re-render per `setState` call. React 18 batches all of them automatically. This means code that relied on intermediate re-renders between async state updates will behave differently.

```ts
setTimeout(() => {
  setA(1);   // React 18: batched — one re-render
  setB(2);   // React 17: two re-renders
}, 1000);
```

This is a net positive for performance, but if intermediate render state was load-bearing (e.g., a loading spinner set by one setState before data is set by another), the spinner may never appear.

## Opting Out: flushSync

When you genuinely need a synchronous DOM update between state changes — measuring layout, integrating with non-React libraries, or animating between discrete states — use `flushSync` to force a synchronous flush:

```ts
import { flushSync } from 'react-dom';

flushSync(() => {
  setLoading(true);
});
// DOM has updated here — reading layout dimensions is now safe
flushSync(() => {
  setData(result);
});
```

Use `flushSync` sparingly. It defeats the performance benefits of batching and can cause cascading synchronous renders if called frequently.

## Functional Updater for Derived State

When the new state depends on the previous value, use the functional updater form. It receives the most recent state value at the time of application — not the stale closure value:

```ts
// Wrong — multiple rapid calls will all use the same stale `count`
setCount(count + 1);
setCount(count + 1); // still count + 1, not count + 2

// Right — each call receives the result of the previous
setCount(prev => prev + 1);
setCount(prev => prev + 1); // correctly produces count + 2
```

This matters most in event handlers that fire rapidly (mouse move, scroll, resize) and in useEffect cleanup functions.

## Batching in useEffect

State updates triggered inside `useEffect` are also batched. But effects run after paint — if you're setting state inside an effect, you're already paying for one extra render cycle. Setting two pieces of state together in a single effect produces one re-render, which is correct, but restructuring into a single state object or `useReducer` is usually cleaner than multiple paired `useState` calls.

## Key Rules

- Reading state immediately after `setState` returns the stale value — the update hasn't been applied to the current render's variables.
- React 18 batches all updates, including those in async callbacks and `setTimeout` — two `setState` calls in a callback produce one re-render, not two.
- Use `flushSync` only when you need a synchronous DOM update between state changes; it's expensive.
- Use the functional updater `setState(prev => ...)` whenever new state derives from previous state, especially in rapid-fire handlers.
- Multiple related state variables that always change together are a signal to use `useReducer` or a single state object.
