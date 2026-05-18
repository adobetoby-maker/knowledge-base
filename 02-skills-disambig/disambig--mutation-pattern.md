# Disambiguation: Mutation Pattern Choice

## Four Mutation Patterns

1. **Server Action from HTML form** — progressive enhancement, works without JS
2. **Server Action from React Hook Form** — client-side validation + server action
3. **Server Action from button/event handler** — simple actions (mark paid, delete)
4. **Route Handler + fetch/TanStack Query mutation** — external callers, complex response handling

## Decision Matrix

| Scenario | Pattern |
|---|---|
| Contact form, appointment request | Server Action from HTML form |
| Invoice creation with line items + validation | Server Action from React Hook Form |
| "Mark as paid" button | Server Action from event handler |
| Webhook receiver | Route Handler (not Server Action) |
| External mobile app posting data | Route Handler (not Server Action) |
| Real-time updates needed after mutation | Server Action + TanStack Query invalidation |

## Pattern 1: HTML Form + Server Action

```typescript
// Minimal. Works without JavaScript (progressive enhancement).
// Best for: contact forms, appointment booking, simple public forms

export default function ContactPage() {
  async function handleContact(formData: FormData) {
    'use server'
    const name = formData.get('name')
    // process...
    redirect('/contact/success')
  }
  return (
    <form action={handleContact}>
      <input name="name" required />
      <button type="submit">Send</button>
    </form>
  )
}
```

## Pattern 2: React Hook Form + Server Action

```typescript
// Client-side validation with real-time errors + server action for submission
// Best for: complex admin forms, multi-field forms, editing existing data

'use client'
const form = useForm({ resolver: zodResolver(schema) })

async function onSubmit(data) {
  const result = await createInvoice(data)  // server action
  if (!result.success) form.setError('root', { message: result.error })
  else router.push('/admin/invoices')
}

return <form onSubmit={form.handleSubmit(onSubmit)}>...</form>
```

## Pattern 3: Server Action from Event Handler

```typescript
// Simple, non-form actions triggered by button click
// Best for: status changes, deletions, simple toggles

'use client'
async function handleMarkPaid() {
  const result = await markInvoicePaid(invoiceId)
  if (result.success) toast.success('Paid')
  else toast.error(result.error)
}

return <button onClick={handleMarkPaid}>Mark as Paid</button>
```

## Pattern 4: Route Handler + fetch

```typescript
// For webhooks, external consumers, or when you need full HTTP control
// (custom headers, streaming, non-JSON responses)

// WHEN TO USE:
// - Stripe/GitHub webhooks
// - CSV export endpoints (streaming)
// - External API that POSTs to your app
// - Mobile app calling your API

export async function POST(req: NextRequest) {
  // Not a Server Action — this is a Route Handler
}
```

## Why NOT Server Actions for Webhooks

Server Actions are designed for React component callers — they use Next.js internal serialization. Webhooks are HTTP POST requests from external services (Stripe, GitHub) that send raw JSON payloads to a URL. They can't use the Server Action protocol.

```typescript
// WRONG for webhooks:
'use server'
export async function handleStripeWebhook(formData: FormData) {
  // Stripe doesn't send FormData — it sends JSON with raw bytes for HMAC
}

// CORRECT for webhooks:
// app/api/webhooks/stripe/route.ts
export async function POST(req: NextRequest) {
  const body = await req.text()  // raw bytes needed for HMAC signature
  // ...
}
```

## Optimistic Updates

For any of the server-side mutation patterns, add optimistic updates when:
- The operation is quick and likely to succeed
- Waiting for the server response creates noticeable lag

```typescript
// With TanStack Query mutation:
const mutation = useMutation({
  mutationFn: markInvoicePaid,
  onMutate: async (id) => {
    const prev = queryClient.getQueryData(['invoices'])
    queryClient.setQueryData(['invoices'], old => 
      old.map(inv => inv.id === id ? { ...inv, status: 'paid' } : inv)
    )
    return { prev }
  },
  onError: (_, __, context) => queryClient.setQueryData(['invoices'], context.prev),
  onSettled: () => queryClient.invalidateQueries({ queryKey: ['invoices'] }),
})
```
