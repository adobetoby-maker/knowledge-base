# When to Use Server Actions vs Client Event Handlers

## The Core Decision

Server Actions (declared with `'use server'`) run on the server. They're the right tool when you need to write data and the caller is a React component.

Client event handlers run in the browser. They call APIs, update local state, and handle UI interactions.

## Decision Matrix

| Scenario | Use |
|----------|-----|
| Form submission that writes to DB | Server Action |
| Button that deletes a record | Server Action |
| Webhook endpoint | Route Handler (not Server Action) |
| Mobile app consuming your API | Route Handler |
| Browser-side state update (no server needed) | Client event handler |
| Complex mutation with optimistic update | Client event handler + Route Handler |
| Sequential steps with progress feedback | Client event handler + Route Handler |
| Cron job | Route Handler |

## Server Action — When It's Right

```typescript
// app/actions/invoices.ts
'use server'
import { revalidatePath } from 'next/cache'
import { createClient } from '@/lib/supabase/server'

export async function createInvoice(formData: FormData) {
  const supabase = await createClient()
  
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')

  const { error } = await supabase.from('invoices').insert({
    customer_name: formData.get('customer_name') as string,
    amount: Number(formData.get('amount')),
    user_id: user.id,
  })

  if (error) throw new Error(error.message)
  revalidatePath('/portal/invoices')
}

// Usage in a component
<form action={createInvoice}>
  <input name="customer_name" />
  <button type="submit">Create</button>
</form>
```

The Server Action handles auth, DB write, and cache revalidation — no Route Handler needed.

## Route Handler — When It's Right

```typescript
// app/api/invoices/route.ts — for external callers
export async function POST(req: NextRequest) {
  const apiKey = req.headers.get('x-api-key')
  if (apiKey !== process.env.API_KEY) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }
  
  const body = await req.json()
  // ... handle request
  return NextResponse.json({ id: invoice.id })
}
```

Route Handlers are needed when the caller is not a React component (webhooks, mobile apps, external services, curl).

## Combining Both

A component can use a Server Action for its form while a mobile app uses the Route Handler for the same functionality:

```typescript
// app/actions/invoices.ts — used by React forms
'use server'
export async function createInvoiceAction(formData: FormData) {
  const data = {
    customer_name: formData.get('customer_name') as string,
    amount: Number(formData.get('amount')),
  }
  await createInvoiceCore(data)
  revalidatePath('/portal/invoices')
}

// app/api/invoices/route.ts — used by external callers
export async function POST(req: NextRequest) {
  const data = await req.json()
  await createInvoiceCore(data)
  return NextResponse.json({ success: true })
}

// lib/invoice-operations.ts — shared core logic
export async function createInvoiceCore(data: CreateInvoiceInput) {
  // auth + validation + DB write
}
```

## Progressive Enhancement Consideration

Server Actions work without JavaScript (form submits to server). Route Handlers require JavaScript for `fetch()`. If the form must work without JS, use a Server Action.

If the form's UX requires JavaScript anyway (real-time validation, optimistic updates), the distinction matters less and either approach works.

## The Webhook Exception

Webhooks MUST use Route Handlers. They're called by external services (Stripe, GitHub, Clerk) that send raw HTTP POST requests — they don't know about React's Server Actions protocol.

```typescript
// app/api/webhooks/stripe/route.ts — CORRECT
export async function POST(req: NextRequest) { ... }

// WRONG — Server Actions cannot receive webhook calls
'use server'
export async function stripeWebhook(formData: FormData) { ... }  // This won't work
```
