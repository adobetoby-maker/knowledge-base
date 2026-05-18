# Next.js — Server Actions vs API Routes

**When:** Deciding how to handle form submissions, mutations, or data fetching that needs to run on the server.
**Rule:** Server Actions for simple mutations tied to a UI. API Routes for everything that needs to be called from outside, by multiple callers, or with complex request/response shapes.

## What Each Is

**Server Actions** — async functions marked `'use server'` that run on the server when called from a component. Zero API endpoint — called like regular functions. No fetch needed.

**API Routes** — traditional HTTP endpoints at `app/api/[route]/route.ts`. Called with `fetch()`. Return `Response` objects.

## Decision Branch
- IF only called from one specific component → Server Action
- IF called from multiple places (different pages, external services) → API Route
- IF needs to be called from a mobile app or external system → API Route
- IF it's a form submit or button click → Server Action (simpler, no fetch boilerplate)
- IF it needs complex headers, streaming, or webhook behavior → API Route
- IF you need to handle file uploads from external sources → API Route
- IF progressive enhancement matters (form works without JS) → Server Action
- IF you're building a webhook receiver → API Route

## Server Action Pattern
```typescript
// app/actions.ts — or inline in the component
'use server'
import { revalidatePath } from 'next/cache'

export async function updateProfile(formData: FormData) {
  const name = formData.get('name') as string
  // validate at the boundary
  if (!name) throw new Error('Name required')
  
  await db.profiles.update({ name })
  revalidatePath('/profile')  // bust cache
}

// In component — no fetch, no useState for loading
<form action={updateProfile}>
  <input name="name" />
  <button type="submit">Save</button>
</form>
```

## API Route Pattern
```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'  // webhooks are never static

export async function POST(req: NextRequest) {
  const body = await req.text()  // raw body for signature verification
  const sig = req.headers.get('stripe-signature')!
  
  // validate at the boundary
  const event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET!)
  
  // handle event
  return NextResponse.json({ received: true })
}
```

## CSRF — Server Actions Are Protected, API Routes Are Not
Next.js automatically validates the origin header on Server Actions — no CSRF token needed.
API Routes have no automatic CSRF protection — add it manually for state-changing endpoints.

## Error Handling Difference
Server Actions — thrown errors surface in `useFormState` or cause a server-side error page.
API Routes — return error responses explicitly: `NextResponse.json({ error: '...' }, { status: 400 })`.

## Common Mistake
Using `fetch('/api/update-profile', ...)` in a Server Component.
Server Components can call Server Actions or database functions directly — no fetch hop needed.
The fetch adds latency (loopback request) and complexity for no benefit.
