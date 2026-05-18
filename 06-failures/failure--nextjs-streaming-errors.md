# Failure Patterns: Next.js Streaming Errors

## Suspense Boundary Missing

When using async Server Components or `loading.tsx`, every async boundary needs a Suspense wrapper. Without it:

```typescript
// WRONG — no Suspense around async component:
export default function Page() {
  return (
    <div>
      <Header />
      <AsyncInvoiceList />  {/* blocks the entire page */}
    </div>
  )
}

// CORRECT — wrap each async section:
export default function Page() {
  return (
    <div>
      <Header />
      <Suspense fallback={<InvoiceListSkeleton />}>
        <AsyncInvoiceList />
      </Suspense>
    </div>
  )
}
```

Without Suspense, the page waits for ALL async Server Components before sending any HTML to the client — no streaming benefit.

## Error in Streamed Segment Crashes Entire Page

When an async component throws inside a Suspense boundary, the error propagates to the nearest error boundary. Without one, the entire page crashes with 500.

```typescript
// CORRECT — pair Suspense with an error boundary:
import { ErrorBoundary } from 'react-error-boundary'

export default function Page() {
  return (
    <ErrorBoundary fallback={<StatsError />}>
      <Suspense fallback={<StatsSkeleton />}>
        <DashboardStats />
      </Suspense>
    </ErrorBoundary>
  )
}
```

## `notFound()` Inside Try-Catch

`notFound()` works by throwing a special Next.js error. If you catch it, the not-found behavior is swallowed.

```typescript
// WRONG — notFound() gets caught:
try {
  const invoice = await getInvoice(id)
  if (!invoice) notFound()  // throws, caught by catch
  return invoice
} catch (e) {
  console.error(e)
  return null
}

// CORRECT — call notFound() outside try/catch:
const invoice = await getInvoice(id)
if (!invoice) notFound()  // now correctly triggers 404

// OR — use error variable pattern:
let invoice
try {
  invoice = await getInvoice(id)
} catch (e) {
  console.error(e)
  throw e
}
if (!invoice) notFound()
```

Same applies to `redirect()` — it also throws internally.

## Async Params Not Awaited (Next.js 15+)

```typescript
// WRONG — params is a Promise in Next.js 15:
export default function Page({ params }: { params: { slug: string } }) {
  return <div>{params.slug}</div>  // TypeError: cannot read slug of Promise
}

// CORRECT — await params:
export default async function Page({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  return <div>{slug}</div>
}
```

Same applies to `searchParams`:
```typescript
export default async function Page({ searchParams }: { searchParams: Promise<{ q: string }> }) {
  const { q } = await searchParams
}
```

## generateStaticParams Returning Wrong Shape

```typescript
// WRONG — returning wrong shape:
export async function generateStaticParams() {
  const articles = await getArticles()
  return articles.map(a => a.slug)  // returns string[], not { slug: string }[]
}

// CORRECT:
export async function generateStaticParams() {
  const articles = await getArticles()
  return articles.map(a => ({ slug: a.slug }))  // object with param name as key
}
```

## Hydration Mismatch from Streaming

When server renders one thing and client hydrates another — common with:
- Client-only state (`useState` with a non-`undefined` initial value that differs from server)
- `Date.now()` called in render (different timestamps)
- Browser-only APIs in render (`localStorage`, `window`)

```typescript
// WRONG — localStorage in render causes hydration mismatch:
function Component() {
  const [value, setValue] = useState(localStorage.getItem('key') ?? '')
}

// CORRECT — use useEffect for client-only state:
function Component() {
  const [value, setValue] = useState('')
  
  useEffect(() => {
    setValue(localStorage.getItem('key') ?? '')
  }, [])
}
```

## cookies()/headers() Outside Server Context

`cookies()` and `headers()` from `next/headers` only work in:
- Server Components
- Route Handlers
- Server Actions

Not in:
- Utility functions called from both server and client
- Middleware (use `request.cookies` instead)

```typescript
// WRONG — util function called from both contexts:
export async function getUser() {
  const cookieStore = await cookies()  // throws when called from client
  // ...
}

// CORRECT — only call cookies() at the boundary:
// In the Server Component:
const cookieStore = await cookies()
const user = await getUser(cookieStore.get('session')?.value)
```
