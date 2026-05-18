# Failure: Next.js Revalidation and Caching Issues

## Problem: Page Shows Stale Data After DB Update

**Symptom**: Data was updated in Supabase, page still shows the old value even after hard refresh.

**Root cause**: Next.js caches Server Component renders. The default behavior in App Router is to cache fetch results (`cache: 'force-cache'`). If the page uses a cached fetch, it won't re-fetch until the cache is invalidated.

**Fix**: Choose the right caching strategy for the data:

```ts
// Data that should always be fresh — opt out of caching
const data = await fetchInvoices()  // No cache option = caches by default in RSC

// Option 1: Force dynamic rendering (no cache, fresh on every request)
export const dynamic = 'force-dynamic'  // in the page file

// Option 2: Use next/cache fetch with no-store
const data = await fetch('/api/invoices', { cache: 'no-store' })

// Option 3: Time-based revalidation (revalidate every 60 seconds)
const data = await fetch('/api/invoices', { next: { revalidate: 60 } })
```

For Supabase queries (not `fetch`), use `unstable_noStore`:
```ts
import { unstable_noStore as noStore } from 'next/cache'

async function getInvoices() {
  noStore()  // Opt this Server Component out of static rendering
  const { data } = await supabase.from('invoices').select('*')
  return data
}
```

## Problem: revalidatePath/revalidateTag Not Working

**Symptom**: Called `revalidatePath('/invoices')` in a Server Action, but the page still shows stale data.

**Root cause 1**: `revalidatePath` and `revalidateTag` must be called from a Server Action or Route Handler, not from a Server Component during render.

```ts
// BAD: called during render — no effect
export default async function Page() {
  revalidatePath('/invoices')  // Wrong — this is a render, not an action
}

// GOOD: called from a Server Action after mutation
'use server'
async function updateInvoice(id: string, data: FormData) {
  await supabase.from('invoices').update(parseFormData(data)).eq('id', id)
  revalidatePath('/invoices')   // ✓ Correct placement
  revalidatePath(`/invoices/${id}`)
}
```

**Root cause 2**: The path doesn't exactly match. `revalidatePath('/invoices')` only invalidates that exact path, not nested paths.

```ts
// Invalidate the list and the detail page
revalidatePath('/invoices')           // list page
revalidatePath(`/invoices/${id}`)     // detail page

// Or use a tag to invalidate multiple pages at once
revalidateTag('invoices')

// Must tag the fetches too
const data = await fetch('/api/invoices', { next: { tags: ['invoices'] } })
```

## Problem: Static Generation Building Stale Pages

**Symptom**: `generateStaticParams` runs at build time, pages don't reflect new data added after build.

**Root cause**: `generateStaticParams` is a build-time function. New database entries don't exist yet at build time.

**Fix**: Use Incremental Static Regeneration (ISR) with revalidation:

```ts
// Generate known pages at build time
export async function generateStaticParams() {
  const { data: slugs } = await supabase.from('articles').select('slug')
  return slugs?.map(row => ({ slug: row.slug })) ?? []
}

// Revalidate every 24 hours — new pages auto-generate on first request
export const revalidate = 86400

// For new slugs not in generateStaticParams: fallback behavior
// In Next.js App Router, missing params return 404 unless you handle it
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const article = await getArticle(slug)
  if (!article) return { title: 'Not Found' }
  return { title: article.title }
}
```

## Problem: Layout Re-renders on Every Navigation

**Symptom**: Layout fetches data (e.g., user profile), but it re-fetches on every page navigation.

**Root cause**: Next.js only caches Server Component renders within a single request. Navigating to a new page is a new request — layout components do re-render, but Next.js deduplicates identical fetch calls within the same render pass.

**Fix**: If the same data is needed in the layout and a child page, use a tag so both share the same cache:

```ts
// layout.tsx
const user = await fetch(`/api/user`, { next: { tags: ['user'], revalidate: 300 } })

// page.tsx
const profile = await fetch(`/api/user`, { next: { tags: ['user'], revalidate: 300 } })
// Only one actual request made per 5 minutes, even across layout + page
```

For Supabase queries, use React's `cache()`:
```ts
import { cache } from 'react'

// This deduplicates calls within the same server render tree
export const getUser = cache(async (userId: string) => {
  const { data } = await supabase.from('profiles').select('*').eq('id', userId).single()
  return data
})
```
