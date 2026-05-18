# Principle: State Machines vs Boolean Flag Soup

## The Problem with Flag Accumulation

Features start simple: `isLoading`. Then errors appear: `isLoading` + `isError`. Then success needs distinguishing from empty: `isLoading` + `isError` + `isEmpty`. Then a stale result should show while refetching: `isLoading` + `isError` + `isEmpty` + `isStale`. Then a partial result is valid...

Each individual boolean seems reasonable. The combination is not. With four booleans, there are 16 possible states. Most are nonsensical — `isLoading: true` and `isError: true` simultaneously? What does that mean? What should the UI render? Inevitably, the impossible combinations occur at runtime because nothing prevents them, and the UI renders incorrectly.

The deeper problem: each new boolean adds cross-cutting transitions. "When do we set `isStale`?" requires understanding every path that sets `isLoading`, `isError`, and `isSuccess`. The state logic becomes a maintenance burden that compounds with each addition.

## Finite State Machines as the Fix

A finite state machine (FSM) makes the valid states and transitions explicit. Instead of flags, a single `status` value that can only be one of the defined states:

```ts
type RequestStatus = 'idle' | 'loading' | 'success' | 'error';

interface RequestState {
  status: RequestStatus;
  data: User | null;
  error: Error | null;
}
```

Now impossible combinations are structurally impossible. `status: 'loading'` and `status: 'error'` cannot both be true. Every branch in the UI checks one value, not four.

Transitions become explicit:

```ts
function reduce(state: RequestState, action: Action): RequestState {
  switch (action.type) {
    case 'FETCH':      return { status: 'loading', data: state.data, error: null };
    case 'SUCCESS':    return { status: 'success', data: action.payload, error: null };
    case 'ERROR':      return { status: 'error',   data: null, error: action.payload };
    case 'RESET':      return { status: 'idle',    data: null, error: null };
    default: return state;
  }
}
```

Adding a new valid state requires adding it to the union type — TypeScript immediately flags every switch statement that doesn't handle it.

## TypeScript Union as Lightweight FSM

For complex state with different shapes per status, use a discriminated union:

```ts
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };
```

TypeScript's narrowing ensures that `state.data` is only accessible when `status === 'success'`. You can't accidentally read data in the loading state — the type system prevents it.

```tsx
function Component({ state }: { state: AsyncState<User> }) {
  if (state.status === 'loading') return <Spinner />;
  if (state.status === 'error') return <Error message={state.error.message} />;
  if (state.status === 'success') return <Profile user={state.data} />;
  return null;
}
```

## XState for Complex Machines

XState is warranted when:
- A state has sub-states (e.g., `loading` has a timeout sub-state)
- The same action has different effects depending on current state
- State transitions need guards (conditions) or side effects (actions)
- You want to visualize the state chart during development

For simple fetch states and form submission flows, a union type with a reducer is sufficient. Reach for XState when the number of valid transitions and guards exceeds what fits comfortably in a switch statement.

## Identifying Flag Soup Candidates

The signal: reading a component and needing to hold multiple booleans in your head to understand any given render path. Phrases like "this only renders if A is true but only when B is false, unless C..." are flag soup.

Convert when:
- More than 2 related boolean flags exist on the same state object
- You find yourself adding `if (!isLoading && !isError && isSuccess)` conditions
- A bug report involves "the loading spinner appeared at the same time as an error message"

## Key Rules

- **Two related boolean flags is a warning sign; three is a problem** — convert to a status union.
- **A discriminated union prevents impossible state structurally**, not by convention.
- **TypeScript narrowing on the status field gives compile-time safety** for state-dependent data access.
- **Transitions should be the only place state changes** — never set booleans in ad-hoc `if` blocks outside a reducer.
- **Reach for XState when guards, sub-states, or side effects are needed** — the union-reducer pattern doesn't scale to full hierarchical state charts.
