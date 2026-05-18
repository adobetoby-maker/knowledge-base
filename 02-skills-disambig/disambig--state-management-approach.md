# Which State Management Approach to Use

## The Guiding Question

Where does the data live?

- **Server** — fetch it in a Server Component
- **Server but needs refresh** — TanStack Query
- **UI-only** — `useState`
- **Shared across components** — Context or URL params
- **Complex local logic** — `useReducer`

## Decision Tree

```
Is this server/database data?
  Yes → Can it be fetched in a Server Component?
    Yes → Use async Server Component (no state needed)
    No (needs interactivity/refresh) → TanStack Query useQuery
  No → Is it shared across components that don't share a parent?
    Yes → Context API (small, stable) or URL params (shareable)
    No → useState (local to one component)
```

## Server Data: Async Server Component

Best for data that doesn't change while the user is on the page:

```typescript
// app/portal/invoices/page.tsx
export default async function InvoicesPage() {
  const supabase = await createClient()
  const { data: invoices } = await supabase.from('invoices').select('*')
  return <InvoiceList invoices={invoices ?? []} />
}
```

No state management needed. Data is fetched once, rendered on server, sent as HTML.

## Server Data That Needs Client Refresh: TanStack Query

When data changes and the user should see updates without a full page reload:

```typescript
'use client'
import { useQuery } from '@tanstack/react-query'

export function InvoiceList() {
  const { data: invoices, isLoading } = useQuery({
    queryKey: ['invoices'],
    queryFn: () => fetch('/api/invoices').then(r => r.json()),
    refetchInterval: 30_000,  // refresh every 30s
  })
  
  if (isLoading) return <Skeleton />
  return invoices?.map(inv => <InvoiceCard key={inv.id} invoice={inv} />)
}
```

## UI State: useState

For state that only affects one component:

```typescript
'use client'
import { useState } from 'react'

export function Accordion({ items }: { items: AccordionItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(null)
  // openIndex is purely UI state — no server involvement
}
```

## Shared State: Context

For state that needs to be shared across a subtree without prop-drilling:

```typescript
// contexts/cart-context.tsx
'use client'
import { createContext, useContext, useReducer } from 'react'

const CartContext = createContext<CartContextValue | null>(null)

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, dispatch] = useReducer(cartReducer, [])
  return (
    <CartContext.Provider value={{ items, dispatch }}>
      {children}
    </CartContext.Provider>
  )
}

export function useCart() {
  const ctx = useContext(CartContext)
  if (!ctx) throw new Error('useCart must be used within CartProvider')
  return ctx
}
```

Use context for: current user, theme, language, shopping cart, modal state shared across the app.

## State in URL

Shareable, bookmarkable state belongs in the URL:

```typescript
// Search, filters, pagination — put in URL
const searchParams = useSearchParams()
const router = useRouter()

const status = searchParams.get('status') ?? 'all'
const page = parseInt(searchParams.get('page') ?? '1')

function setStatus(newStatus: string) {
  const params = new URLSearchParams(searchParams)
  params.set('status', newStatus)
  params.set('page', '1')  // reset page
  router.push(`?${params.toString()}`)
}
```

URL state survives page refresh and can be shared/bookmarked. Good for: filters, search queries, selected tab, sort order.

## Projects in This Workspace

| Project | State approach |
|---------|----------------|
| jrs-auto-repair | Async Server Components (mostly read-only) |
| manage-worker-bee | Server Components + React Flow canvas state (useState) |
| language-lens-elite | Full context provider stack (auth, app, grammar, match, etc.) |
| silver-creek-logistics | Server Components + form state (useState) |

## Anti-Patterns

- **`useEffect` to fetch server data** — use Server Components or TanStack Query instead
- **useState for server data** — it goes stale; use TanStack Query for refetchable server data
- **Context for everything** — context re-renders all consumers; use it sparingly for truly global state
- **Prop drilling past 3 levels** — at 3+ levels, consider context
