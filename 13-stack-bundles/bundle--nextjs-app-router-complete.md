# Stack Bundle: Next.js App Router — Complete Patterns

## Critical Version Notes

This bundle covers Next.js 15+ (App Router). Key breaking changes from Next.js 13/14:
- `params` is now `Promise<Params>` — must `await params`
- `searchParams` is now `Promise<SearchParams>` — must `await searchParams`
- `cookies()` and `headers()` now return Promises — must `await`
- `getServerSideProps` doesn't exist — use Server Components
- `getStaticProps` doesn't exist — use `generateStaticParams` + static data fetch

## File Conventions

```
app/
  layout.tsx              ← Root layout (wraps everything)
  page.tsx                ← Homepage /
  loading.tsx             ← Loading UI for this segment
  error.tsx               ← Error UI ('use client' required)
  not-found.tsx           ← 404 UI
  blog/
    page.tsx              ← /blog
    [slug]/
      page.tsx            ← /blog/:slug
      generateStaticParams ← pre-render all slugs at build
  api/
    invoices/
      route.ts            ← /api/invoices (GET, POST)
      [id]/
        route.ts          ← /api/invoices/:id (GET, PUT, DELETE)
```

## Page Component with Dynamic Params

```typescript
// app/blog/[slug]/page.tsx
import { Metadata } from 'next'
import { notFound } from 'next/navigation'

// Generate metadata for SEO
export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>
}): Promise<Metadata> {
  const { slug } = await params
  const article = getArticleBySlug(slug)
  if (!article) return {}
  
  return {
    title: article.title,
    description: article.excerpt,
    openGraph: { title: article.title, description: article.excerpt }
  }
}

// Pre-generate all slugs at build time
export async function generateStaticParams() {
  return articles.map(a => ({ slug: a.slug }))
}

// Page component
export default async function BlogPost({
  params,
}: {
  params: Promise<{ slug: string }>
}) {
  const { slug } = await params  // Must await in Next.js 15+
  const article = getArticleBySlug(slug)
  if (!article) notFound()
  
  return <ArticleLayout article={article} />
}
```

## Layout Pattern

```typescript
// app/layout.tsx
import { Inter } from 'next/font/google'
import { Providers } from '@/components/Providers'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body>
        <Providers>
          <NavBar />
          {children}
          <Footer />
        </Providers>
      </body>
    </html>
  )
}
```

## Data Fetching in Server Components

```typescript
// Server Component — can be async, no 'use client'
async function InvoiceList({ userId }: { userId: string }) {
  const supabase = await createClient()
  
  const { data: invoices, error } = await supabase
    .from('invoices')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
  
  if (error) throw error  // caught by error.tsx
  
  return (
    <ul>
      {invoices.map(inv => <InvoiceRow key={inv.id} invoice={inv} />)}
    </ul>
  )
}

// Suspense wrapper in parent
<Suspense fallback={<InvoiceListSkeleton />}>
  <InvoiceList userId={userId} />
</Suspense>
```

## Route Handler

```typescript
// app/api/invoices/route.ts
import { NextRequest } from 'next/server'

export async function GET(request: NextRequest) {
  const url = request.nextUrl
  const page = Number(url.searchParams.get('page') ?? '1')
  
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  
  const { data } = await supabase.from('invoices').select('*').eq('user_id', user.id)
  return Response.json({ data })
}

export async function POST(request: NextRequest) {
  const body = await request.json()
  const result = CreateInvoiceSchema.safeParse(body)
  if (!result.success) return Response.json({ error: 'Invalid' }, { status: 400 })
  
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 })
  
  const { data, error } = await supabase.from('invoices').insert(result.data).select().single()
  if (error) return Response.json({ error: 'Failed' }, { status: 500 })
  
  return Response.json(data, { status: 201 })
}
```

## Server Actions

```typescript
// app/actions/invoice.ts
'use server'
import { revalidatePath } from 'next/cache'

export async function createInvoice(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')
  
  const amount = Number(formData.get('amount'))
  
  await supabase.from('invoices').insert({ amount, user_id: user.id })
  revalidatePath('/portal/invoices')  // invalidate cached page
}
```

## Caching

```typescript
// Static (default for Server Components with static data)
// Data cached indefinitely, revalidated by tag/path

// Force dynamic (no caching)
export const dynamic = 'force-dynamic'

// Revalidate by time
export const revalidate = 3600  // 1 hour

// Tag-based invalidation
fetch(url, { next: { tags: ['invoices'] } })
revalidateTag('invoices')  // invalidate in server action/route handler
```

## The Four Cache Layers (Quick Reference)

1. **Request Memoization** — deduplicates identical fetch() calls in a single request
2. **Data Cache** — persists fetch() results across requests (per-URL, configurable)
3. **Full Route Cache** — caches complete rendered HTML+RSC payload
4. **Router Cache** — client-side cache of visited pages (soft navigation)

`revalidatePath()` invalidates Full Route Cache. `revalidateTag()` invalidates Data Cache by tag.
