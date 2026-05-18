# Failure: React Query staleTime and cacheTime Misconfiguration

## Overview
React Query's default `staleTime` of 0 means every query is considered stale immediately after fetching. On every component mount — navigation, tab switch, Suspense re-render — it triggers a background refetch. For data that changes once per day (user profile, app config, feature flags), this produces unnecessary network requests and a visible "flash of old content" as stale data is shown briefly while the refetch completes. Understanding the distinction between `staleTime` and `gcTime` (formerly `cacheTime`) is essential for correct query configuration.

## The Two Key Settings

**`staleTime`** — How long fetched data is considered fresh. During this window, no refetch happens on mount.
- Default: `0` (stale immediately — refetch on every mount)
- `Infinity`: never considered stale (refetch only on explicit invalidation)

**`gcTime`** (formerly `cacheTime` in v4) — How long unused data stays in cache before garbage collection.
- Default: `5 * 60 * 1000` (5 minutes)
- Only relevant when no component is subscribed to the query

The confusion: a query can be **fresh** (in cache, not refetching) or **stale** (in cache, but will refetch on next mount). `gcTime` controls when stale data is evicted from the cache entirely.

## Default Behavior and Its Problems

```typescript
// Default: staleTime=0
const { data: user } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  // staleTime: 0 (default)
});
```

With `staleTime: 0`:
1. User loads the profile page → fetches user
2. User clicks to another page → user query becomes inactive
3. User clicks back to profile page → **immediately fires another fetch** (even if it's been 2 seconds)
4. Brief flash: old data shown while refetch completes → new data replaces it

For user profiles, this is wasteful and creates visible UI flicker.

## Setting staleTime by Data Type

```typescript
// User profile — changes rarely
const { data: user } = useQuery({
  queryKey: ['user', userId],
  queryFn: () => fetchUser(userId),
  staleTime: 5 * 60 * 1000,  // 5 minutes — no refetch within 5 min of last fetch
});

// App configuration — changes only on deploy
const { data: config } = useQuery({
  queryKey: ['config'],
  queryFn: fetchAppConfig,
  staleTime: Infinity,  // Never considered stale; only refetch on explicit invalidation
});

// Feed / live data — always fresh
const { data: notifications } = useQuery({
  queryKey: ['notifications'],
  queryFn: fetchNotifications,
  staleTime: 0,           // Default: refetch on every mount
  refetchInterval: 30000, // Also poll every 30 seconds
});
```

## Global Defaults

Set defaults once to avoid repetition:
```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,  // 1 minute default for all queries
      gcTime: 5 * 60 * 1000,  // 5 minutes garbage collection
      retry: 1,  // Retry once on failure
    },
  },
});
```

Per-query `staleTime` overrides the global default.

## The gcTime / staleTime Relationship

```
Timeline:
0s    — Query fetches
0s    — Data is FRESH (within staleTime)
60s   — Data becomes STALE (staleTime elapsed)
60s   — Component unmounts, query becomes inactive
5min  — Query is garbage collected (gcTime elapsed since last subscriber)

Between 60s and 5min: data is in cache but stale.
If component remounts during this window: shows stale data immediately, triggers background refetch.
After 5min: cache miss; loading state shown until fetch completes.
```

## refetchOnWindowFocus

Another common annoyance: React Query refetches all active queries when the browser tab regains focus (default: `true`). For apps where background refetch is disruptive:

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,  // Disable tab-focus refetch globally
    },
  },
});
```

Or per-query:
```typescript
useQuery({ ..., refetchOnWindowFocus: false });
```

## Key Rules
- Default `staleTime: 0` causes a refetch on every component mount — increase for slow-changing data
- User profiles, configs, and static reference data should have `staleTime: 5 * 60 * 1000` or `Infinity`
- `staleTime` controls refetch frequency; `gcTime` controls cache eviction — they are independent
- `gcTime` must be >= `staleTime` (or data evicts before it can be served as stale)
- Use global defaults in `QueryClient` to avoid per-query repetition
- `refetchOnWindowFocus` causes refetches on tab switch — disable globally if it causes UI disruption
