# Disambiguation: Server Action vs API Route Handler

## What They Are

**Server Action:** An async function marked `'use server'` that runs on the server but can be called directly from client components. No HTTP overhead, no explicit URL, built into Next.js.

**Route Handler:** A file `app/api/[path]/route.ts` that handles HTTP requests at a specific URL. Works for any HTTP client — browser, mobile app, external service, curl.

## When to Use a Server Action

```typescript
// app/actions/invoice.ts
'use server'
import { createServerClient } from '@supabase/ssr'
import { z } from 'zod'

const schema = z.object({ amount: z.number().positive() })

export async function createInvoice(formData: FormData) {
  const supabase = await createServerClient(/* ... */)
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')
  
  const result = schema.safeParse({ amount: Number(formData.get('amount')) })
  if (!result.success) return { error: 'Invalid input' }
  
  const { data, error } = await supabase
    .from('invoices')
    .insert({ amount: result.data.amount, user_id: user.id })
    .select().single()
  
  if (error) return { error: 'Failed to create' }
  return { data }
}

// In a Client Component:
<form action={createInvoice}>...</form>
// or:
const result = await createInvoice(formData)
```

Use Server Actions when:
- Called only from your Next.js app (not from mobile, not from external services)
- Triggered by form submissions or user interactions
- Working with data that the current user owns
- The caller is a React component, not an HTTP client

## When to Use a Route Handler

```typescript
// app/api/invoices/route.ts
export async function POST(request: Request) {
  // Standard HTTP handler
}
```

Use Route Handlers when:
- The endpoint needs to be called from outside the Next.js app (mobile app, Stripe webhook, Cloudflare Worker, another service)
- The response needs specific HTTP headers (Cache-Control, Authorization, Content-Type for non-JSON)
- You need webhook signature verification (Stripe, GitHub, Twilio all POST to your URL)
- You need streaming responses
- The operation is a background job triggered by Vercel Cron

## The Webhook Case

Stripe, Twilio, and similar services call your webhook URL via HTTP POST. This MUST be a Route Handler:

```typescript
// app/api/webhooks/stripe/route.ts
export async function POST(request: Request) {
  const sig = request.headers.get('stripe-signature')
  // verify signature, process event
}
```

Server Actions cannot receive webhooks — they require a Next.js client to call them.

## Security Considerations

**Server Actions:**
- Automatically include CSRF protection via Next.js
- Auth check must still be explicit inside the action

**Route Handlers:**
- No built-in CSRF protection — you must handle it
- Must verify auth explicitly
- Webhook routes must verify the webhook signature

## Performance Tradeoffs

**Server Actions:** No HTTP round-trip overhead. The call goes directly from component to server function. Good for interactive UI.

**Route Handlers:** Full HTTP request/response cycle. Slightly more overhead but no performance issue in practice for typical web operations.

## Combining Both

Most Next.js apps need both:
- Server Actions: for form submissions, user-triggered mutations
- Route Handlers: for webhooks, external API consumers, cron jobs, streaming

They coexist in the same Next.js app without conflict.
