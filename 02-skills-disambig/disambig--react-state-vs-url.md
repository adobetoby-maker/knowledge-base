# Disambiguation: React State vs URL State

## The Core Question

Where should this piece of state live?

## Decision Matrix

| State Type | Where to Put It |
|---|---|
| Filter/sort settings | URL search params |
| Active tab (shareable) | URL search params |
| Active tab (not shareable) | `useState` |
| Form field values | `useState` via `useForm` |
| Modal open/closed | `useState` |
| Wizard step | URL param (bookmarkable) or `useState` |
| Selected item (table row) | `useState` |
| Pagination page | URL search params |
| Search query | URL search params |
| Cart items | localStorage + `useState` |
| Auth state | Supabase context |
| Server data | TanStack Query / Server Component |

## URL State: When It Matters

Put state in the URL when:
1. Back button should restore the state
2. Users might share/bookmark the view
3. Refresh should preserve the state
4. A link to "the current view" would be useful

```typescript
// These belong in URL:
/invoices?status=pending&page=2&sort=date
/blog?q=oil+change
/customers?from=2026-01-01&to=2026-03-31
```

## React State: When URL Would Be Overkill

Use `useState` when:
- The state is transient UI interaction (modal open, hover state, accordion expanded)
- It's not meaningful to another user if shared
- It changes too frequently to track in URL (mouse position, scroll depth)

```typescript
// These belong in useState:
const [isModalOpen, setIsModalOpen] = useState(false)
const [selectedRows, setSelectedRows] = useState<string[]>([])
const [inputFocused, setInputFocused] = useState(false)
```

## Implementing URL State

```typescript
'use client'
import { useRouter, usePathname, useSearchParams } from 'next/navigation'

// Read from URL:
const searchParams = useSearchParams()
const status = searchParams.get('status') ?? 'all'
const page = Number(searchParams.get('page')) || 1

// Write to URL:
const router = useRouter()
const pathname = usePathname()

function setStatus(value: string) {
  const params = new URLSearchParams(searchParams.toString())
  if (value === 'all') params.delete('status')
  else params.set('status', value)
  params.delete('page')  // reset pagination on filter change
  router.push(`${pathname}?${params.toString()}`)
}

// replace vs push:
// router.push() — adds history entry (back button returns to previous filter)
// router.replace() — replaces history entry (used for live search, no back for each keystroke)
```

## Server Component Reading URL State

Server Components receive searchParams as props:

```typescript
// app/(admin)/invoices/page.tsx
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; page?: string }>
}) {
  const { status, page } = await searchParams
  
  const invoices = await fetchInvoices({
    status: status ?? 'all',
    page: Number(page) || 1,
  })
  
  return <InvoiceTable data={invoices} />
}
```

Server Components read URL state but don't "manage" it — they just receive it as props and fetch accordingly.

## Lifting State vs Collocating

If state is only used in one component: keep it local (useState).
If state is needed by sibling components: lift it to the parent.
If state is needed by many components at different levels: use URL state or context.

Don't lift state preemptively "in case" — lift when you actually need it.

## Anti-Pattern: Derived State in useState

Don't store in `useState` what can be derived from other state or props:

```typescript
// WRONG — activeInvoices is derived from invoices + status:
const [activeInvoices, setActiveInvoices] = useState([])
useEffect(() => {
  setActiveInvoices(invoices.filter(i => i.status === status))
}, [invoices, status])

// CORRECT — compute it during render:
const activeInvoices = invoices.filter(i => i.status === status)
// With useMemo if expensive:
const activeInvoices = useMemo(
  () => invoices.filter(i => i.status === status),
  [invoices, status]
)
```
