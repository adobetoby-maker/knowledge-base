# Infinite Scroll Pattern

## When to Use

Infinite scroll works well for feed-style content (posts, messages, activity logs) where users browse linearly. Use standard pagination for tabular data where users need random page access.

## IntersectionObserver Hook

The core primitive: trigger loading when a sentinel element enters the viewport.

```typescript
// hooks/use-intersection-observer.ts
import { useEffect, useRef, useCallback } from 'react'

interface UseIntersectionObserverOptions {
  onIntersect: () => void
  threshold?: number
  rootMargin?: string
  enabled?: boolean
}

export function useIntersectionObserver({
  onIntersect,
  threshold = 0,
  rootMargin = '0px',
  enabled = true,
}: UseIntersectionObserverOptions) {
  const ref = useRef<HTMLDivElement>(null)

  const callback = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      if (entries[0].isIntersecting) onIntersect()
    },
    [onIntersect]
  )

  useEffect(() => {
    if (!enabled || !ref.current) return
    const observer = new IntersectionObserver(callback, { threshold, rootMargin })
    observer.observe(ref.current)
    return () => observer.disconnect()
  }, [callback, enabled, threshold, rootMargin])

  return { ref }
}
```

## Infinite Query with TanStack Query

```typescript
// hooks/use-infinite-posts.ts
import { useInfiniteQuery } from '@tanstack/react-query'

interface Post {
  id: string
  content: string
  created_at: string
}

interface PostsPage {
  posts: Post[]
  nextCursor: string | null
}

export function useInfinitePosts(search?: string) {
  return useInfiniteQuery<PostsPage>({
    queryKey: ['posts', 'infinite', search],
    queryFn: async ({ pageParam }) => {
      const url = new URL('/api/posts', window.location.origin)
      if (pageParam) url.searchParams.set('cursor', pageParam as string)
      if (search) url.searchParams.set('q', search)
      const res = await fetch(url.toString())
      if (!res.ok) throw new Error('Failed to fetch posts')
      return res.json()
    },
    getNextPageParam: lastPage => lastPage.nextCursor,
    initialPageParam: undefined as string | undefined,
  })
}
```

```typescript
// components/post-feed.tsx
'use client'
import { useInfinitePosts } from '@/hooks/use-infinite-posts'
import { useIntersectionObserver } from '@/hooks/use-intersection-observer'
import { PostCard } from './post-card'
import { Loader2 } from 'lucide-react'

export function PostFeed() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
    isError,
  } = useInfinitePosts()

  const { ref } = useIntersectionObserver({
    onIntersect: fetchNextPage,
    enabled: hasNextPage && !isFetchingNextPage,
    rootMargin: '200px',  // start loading 200px before sentinel enters viewport
  })

  if (isLoading) return <FeedSkeleton />
  if (isError) return <div>Failed to load posts</div>

  const posts = data.pages.flatMap(page => page.posts)

  return (
    <div className="space-y-4">
      {posts.map(post => (
        <PostCard key={post.id} post={post} />
      ))}

      {/* Sentinel element — triggers load more when visible */}
      <div ref={ref} className="h-1" aria-hidden="true" />

      {isFetchingNextPage && (
        <div className="flex justify-center py-4">
          <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
        </div>
      )}

      {!hasNextPage && posts.length > 0 && (
        <p className="text-center text-sm text-muted-foreground py-4">
          You've reached the end
        </p>
      )}
    </div>
  )
}
```

## API Route with Cursor Pagination

```typescript
// app/api/posts/route.ts
export async function GET(req: NextRequest) {
  const cursor = req.nextUrl.searchParams.get('cursor')
  const q = req.nextUrl.searchParams.get('q') ?? ''
  const limit = 20

  const supabase = createAdminClient()
  let query = supabase
    .from('posts')
    .select('id, content, created_at, author:users(name, avatar_url)')
    .order('created_at', { ascending: false })
    .limit(limit)

  if (cursor) query = query.lt('created_at', cursor)
  if (q) query = query.ilike('content', `%${q}%`)

  const { data: posts, error } = await query
  if (error) return NextResponse.json({ error: 'Failed to fetch' }, { status: 500 })

  const nextCursor = posts?.length === limit
    ? posts[posts.length - 1].created_at
    : null

  return NextResponse.json({ posts: posts ?? [], nextCursor })
}
```

## Skeleton Loading State

```typescript
function FeedSkeleton() {
  return (
    <div className="space-y-4">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="rounded-lg border p-4 space-y-3">
          <div className="h-4 w-1/3 rounded bg-muted animate-pulse" />
          <div className="h-4 w-full rounded bg-muted animate-pulse" />
          <div className="h-4 w-2/3 rounded bg-muted animate-pulse" />
        </div>
      ))}
    </div>
  )
}
```

## Common Mistakes

- **No sentinel margin** — without `rootMargin`, the trigger fires only when the sentinel is fully visible, causing a visible jump; use `rootMargin: '200px'` to preload
- **Re-fetching on every render** — ensure `enabled` is false while already fetching: `enabled: hasNextPage && !isFetchingNextPage`
- **Flattening pages in render** — `data.pages.flatMap(p => p.posts)` is correct; accessing `data.pages[0]` directly misses loaded pages
- **No end state** — show "You've reached the end" message when `!hasNextPage`; otherwise users keep scrolling wondering if more exists
- **Memory growth** — infinite scroll accumulates all loaded items in memory; for very long feeds consider virtualizing with `@tanstack/react-virtual`
