# Disambiguation: Next.js Rendering Choice

## The Three Rendering Modes

1. **Static** — generated at build time, served from CDN, no server cost per request
2. **Dynamic** — rendered on each request, can use request-time data (cookies, headers)
3. **Incremental Static Regeneration (ISR)** — static but refreshed periodically

## Decision Tree

```
Does the page content change based on the logged-in user?
  YES → Dynamic (Server Component with auth check)
  NO  → Continue...

Does the content change more often than once per hour?
  YES → Dynamic or ISR with short revalidation
  NO  → Continue...

Are there hundreds or thousands of possible pages (e.g., /blog/[slug])?
  YES → ISR or Static with generateStaticParams
  NO  → Static

Does it need real-time data (prices, inventory)?
  YES → Dynamic
  NO  → Static or ISR
```

## When Each Applies in This Stack

| Page | Rendering | Why |
|---|---|---|
| `/` homepage (jrs) | Static | Same for all users, changes rarely |
| `/blog/[slug]` | Static | Pre-generate from articles array |
| `/services/[slug]` | Static | Fixed service pages |
| `/portal/invoices` | Dynamic | User-specific data |
| `/admin/invoices` | Dynamic | Auth-gated, real-time data |
| Climb sites blog | ISR (1h) | Content may update without rebuild |

## Static Pages

```typescript
// app/blog/[slug]/page.tsx
// NO async function = static by default
export function generateStaticParams() {
  return articles.map(a => ({ slug: a.slug }))
}

export default function BlogPost({ params }: { params: { slug: string } }) {
  const article = articles.find(a => a.slug === params.slug)
  if (!article) notFound()
  return <ArticleContent article={article} />
}
```

All blog pages generated at build time. Fast, no DB queries at request time.

## Dynamic Pages

```typescript
// app/(portal)/invoices/page.tsx
// Any of these make a page dynamic:
// - cookies(), headers() used inside
// - await supabase.auth.getUser() (accesses cookies)
// - fetch() with no cache config

export default async function InvoicesPage() {
  const supabase = createClient()  // reads request cookies → dynamic
  const { data: invoices } = await supabase.from('invoices').select('*')
  return <InvoiceList invoices={invoices} />
}
```

## ISR (Incremental Static Regeneration)

```typescript
// app/blog/[slug]/page.tsx
export const revalidate = 3600  // regenerate every hour

// OR per-fetch:
const data = await fetch(url, { next: { revalidate: 3600 } })
```

With ISR, the page is served static (fast) but the server regenerates it in the background after `revalidate` seconds have passed since last generation.

## On-Demand Revalidation

When content changes (new blog post, service update), trigger revalidation:
```typescript
// In a Server Action or Route Handler:
import { revalidatePath, revalidateTag } from 'next/cache'

revalidatePath('/blog')          // revalidate all blog pages
revalidatePath('/blog/[slug]', 'page')  // pattern
revalidateTag('blog-posts')      // revalidate anything tagged 'blog-posts'
```

## Common Mistake: Unintentional Dynamic Pages

A page becomes dynamic the moment any code in it accesses cookies or headers. Check for unintended dynamic behavior:

```typescript
// BAD: blog post is accidentally dynamic because of one cookie check
import { cookies } from 'next/headers'  // ← makes the whole page dynamic

export default function BlogPost() {
  const prefersDark = cookies().get('theme')?.value === 'dark'
  // This forces dynamic rendering — blog pages should be static
}

// FIX: move the preference check to a Client Component
// The static Server Component renders the content
// A Client Component reads localStorage for theme preference
```

## Opting Into Static Caching Explicitly

```typescript
// Force static caching for a dynamic data fetch
import { unstable_cache } from 'next/cache'

const getServices = unstable_cache(
  async () => supabase.from('services').select('*'),
  ['services'],
  { revalidate: 86400, tags: ['services'] }
)

// Now supabase call is cached even though it's in a Server Component
export default async function ServicesPage() {
  const { data: services } = await getServices()
  // ...
}
```
