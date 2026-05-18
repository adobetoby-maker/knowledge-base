# TanStack Query vs SWR

## What They Both Do

Both libraries solve the same fundamental problem: server state is not the same as client state, and managing it with `useState` + `useEffect` leads to scattered loading/error handling, race conditions, stale data, and duplicate fetches. Both provide a hook-based API that handles caching, revalidation, deduplication, and background refetching.

The choice is about complexity ceiling, not fundamentals.

## Where SWR Excels

SWR was built with a single constraint in mind: be the smallest, simplest way to keep data fresh. The API surface is intentionally minimal. `useSWR(key, fetcher)` covers 80% of use cases in a few characters. The mental model is "stale-while-revalidate" — show cached data immediately, refetch in the background, update when fresh data arrives.

SWR's bundle footprint is smaller (~4kb gzipped vs ~11kb for TanStack Query). In applications where data fetching is read-dominated — dashboards that display data, content sites, profile pages — SWR's simplicity is a genuine asset. Fewer concepts to learn, fewer ways to misconfigure.

## Where TanStack Query Extends Beyond SWR

**Mutations with lifecycle hooks:** TanStack Query's `useMutation` provides `onMutate`, `onSuccess`, `onError`, `onSettled` hooks. This is the correct place to implement optimistic updates — update the cache before the server responds, roll back on error. SWR supports optimistic updates but the pattern is more manual.

**Infinite queries:** `useInfiniteQuery` handles paginated and cursor-based lists with built-in support for fetching next/previous pages, combining pages into a flat list, and knowing when there are no more pages. SWR has `useSWRInfinite` but it requires more manual page management.

**Query invalidation and relationships:** When a mutation affects multiple queries (creating an order invalidates both `/orders` and `/dashboard/stats`), TanStack Query's `queryClient.invalidateQueries` handles this cleanly by key prefix or exact match. SWR's `mutate` is global but less ergonomic for invalidating sets of related keys.

**Dependent queries:** Queries that depend on data from other queries (`useQuery({ enabled: !!userId })`) have first-class support. The `enabled` flag prevents fetching until prerequisites are met.

**DevTools:** TanStack Query ships dedicated browser DevTools that show cache state, query status, and when data was last fetched. SWR has no equivalent.

## The Bundle Size Tradeoff

SWR: ~4kb gzipped. TanStack Query: ~11kb gzipped. For most applications this is not meaningful — a single unoptimized image is larger. Only relevant when optimizing for initial bundle size on bandwidth-constrained devices or when adding to an already-large bundle.

## Decision Framework

**Use SWR when:**
- Data fetching is primarily read-only display (no complex mutations)
- The application is simple: a handful of data-fetching hooks with no interdependencies
- Bundle size is a genuine constraint
- Onboarding junior developers who benefit from a minimal API

**Use TanStack Query when:**
- Mutations need optimistic updates or rollback
- Paginated/infinite scroll lists are part of the UI
- Multiple queries need to be invalidated together after a mutation
- DevTools visibility into cache state would help during development (which it always does)
- The data model has relationships where one action affects multiple cached resources

**Default position:** Use TanStack Query for any application with user-driven data modifications. The mutation lifecycle hooks alone justify the larger bundle. Use SWR only for pure read-heavy display applications or when the simplest possible API is the priority.

## Key Rules

- Never use SWR for optimistic updates on complex forms — the manual cache manipulation is error-prone
- Always use TanStack Query's `enabled` option instead of conditional hook calls — conditional hooks violate Rules of Hooks
- Set `staleTime` explicitly; the default (0) causes refetches on every focus, which is rarely what you want
- Treat query keys as the address of cached data — structure them consistently (`[resource, id, filters]`)
- In TanStack Query, mutations should call `invalidateQueries` in `onSuccess`, not in the component
