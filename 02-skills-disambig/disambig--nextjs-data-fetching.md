# Disambiguation: Next.js Data Fetching Methods

## The Choice Matrix

| Need | Pattern | Where |
|------|---------|-------|
| Server-side data, no user interaction | Async Server Component | `app/page.tsx` |
| Data from database for current user | Async Server Component + Supabase server client | Server Component |
| Real-time data that updates | TanStack Query | Client Component |
| Data from external public API, cacheable | `fetch()` with caching | Server Component |
| Form submission | Server Action | `'use server'` function |
| Triggered by user click | Route Handler or Server Action | Depends on caller |
| Data needed by client component | Fetch in Server Component, pass as props | Server → Client |

## When to Use Server Components (Default)

```typescript
// app/portal/invoices/page.tsx
// Server Component — no 'use client' directive
export default async function InvoicesPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  
  const { data: invoices } = await supabase
    .from('invoices')
    .select('*')
    .eq('user_id', user.id)
  
  return <InvoiceList invoices={invoices} />
}
```

Use when: data is only needed on page load, doesn't change based on user interaction (other than navigating to a new page).

## When to Use TanStack Query (Client-Side)

```typescript
'use client'
// When the user can trigger data refresh, filter, or paginate
function InvoiceTable() {
  const [status, setStatus] = useState<string | null>(null)
  
  const { data } = useQuery({
    queryKey: ['invoices', status],
    queryFn: () => fetch(`/api/invoices?status=${status}`).then(r => r.json()),
  })
  
  return (
    <>
      <StatusFilter onChange={setStatus} />
      <Table data={data} />
    </>
  )
}
```

Use when: data depends on user-controlled state (filters, pagination, search).

## The Prop Passing Pattern

Server Components can fetch data and pass it to Client Components as props:

```typescript
// Server Component
async function InvoicePage() {
  const invoices = await fetchInvoices()  // server-side
  
  return (
    <InvoiceEditor  // Client Component ('use client')
      initialInvoices={invoices}
    />
  )
}
```

The Client Component receives the data pre-loaded. It can then manage local state changes without refetching the initial data.

## When NOT to Use useEffect for Data Fetching

```typescript
// DON'T — this pattern is obsolete in React 18+ / Next.js App Router
'use client'
function InvoiceList() {
  const [invoices, setInvoices] = useState([])
  const [loading, setLoading] = useState(true)
  
  useEffect(() => {
    fetch('/api/invoices').then(r => r.json()).then(data => {
      setInvoices(data)
      setLoading(false)
    })
  }, [])
}
```

Replace with:
- Server Component fetching (if data doesn't need client-side interactivity)
- TanStack Query (if data needs to respond to client state changes)

## Caching Strategies

```typescript
// Static — fetched once at build time
const data = await fetch(url)  // cached by default

// Revalidated — fetched fresh every N seconds
const data = await fetch(url, { next: { revalidate: 3600 } })

// Per-request fresh — no caching
const data = await fetch(url, { cache: 'no-store' })

// Tagged — manually invalidated
const data = await fetch(url, { next: { tags: ['invoices'] } })
// Later: revalidateTag('invoices')
```

## Server Actions vs Route Handlers for Mutations

**Server Action:** Form submissions from React components. No explicit HTTP request.
```typescript
<form action={createInvoice}>...</form>
```

**Route Handler:** Mutations from external sources or when you need HTTP semantics.
```typescript
const response = await fetch('/api/invoices', { method: 'POST', body: JSON.stringify(data) })
```

For mutations within your own Next.js app: prefer Server Actions. For mutations from mobile apps, Stripe webhooks, other services: use Route Handlers.
