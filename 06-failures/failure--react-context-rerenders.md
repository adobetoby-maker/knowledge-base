# Failure: React Context Re-renders

React Context re-renders every subscribed consumer whenever the context value changes — even if the specific data the consumer uses didn't change. In large component trees this causes cascading renders that make the UI feel sluggish without any obvious CPU bottleneck.

## Why This Happens

`React.createContext` stores a single value. When the Provider's value prop changes (by reference), React queues a re-render for every component that called `useContext` for that context, regardless of what part of the value they read. There is no built-in selector mechanism in the base Context API.

The most common trigger: the value object is created inline in the Provider:

```tsx
// WRONG — new object every render, all consumers re-render every render
function AppProvider({ children }) {
  const [user, setUser] = useState(null);
  const [theme, setTheme] = useState('light');

  return (
    <AppContext.Provider value={{ user, setUser, theme, setTheme }}>
      {children}
    </AppContext.Provider>
  );
}
```

Every time `AppProvider` renders (for any reason), a new `{ user, setUser, theme, setTheme }` object is created. Consumers see a "new" value and re-render, even if `user` and `theme` didn't change.

## Fix 1: Memoize the Context Value

```tsx
const value = useMemo(
  () => ({ user, setUser, theme, setTheme }),
  [user, theme] // setUser and setTheme from useState are stable — omit
);

return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
```

This makes the value reference stable when the actual data hasn't changed. Consumers only re-render when `user` or `theme` changes.

Note: `useMemo` prevents re-renders of consumers but not of the Provider itself. The Provider will still re-render on parent re-renders; it just won't broadcast those renders downstream.

## Fix 2: Split Context into Smaller Pieces

One large context with many unrelated values means consumers re-render whenever any of those values changes. Split by domain:

```tsx
// Separate contexts — theme consumers don't re-render when user changes
const UserContext = createContext(null);
const ThemeContext = createContext(null);
```

This is the most impactful change. A component reading only theme should never re-render because the user changed. Splitting enforces this at the architecture level.

A useful heuristic: values that change together belong in the same context; values that change independently belong in separate contexts.

## Fix 3: Separate Data and Dispatch

A common pattern: one context for read-only data (triggers re-renders when data changes), one for dispatch functions (stable references, never triggers re-renders):

```tsx
const StateContext = createContext(null);   // re-renders consumers
const DispatchContext = createContext(null); // never re-renders consumers

function Provider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  return (
    <DispatchContext.Provider value={dispatch}>
      <StateContext.Provider value={state}>
        {children}
      </StateContext.Provider>
    </DispatchContext.Provider>
  );
}
```

Components that only dispatch actions (buttons, form handlers) subscribe only to `DispatchContext` and never re-render when state changes.

## When Zustand Is a Better Fit

Context is well-suited for: auth state, theme, locale, and other values that change rarely and need to be accessible deep in the tree.

Context struggles when: many components subscribe to different slices of a frequently-updating store, or when you need selector-based re-render optimization.

Zustand (and similar stores like Jotai or Redux) provide built-in selector support:

```ts
const count = useStore((state) => state.count); // only re-renders when count changes
```

If you find yourself splitting context into 5+ pieces, adding complex memoization, or building a custom subscription layer — reach for Zustand instead. It solves the selector problem correctly and with less boilerplate.

## Key Rules

- Never create the context value object inline in the Provider — always `useMemo` it.
- Split contexts by change frequency and consumer domain, not by convenience.
- Dispatch functions (from `useReducer` or `useState`) are stable — put them in their own context so action-only components don't re-render on state changes.
- `React.memo` on consumers does not help with context — memo only blocks re-renders from parent props, not from context subscriptions.
- When context optimization becomes complicated, evaluate Zustand: its selector-based subscriptions are purpose-built for this problem.
- Profile before optimizing: use React DevTools Profiler to confirm context is actually the bottleneck before restructuring.
