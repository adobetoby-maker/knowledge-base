# TanStack Query (React Query) — Patterns

**When:** Fetching data from APIs or Supabase in React client components. Managing loading/error states, caching, refetching, optimistic updates.
**Rule:** TanStack Query is the right tool for ALL client-side server state. Never use useState + useEffect for fetching — use TanStack Query.

## Setup
```typescript
// app/layout.tsx (or providers.tsx)
'use client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useState } from 'react'

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 60 * 1000,  // 1 minute — data fresh for this long
        retry: 1,
      }
    }
  }))
  
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
}
```

## Basic Query
```typescript
import { useQuery } from '@tanstack/react-query'

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user', userId],     // unique cache key — include all params
    queryFn: () => fetch(`/api/users/${userId}`).then(r => r.json()),
    staleTime: 5 * 60 * 1000,      // cache for 5 minutes
  })
  
  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />
  return <div>{user.name}</div>
}
```

## Mutation (POST/PUT/DELETE)
```typescript
import { useMutation, useQueryClient } from '@tanstack/react-query'

function UpdateProfileForm({ userId }: { userId: string }) {
  const queryClient = useQueryClient()
  
  const mutation = useMutation({
    mutationFn: (data: Partial<User>) =>
      fetch(`/api/users/${userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      }).then(r => r.json()),
    
    onSuccess: () => {
      // Invalidate the user query so it refetches
      queryClient.invalidateQueries({ queryKey: ['user', userId] })
    }
  })
  
  return (
    <form onSubmit={e => {
      e.preventDefault()
      mutation.mutate({ name: e.currentTarget.name.value })
    }}>
      <input name="name" />
      <button type="submit" disabled={mutation.isPending}>
        {mutation.isPending ? 'Saving...' : 'Save'}
      </button>
    </form>
  )
}
```

## Optimistic Updates
```typescript
const mutation = useMutation({
  mutationFn: (newLike: Like) => postLike(newLike),
  
  onMutate: async (newLike) => {
    await queryClient.cancelQueries({ queryKey: ['likes', postId] })
    const previous = queryClient.getQueryData(['likes', postId])
    
    // Optimistically update
    queryClient.setQueryData(['likes', postId], (old: Like[]) => [...old, newLike])
    
    return { previous }  // context for rollback
  },
  
  onError: (err, newLike, context) => {
    // Roll back on error
    queryClient.setQueryData(['likes', postId], context?.previous)
  },
  
  onSettled: () => {
    queryClient.invalidateQueries({ queryKey: ['likes', postId] })
  }
})
```

## Supabase with TanStack Query
```typescript
function useUserProfile(userId: string) {
  return useQuery({
    queryKey: ['profile', userId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single()
      if (error) throw error
      return data
    },
    enabled: !!userId  // only run if userId exists
  })
}
```

## Query Key Conventions
```typescript
// All users
['users']

// Specific user
['users', userId]

// User's posts
['users', userId, 'posts']

// Filtered posts
['posts', { category: 'brakes', published: true }]
```
Consistent keys = better cache sharing and invalidation control.

## When NOT to Use TanStack Query
```
Server Components (Next.js App Router) → fetch directly
One-time operations with no cache → Server Action
Browser-only state (open/closed, selected tab) → useState
```
