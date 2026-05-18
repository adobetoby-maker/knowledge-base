# TanStack Query: useMutation vs useQuery

## The Semantic Distinction

`useQuery` is for reading. `useMutation` is for writing. This is not just a naming convention — they have fundamentally different behavior because reads and writes have fundamentally different semantics.

**`useQuery`** runs automatically when the component mounts (and re-runs on refocus, reconnect, and when its key becomes stale). It is declarative: "always show me the current state of this data."

**`useMutation`** is imperative: "do this specific action when I say to." It does not run on mount, does not re-run automatically, and does not have a cache key in the query cache. It is a function you call.

## Why Using useQuery for Mutations Breaks Things

A common mistake is fetching with `useQuery` and then using the same hook to perform a write action:

```ts
// WRONG — never do this
const { refetch: createUser } = useQuery({
  queryKey: ['user', 'create'],
  queryFn: () => fetch('/api/users', { method: 'POST', body: ... }),
  enabled: false, // trying to prevent auto-run
});
```

This has multiple failure modes:
1. The query cache stores the mutation result, associating `['user', 'create']` with stale POST response data.
2. Background refetch intervals, window focus refetches, and retry logic apply to mutations — you can accidentally POST the same data multiple times.
3. Cache invalidation after a mutation (which should trigger GET refetches) may accidentally trigger another POST.

## The Optimistic Update Pattern

`useMutation` is designed for optimistic updates via its lifecycle callbacks:

```ts
const mutation = useMutation({
  mutationFn: (newTodo) => api.createTodo(newTodo),
  onMutate: async (newTodo) => {
    // Cancel outgoing refetches so they don't overwrite optimistic update
    await queryClient.cancelQueries({ queryKey: ['todos'] });
    // Snapshot current value for rollback
    const previous = queryClient.getQueryData(['todos']);
    // Apply optimistic update
    queryClient.setQueryData(['todos'], (old) => [...old, newTodo]);
    return { previous }; // returned as context
  },
  onError: (err, newTodo, context) => {
    // Roll back on failure
    queryClient.setQueryData(['todos'], context.previous);
  },
  onSettled: () => {
    // Always refetch to get authoritative server state
    queryClient.invalidateQueries({ queryKey: ['todos'] });
  },
});
```

`useQuery` has none of these callbacks — it has no mechanism for optimistic rollback because reads never need to roll back.

## invalidateQueries vs setQueryData on Success

After a mutation succeeds, you have two ways to update the cache:

**`invalidateQueries`:** Marks cached data as stale, triggering a background refetch. Use this when: you want authoritative server data, the mutation might affect multiple queries, or the new server state is unpredictable from the mutation input alone. The correct default in most cases.

**`setQueryData`:** Directly writes to the cache without a network request. Use this when: the server response contains the full updated entity, you want to avoid a round-trip, and you trust the response is the complete new state. Optimistic updates use this pattern, then confirm with `invalidateQueries` in `onSettled`.

Do not use `setQueryData` without a subsequent `invalidateQueries` on `onSettled` — you risk the cache drifting from server truth if the mutation partially succeeded or the server applied additional transforms.

## Dependent Mutations

When one mutation must complete before another can start, chain them in the `onSuccess` callback — do not use `useQuery` with `enabled: !!previousResult` as a hack to sequence writes.

## Key Rules

- **Never use `useQuery` to trigger side effects** (POST, PUT, DELETE, PATCH) — use `useMutation`.
- **Always include `onSettled: () => invalidateQueries(...)`** in mutations that change server state — this ensures cache coherence even when optimistic updates are not used.
- **Always include `onError` rollback** when using `onMutate` for optimistic updates — missing rollback leaves the UI permanently wrong on server error.
- Use `cancelQueries` in `onMutate` before applying an optimistic update — without it, an in-flight refetch can overwrite your optimistic state immediately.
- `mutate` is fire-and-forget; `mutateAsync` returns a Promise — use `mutateAsync` when you need to `await` the result or chain `.then()` / `catch()` inline.
