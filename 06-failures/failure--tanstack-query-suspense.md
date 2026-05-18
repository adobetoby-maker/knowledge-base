# Failure: TanStack Query with React Suspense

## Overview
Integrating TanStack Query with React Suspense requires both sides to be configured correctly. When `suspense` mode is enabled, React Query throws a Promise to trigger the Suspense boundary — but if no `<Suspense>` boundary exists above the component, React propagates the throw to the nearest error boundary or crashes. Mixing suspense and non-suspense queries in the same component produces inconsistent behavior. TanStack Query v5 introduced `useSuspenseQuery` to make this opt-in per query, eliminating ambiguity.

## How Suspense Integration Works

When `suspense: true` is set (v4) or `useSuspenseQuery` is used (v5), the query hook throws:
- A **Promise** when loading (causing `<Suspense>` to show the fallback)
- An **Error** when the query fails (causing `<ErrorBoundary>` to catch it)

The component never renders in a loading or error state — it either renders with data or doesn't render at all.

## v4 Suspense (suspense option)

```typescript
// v4: opt-in with suspense option
function UserProfile({ userId }: { userId: string }) {
  const { data: user } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    suspense: true,  // Throws Promise while loading
  });

  // data is guaranteed to be defined here — no need for null checks
  return <div>{user.name}</div>;
}

// Required: Suspense + ErrorBoundary boundaries above
function App() {
  return (
    <ErrorBoundary fallback={<div>Error loading user</div>}>
      <Suspense fallback={<div>Loading...</div>}>
        <UserProfile userId="1" />
      </Suspense>
    </ErrorBoundary>
  );
}
```

## v5 Suspense (useSuspenseQuery)

TanStack Query v5 replaces the `suspense` option with dedicated hooks:

```typescript
import { useSuspenseQuery, useSuspenseQueries } from '@tanstack/react-query';

function UserProfile({ userId }: { userId: string }) {
  // Explicitly suspense — data is always defined
  const { data: user } = useSuspenseQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  });

  return <div>{user.name}</div>;  // TypeScript knows data is User, not User | undefined
}

// Multiple suspense queries in parallel
function Dashboard({ userId }: { userId: string }) {
  const [{ data: user }, { data: orders }] = useSuspenseQueries({
    queries: [
      { queryKey: ['user', userId], queryFn: () => fetchUser(userId) },
      { queryKey: ['orders', userId], queryFn: () => fetchOrders(userId) },
    ],
  });
  // Both resolved — no loading states needed
  return <div>{user.name}: {orders.length} orders</div>;
}
```

## The Missing Boundary Crash

```typescript
// BROKEN: useSuspenseQuery with no Suspense boundary above
function App() {
  return (
    <div>
      <UserProfile userId="1" />  {/* Throws Promise → propagates to root → crash */}
    </div>
  );
}

// FIXED: Suspense boundary catches the thrown Promise
function App() {
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userId="1" />
    </Suspense>
  );
}
```

The error in React: `A React component suspended while rendering, but no fallback UI was specified.`

## Mixing Suspense and Non-Suspense Queries

```typescript
// PROBLEMATIC: mixing in the same component
function Component() {
  const { data: a } = useSuspenseQuery({ queryKey: ['a'], queryFn: fetchA });
  const { data: b, isLoading: bLoading } = useQuery({ queryKey: ['b'], queryFn: fetchB });

  // 'a' is always defined (suspense threw until it was ready)
  // 'b' may be undefined (no suspense — component renders before b is ready)
  // This inconsistency makes the component logic confusing
}

// BETTER: consistent — either all suspense or none
function Component() {
  const [{ data: a }, { data: b }] = useSuspenseQueries({ queries: [...] });
  // Both guaranteed to be defined
}
```

## Error Handling with Suspense

`useSuspenseQuery` throws errors — they must be caught by an `<ErrorBoundary>`:

```typescript
import { ErrorBoundary } from 'react-error-boundary';

function App() {
  return (
    <ErrorBoundary
      fallback={<div>Something went wrong</div>}
      onError={(error) => logger.error(error)}
    >
      <Suspense fallback={<LoadingSpinner />}>
        <UserProfile userId="1" />
      </Suspense>
    </ErrorBoundary>
  );
}
```

Without `<ErrorBoundary>`, a failed query throws an unhandled error that crashes the component tree.

## Key Rules
- `useSuspenseQuery` (v5) requires a `<Suspense>` boundary above the component in the tree
- Every Suspense boundary should have a co-located `<ErrorBoundary>` — failures throw errors, not just Promises
- Don't mix `useSuspenseQuery` and `useQuery` in the same component — pick one pattern and be consistent
- In v5, `useSuspenseQuery` data is typed as `T` (not `T | undefined`) — TypeScript enforces this correctly
- `useSuspenseQueries` fetches multiple queries in parallel and suspends until all are complete
- Suspense boundaries can be nested — inner boundaries provide more granular loading states
