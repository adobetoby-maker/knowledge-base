# Plugin: SWR

## Overview

SWR (stale-while-revalidate) is Vercel's data-fetching hook. Simpler than TanStack Query but less powerful. Choose SWR for straightforward GET-only data fetching in smaller apps. Choose TanStack Query when you need mutations with cache invalidation, optimistic updates, or complex cache management.

## Installation

```bash
npm install swr
```

## Basic Fetch

```tsx
import useSWR from 'swr'

const fetcher = (url: string) => fetch(url).then(r => r.json())

function Profile({ userId }: { userId: string }) {
  const { data, error, isLoading } = useSWR(`/api/users/${userId}`, fetcher)

  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />

  return <div>{data.name}</div>
}
```

## Global Configuration

```tsx
// app/providers.tsx
import { SWRConfig } from 'swr'

const globalFetcher = async (url: string) => {
  const res = await fetch(url)
  if (!res.ok) {
    const error = new Error('Fetch failed') as Error & { status: number }
    error.status = res.status
    throw error
  }
  return res.json()
}

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SWRConfig
      value={{
        fetcher: globalFetcher,
        revalidateOnFocus: false,  // don't refetch on tab switch
        errorRetryCount: 3,
        dedupingInterval: 2000,
      }}
    >
      {children}
    </SWRConfig>
  )
}
```

## Mutations with useSWRMutation

```tsx
import useSWRMutation from 'swr/mutation'

async function updateProfile(url: string, { arg }: { arg: { name: string } }) {
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(arg),
  })
  return res.json()
}

function ProfileEditor({ userId }: { userId: string }) {
  const { trigger, isMutating } = useSWRMutation(
    `/api/users/${userId}`,
    updateProfile
  )

  const handleSave = async (name: string) => {
    await trigger({ name })
    // SWR automatically revalidates the key after mutation
  }

  return <button onClick={() => handleSave('Alice')} disabled={isMutating}>Save</button>
}
```

## Optimistic Updates

```tsx
import { mutate } from 'swr'

async function addTodo(text: string, userId: string) {
  const key = `/api/todos?userId=${userId}`

  // Optimistic update
  mutate(
    key,
    (todos: Todo[]) => [...(todos ?? []), { id: 'temp', text, done: false }],
    false  // false = don't revalidate yet
  )

  await fetch('/api/todos', {
    method: 'POST',
    body: JSON.stringify({ text, userId }),
  })

  // Revalidate after real mutation
  mutate(key)
}
```

## Conditional Fetching

```tsx
// Pass null to pause fetching (e.g., user not logged in)
const { data } = useSWR(userId ? `/api/users/${userId}` : null, fetcher)

// Dependent fetch
const { data: user } = useSWR('/api/me', fetcher)
const { data: orders } = useSWR(user ? `/api/orders?userId=${user.id}` : null, fetcher)
```

## Pagination with useSWRInfinite

```tsx
import useSWRInfinite from 'swr/infinite'

function PostList() {
  const { data, size, setSize, isLoading } = useSWRInfinite(
    (pageIndex, previousPageData) => {
      if (previousPageData && !previousPageData.length) return null  // end of list
      return `/api/posts?page=${pageIndex + 1}`
    },
    fetcher
  )

  const posts = data ? data.flat() : []
  const isLoadingMore = size > 1 && data && typeof data[size - 1] === 'undefined'
  const isEmpty = data?.[0]?.length === 0
  const isReachingEnd = isEmpty || (data && data[data.length - 1]?.length < 10)

  return (
    <div>
      {posts.map(post => <PostCard key={post.id} post={post} />)}
      {!isReachingEnd && (
        <button onClick={() => setSize(size + 1)} disabled={isLoadingMore}>
          {isLoadingMore ? 'Loading…' : 'Load more'}
        </button>
      )}
    </div>
  )
}
```

## SWR vs TanStack Query

| Feature | SWR | TanStack Query |
|---|---|---|
| Bundle size | ~4KB | ~12KB |
| Mutations + cache | Basic | Full |
| Optimistic updates | Manual | Built-in helpers |
| Devtools | No | Yes |
| Infinite queries | `useSWRInfinite` | `useInfiniteQuery` |
| Prefetching | `preload()` | `prefetchQuery()` |

## Key Rules

- The cache key is the first argument to `useSWR` — use a string (URL) for simple cases; use an array `[url, params]` when params affect the result.
- `revalidateOnFocus: false` prevents confusing refetches when switching tabs — set globally for most apps.
- `mutate` invalidates by key — the key must match exactly, including query params.
- SWR doesn't deduplicate requests across components for different keys — TanStack Query's `QueryClient` is better for complex cross-component cache coordination.
