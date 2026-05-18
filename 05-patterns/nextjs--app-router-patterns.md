# Next.js App Router — Core Patterns

**When:** Building routes, layouts, loading states, error boundaries, or parallel/intercepting routes in Next.js App Router.
**Rule:** App Router uses the filesystem as the routing API. File names are the API — understand them before writing any route.

## File Conventions
```
app/
  layout.tsx          — shared UI wrapping all routes in this segment
  page.tsx            — the actual page (route becomes accessible)
  loading.tsx         — shown while page.tsx is loading (Suspense boundary)
  error.tsx           — shown when page.tsx throws (Error boundary)
  not-found.tsx       — shown when notFound() is called
  route.ts            — API Route Handler (no UI)
  template.tsx        — like layout but re-mounts on navigation (rare)

  [id]/               — dynamic segment
    page.tsx          — accessible at /[any-value]

  (group)/            — route group: doesn't affect URL, shares layout
    page.tsx          — accessible at /page (not /group/page)
    layout.tsx        — shared only within this group

  @slot/              — parallel route slot
    page.tsx          — renders simultaneously with sibling slots

  (..)route/          — intercepting route
```

## Route Parameters
```typescript
// app/blog/[slug]/page.tsx
export default async function BlogPost({
  params,
  searchParams
}: {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ q?: string }>
}) {
  const { slug } = await params        // Next.js 15+: params is a Promise
  const { q } = await searchParams    // query string params
  
  const post = await getPost(slug)
  if (!post) notFound()               // shows not-found.tsx
  
  return <article>{post.title}</article>
}
```

## Loading State
```typescript
// app/dashboard/loading.tsx
export default function Loading() {
  return (
    <div className="space-y-4">
      <div className="h-8 w-48 animate-pulse rounded bg-gray-200" />
      <div className="h-4 w-full animate-pulse rounded bg-gray-200" />
    </div>
  )
}
```
Next.js automatically wraps `page.tsx` in a Suspense boundary using this file.

## Error Boundary
```typescript
'use client'  // Error components must be Client Components

import { useEffect } from 'react'

export default function Error({
  error,
  reset
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])
  
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

## Parallel Routes (Dashboard with Slots)
```
app/dashboard/
  layout.tsx      — receives @analytics and @team as props
  page.tsx        — default content
  @analytics/
    page.tsx
  @team/
    page.tsx
```
```typescript
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  analytics,
  team
}: {
  children: React.ReactNode
  analytics: React.ReactNode
  team: React.ReactNode
}) {
  return (
    <div className="grid grid-cols-2 gap-8">
      {children}
      {analytics}
      {team}
    </div>
  )
}
```

## generateStaticParams — Static Generation at Scale
```typescript
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await getAllPosts()
  return posts.map(post => ({ slug: post.slug }))
}
// Next.js pre-renders a page for each slug at build time
```

## Metadata
```typescript
// Static
export const metadata: Metadata = { title: 'Page Title', description: '...' }

// Dynamic (depends on route param)
export async function generateMetadata({ params }): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)
  return {
    title: post.title,
    description: post.excerpt,
    openGraph: {
      title: post.title,
      images: [post.coverImage]
    }
  }
}
```
