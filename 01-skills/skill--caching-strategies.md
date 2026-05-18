# Caching Strategies

## The Cache Hierarchy

For Next.js on Vercel, caching happens at multiple levels. Understand each level before adding caching:

1. **Edge/CDN** — served from Cloudflare/Vercel's global network, zero compute cost
2. **Next.js Full Route Cache** — pre-rendered static pages stored on server
3. **Next.js Data Cache** — cached `fetch()` responses stored on server
4. **Request Memoization** — deduplication within a single render pass
5. **Client-side Router Cache** — browser-cached page prefetches

## When Each Cache Applies

### Static Pages (Most Aggressive)

```typescript
// Page has no dynamic functions → static by default
// Builds once, served from CDN globally
export default async function AboutPage() {
  return <div>About us</div>  // purely static, served from CDN
}
```

### ISR (Stale-While-Revalidate)

```typescript
// Revalidate the page every hour in the background
export const revalidate = 3600

// Or revalidate on demand
export async function createArticle() {
  await insertArticle(data)
  revalidatePath('/blog')  // invalidates the cached /blog page
  revalidateTag('articles')  // invalidates any fetches tagged 'articles'
}
```

### Fetch Cache Control

```typescript
// Cache for 1 hour
const data = await fetch('https://api.example.com/data', {
  next: { revalidate: 3600 }
})

// Cache indefinitely (until manually invalidated)
const data = await fetch('https://api.example.com/data', {
  next: { tags: ['products'], revalidate: false }
})

// Never cache
const data = await fetch('https://api.example.com/data', {
  cache: 'no-store'
})
```

### unstable_cache for Supabase

Supabase queries bypass Next.js data cache (not `fetch()`). Use `unstable_cache` to cache them:

```typescript
import { unstable_cache } from 'next/cache'
import { createAdminClient } from '@/lib/supabase/admin'

export const getPublishedArticles = unstable_cache(
  async () => {
    const supabase = createAdminClient()
    const { data } = await supabase
      .from('articles')
      .select('*')
      .eq('published', true)
      .order('created_at', { ascending: false })
    return data
  },
  ['published-articles'],  // cache key
  {
    revalidate: 3600,        // 1 hour
    tags: ['articles'],      // invalidate with revalidateTag('articles')
  }
)
```

## Cloudflare KV Caching (Workers)

For Cloudflare Workers, use KV for caching:

```typescript
async function getCachedData<T>(
  key: string,
  fetcher: () => Promise<T>,
  ttlSeconds: number,
  env: Env
): Promise<T> {
  const cached = await env.CACHE.get(key, 'json') as T | null
  if (cached !== null) return cached
  
  const fresh = await fetcher()
  await env.CACHE.put(key, JSON.stringify(fresh), { expirationTtl: ttlSeconds })
  return fresh
}

// Usage in worker
const articles = await getCachedData(
  'articles:published',
  () => fetchArticlesFromAPI(),
  3600,
  env
)
```

KV is eventually consistent — a write may take a few seconds to propagate globally. For immediate consistency, KV is not appropriate.

## Client-Side Caching (TanStack Query)

For client components that need data caching:

```typescript
const { data } = useQuery({
  queryKey: ['invoices', userId],
  queryFn: () => fetch(`/api/invoices?userId=${userId}`).then(r => r.json()),
  staleTime: 1000 * 60 * 5,      // data is fresh for 5 minutes (no refetch)
  gcTime: 1000 * 60 * 30,         // keep in cache for 30 minutes after unused
  refetchOnWindowFocus: false,    // don't refetch when user returns to tab
  refetchOnMount: false,          // don't refetch when component remounts
})
```

## Cache Invalidation Patterns

The hardest part of caching is knowing when to invalidate.

**After mutations:**
```typescript
// Server Action
export async function updateInvoice(invoiceId: string, data: UpdateInput) {
  await updateInvoiceInDB(invoiceId, data)
  revalidatePath(`/portal/invoices/${invoiceId}`)  // specific page
  revalidatePath('/portal/invoices')               // list page
  revalidateTag('invoices')                        // all tagged fetches
}
```

**Immediate invalidation via Route Handler:**
```typescript
// API endpoint that external systems can call to invalidate
export async function POST(req: NextRequest) {
  const { tags, paths } = await req.json()
  const secret = req.headers.get('x-revalidate-secret')
  
  if (secret !== process.env.REVALIDATE_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }
  
  for (const tag of tags ?? []) revalidateTag(tag)
  for (const path of paths ?? []) revalidatePath(path)
  
  return NextResponse.json({ revalidated: true })
}
```

## What NOT to Cache

- User-specific data on shared static pages
- Data that must be real-time (chat, live prices, inventory)
- Auth state (sessions are always fresh)
- Form submissions and mutations (these must hit the server)
