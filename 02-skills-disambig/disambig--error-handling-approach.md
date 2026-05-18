# Error Handling Approach

## Three Error Categories

**1. Expected failures** — validation errors, not found, unauthorized. Return structured error responses, don't throw.

**2. Unexpected failures** — database connection failure, external API down, code bug. Catch, log, return generic error response.

**3. Unrecoverable failures** — app startup with missing env vars, corrupted state. Throw at startup, crash early.

## In Route Handlers

```typescript
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  
  // Auth check — expected failure (401)
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  // DB query — may fail unexpectedly
  const { data: invoice, error } = await supabase
    .from('invoices')
    .select('*')
    .eq('id', id)
    .single()
  
  if (error) {
    if (error.code === 'PGRST116') {
      // Not found — expected
      return NextResponse.json({ error: 'Invoice not found' }, { status: 404 })
    }
    // Unexpected DB error
    console.error('DB error fetching invoice:', { id, error: error.message })
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
  
  // Authorization check — user can only see their own
  if (invoice.user_id !== user.id) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }
  
  return NextResponse.json(invoice)
}
```

## In Server Actions

Server Actions can throw — Next.js handles the throw and passes it to the nearest `error.tsx` boundary.

But for form submissions, it's better to return structured state:

```typescript
// app/actions/invoices.ts
'use server'
import { revalidatePath } from 'next/cache'

type ActionResult = { success: true } | { success: false; error: string }

export async function createInvoice(prevState: ActionResult | null, formData: FormData): Promise<ActionResult> {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user) return { success: false, error: 'You must be logged in' }
  
  const customerName = formData.get('customer_name') as string
  if (!customerName?.trim()) {
    return { success: false, error: 'Customer name is required' }
  }
  
  const { error } = await supabase.from('invoices').insert({
    user_id: user.id,
    customer_name: customerName,
  })
  
  if (error) {
    console.error('Invoice creation error:', error)
    return { success: false, error: 'Failed to create invoice. Please try again.' }
  }
  
  revalidatePath('/portal/invoices')
  return { success: true }
}
```

## In Client Components

```typescript
'use client'
import { useState } from 'react'

export function InvoiceActions({ invoiceId }: { invoiceId: string }) {
  const [error, setError] = useState<string | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)

  async function handleDelete() {
    setIsDeleting(true)
    setError(null)
    
    try {
      const res = await fetch(`/api/invoices/${invoiceId}`, { method: 'DELETE' })
      
      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        throw new Error(data.error ?? `Request failed: ${res.status}`)
      }
      
      // Success — navigate or refresh
    } catch (err) {
      setError((err as Error).message ?? 'Something went wrong')
    } finally {
      setIsDeleting(false)
    }
  }

  return (
    <div>
      {error && <p className="text-sm text-red-500">{error}</p>}
      <button onClick={handleDelete} disabled={isDeleting}>
        {isDeleting ? 'Deleting...' : 'Delete'}
      </button>
    </div>
  )
}
```

## Error Response Shape Consistency

All Route Handlers should return the same error shape:

```typescript
// Always: { error: string } for errors
// Never: { message: string } or { err: string } — inconsistent
return NextResponse.json({ error: 'Invoice not found' }, { status: 404 })
return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

// For validation errors, include field details:
return NextResponse.json({
  error: 'Validation failed',
  fields: { customer_name: 'Required', amount: 'Must be positive' }
}, { status: 422 })
```

## When to Use error.tsx vs Try/Catch

| Situation | Approach |
|-----------|----------|
| Page data fetch fails | error.tsx catches (thrown by notFound() or Server Component throw) |
| Form submission fails | Return error state in Server Action, display inline |
| API call fails | try/catch in client component, display inline error |
| Missing env var at startup | Throw in module initialization (crashes dev server immediately) |
| Webhook processing fails | Return 500, let provider retry |
