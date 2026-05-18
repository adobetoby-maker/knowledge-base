# Next.js Static vs Dynamic Rendering

## The Core Decision

By default, Next.js tries to render pages statically at build time. Pages opt into dynamic rendering when they:
- Read request headers (`headers()`)
- Read cookies (`cookies()`)
- Use URL search params
- Call `noStore()` or `unstable_noStore()`
- Have no `generateStaticParams` for dynamic routes

Understanding this distinction prevents surprise behavior where pages are static when you expect them to be dynamic, or dynamic when they could be static.

## Rendering Modes

**Static (SSG)** — rendered at build time, served from CDN. Fastest. No per-request computation.

**Dynamic (SSR)** — rendered per request. Always fresh. Slower TTFB.

**Incremental Static Regeneration (ISR)** — static with periodic revalidation. Best of both.

## Checking What's Static vs Dynamic

After `npm run build`, Next.js shows the build output:

```
○ /                        (static)
○ /about                   (static)
● /blog/[slug]             (SSG - 12 pages)
λ /portal/dashboard        (dynamic)
λ /api/invoices            (dynamic)
```

- `○` = static
- `●` = static with generateStaticParams
- `λ` = dynamic (server-side rendered per request)

## Static Routes with Dynamic Data (ISR)

Best for: blog posts, service pages, content that changes infrequently.

```typescript
// app/blog/[slug]/page.tsx
export const revalidate = 3600  // regenerate every hour

export async function generateStaticParams() {
  // Pre-render these slugs at build time
  return articles.map(a => ({ slug: a.slug }))
}

export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = articles.find(a => a.slug === slug)
  if (!article) notFound()
  return <ArticlePage article={article} />
}
```

Since `articles` is a TypeScript array (not a database), the data is already in the bundle — this renders as fully static.

## Forcing Dynamic Rendering

```typescript
// Option 1: Use dynamic functions
import { headers, cookies } from 'next/headers'

export default async function Page() {
  const cookieStore = await cookies()  // forces dynamic
  const headersList = await headers()  // forces dynamic
  // ...
}

// Option 2: Explicit opt-out of caching
import { unstable_noStore as noStore } from 'next/cache'

export default async function Page() {
  noStore()  // forces dynamic rendering
  const data = await fetchFreshData()
  return <Component data={data} />
}

// Option 3: Export the dynamic config
export const dynamic = 'force-dynamic'  // never cache, always SSR
```

## Caching Layers

Next.js has four caching layers:

| Cache | What it caches | Invalidation |
|-------|---------------|--------------|
| Request memoization | `fetch()` in same render | Per request (automatic) |
| Data cache | `fetch()` results | `revalidatePath()`, `revalidateTag()`, `revalidate` option |
| Full route cache | Static pages | `revalidatePath()`, `revalidateTag()`, redeploy |
| Router cache | Client-side page cache | Navigation, `router.refresh()` |

## Cache Tags and Revalidation

```typescript
// Tag a fetch request
const { data: invoices } = await fetch('/api/invoices', {
  next: { tags: ['invoices'] }
})

// Revalidate by tag (in Server Action)
import { revalidateTag } from 'next/cache'

export async function createInvoice(data: FormData) {
  await insertInvoice(data)
  revalidateTag('invoices')  // invalidates all fetches tagged 'invoices'
}
```

## Supabase Queries and Caching

Supabase queries via the JS client don't go through `fetch()`, so they don't participate in Next.js's data cache. They are always fresh.

To cache Supabase data:
```typescript
// Option 1: Wrap in unstable_cache
import { unstable_cache } from 'next/cache'

const getCachedInvoices = unstable_cache(
  async (userId: string) => {
    const supabase = createAdminClient()
    const { data } = await supabase.from('invoices').select('*').eq('user_id', userId)
    return data
  },
  ['invoices'],  // cache key
  { revalidate: 60, tags: ['invoices'] }
)

// Option 2: Route-level static rendering (for pages with no user-specific data)
export const revalidate = 300  // 5 minutes
```

## When Each Strategy Applies

| Page | Strategy | Reason |
|------|----------|--------|
| JRS blog posts | Static (ISR 1h) | Content in TypeScript array, SEO important |
| JRS service pages | Static | Never changes, SEO critical |
| Portal dashboard | Dynamic (SSR) | Shows user-specific data |
| Admin table | Dynamic | Always fresh data required |
| Landing page | Static | Maximum performance, SEO |
| API routes | Dynamic | Request-dependent |
