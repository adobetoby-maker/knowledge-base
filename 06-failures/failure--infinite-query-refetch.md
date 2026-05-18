# Failure: useInfiniteQuery Refetching All Pages on Window Focus

## Overview
TanStack Query's `useInfiniteQuery` (and React Query's equivalent) has a default behavior that catches many developers off guard: when the user returns to the tab (window focus event), TanStack Query refetches stale data. For infinite queries, "refetch" means refetching ALL currently loaded pages from page 1. If the user has scrolled to page 10, a window focus event triggers 10 parallel API requests. The visible result is the list jumping back to page 1 or user scroll position being lost.

## The Trigger Chain

```
User loads page → loads page 1 (items 1-20)
User scrolls down → loads pages 2, 3, 4 (items 21-80)
User switches to another tab for 5 minutes
User returns to the tab

Default behavior: staleTime=0 → data is stale → window focus triggers refetch
useInfiniteQuery refetches: page 1, page 2, page 3, page 4 (all pages)
→ 4 simultaneous API requests
→ React state updates → list re-renders → scroll position may jump
```

## The Default Settings That Cause This

```typescript
// Default TanStack Query v5 settings (implicit):
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 0,           // data is immediately stale → refetch on focus
      refetchOnWindowFocus: true, // trigger refetch when tab is focused
      refetchOnMount: true,   // refetch on every component mount
    },
  },
});
```

With `staleTime: 0` and `refetchOnWindowFocus: true`, every tab switch triggers a refetch.

## Solution 1: Disable refetchOnWindowFocus for Infinite Queries

```typescript
const { data, fetchNextPage, hasNextPage } = useInfiniteQuery({
  queryKey: ["posts", filters],
  queryFn: ({ pageParam }) => fetchPosts({ page: pageParam, ...filters }),
  initialPageParam: 1,
  getNextPageParam: (lastPage) => lastPage.nextPage,
  
  // Prevent all-pages refetch on window focus
  refetchOnWindowFocus: false,
  
  // Or set a stale time so data isn't immediately refetchable
  staleTime: 5 * 60 * 1000, // 5 minutes
});
```

## Solution 2: maxPages — Limit In-Memory Pages

TanStack Query v5 introduced `maxPages` to cap how many pages are kept in memory (and thus how many are refetched):

```typescript
const { data, fetchNextPage } = useInfiniteQuery({
  queryKey: ["posts"],
  queryFn: ({ pageParam }) => fetchPosts(pageParam),
  initialPageParam: 1,
  getNextPageParam: (last) => last.nextPage,
  getPreviousPageParam: (first) => first.prevPage,
  
  maxPages: 3, // only keep last 3 pages in memory
  // If user has loaded 10 pages, maxPages=3 means pages 8,9,10 are kept
  // Refetch on focus = only 3 requests, not 10
});
```

`maxPages` also reduces memory usage for very long lists.

## Solution 3: Stale Time to Reduce Refetch Frequency

```typescript
// Global defaults for all infinite queries:
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 2 * 60 * 1000, // data considered fresh for 2 minutes
      // window focus refetch only fires if data is stale (older than staleTime)
    },
  },
});

// Per-query override:
useInfiniteQuery({
  queryKey: ["feed"],
  queryFn: ({ pageParam }) => fetchFeed(pageParam),
  staleTime: 10 * 60 * 1000, // 10 minutes — social feed doesn't need frequent refetch
});
```

## Solution 4: Manual Invalidation Instead of Auto-Refetch

Turn off automatic refetching and let the application decide when to refresh:

```typescript
useInfiniteQuery({
  queryKey: ["notifications"],
  queryFn: fetchNotifications,
  refetchOnWindowFocus: false,
  refetchOnMount: false,
  refetchInterval: false, // no polling
});

// Explicit refresh button
function RefreshButton() {
  const queryClient = useQueryClient();
  return (
    <button
      type="button"
      onClick={() => queryClient.invalidateQueries({ queryKey: ["notifications"] })}
    >
      Refresh
    </button>
  );
}
```

## Detecting the Problem

Signs of infinite query refetch abuse:
- Network tab shows N requests firing simultaneously when switching back to the tab
- Scroll position jumps to top after returning to page
- "Loading" spinner appears briefly every time you switch tabs
- API rate limits are hit more than expected

```typescript
// Add query logging to see when queries refetch
const queryClient = new QueryClient({
  logger: {
    log: (message) => console.log("[Query]", message),
    warn: console.warn,
    error: console.error,
  },
});
```

## Key Rules
- Set `refetchOnWindowFocus: false` for infinite queries — all-pages refetch is almost never desirable
- Use `maxPages` in TanStack Query v5 to cap memory and limit refetch scope
- Set `staleTime` to a meaningful duration (2-10 minutes for most lists)
- Social feeds, notification lists, message threads: `refetchOnWindowFocus: false` + manual refresh button
- Real-time data (live dashboards, trading feeds): use WebSocket or polling instead of window focus refetch
- Test by: load 3+ pages, switch tabs for 30 seconds, return, count network requests in DevTools
