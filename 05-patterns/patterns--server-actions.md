# Server Actions Pattern

## What Server Actions Are

Server Actions are async functions that run on the server but can be called from Client Components. They're the primary way to mutate data from React forms and Client Components in Next.js App Router.

They replace Route Handlers for mutations originating from React components. They do NOT replace Route Handlers for webhooks or external API consumers.

## Basic Server Action

```typescript
// app/actions/invoices.ts
'use server'
import { createClient } from '@/lib/supabase/server'
import { z } from 'zod'
import { revalidatePath } from 'next/cache'

const UpdateStatusSchema = z.object({
  invoiceId: z.string().uuid(),
  status: z.enum(['pending', 'paid', 'overdue']),
})

export async function updateInvoiceStatus(
  invoiceId: string,
  status: 'pending' | 'paid' | 'overdue'
): Promise<{ success: boolean; error?: string }> {
  // Validate
  const result = UpdateStatusSchema.safeParse({ invoiceId, status })
  if (!result.success) return { success: false, error: 'Invalid input' }
  
  // Auth check
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return { success: false, error: 'Unauthorized' }
  
  // Update
  const { error } = await supabase
    .from('invoices')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', invoiceId)
    .eq('customer_id', user.id)  // RLS: user can only update their own
  
  if (error) return { success: false, error: 'Failed to update' }
  
  // Revalidate the invoices list page
  revalidatePath('/portal/invoices')
  
  return { success: true }
}
```

## Calling a Server Action from a Client Component

```typescript
'use client'
import { updateInvoiceStatus } from '@/app/actions/invoices'
import { useState } from 'react'
import { toast } from 'sonner'

export function MarkPaidButton({ invoiceId }: { invoiceId: string }) {
  const [loading, setLoading] = useState(false)

  async function handleClick() {
    setLoading(true)
    const result = await updateInvoiceStatus(invoiceId, 'paid')
    
    if (result.success) {
      toast.success('Invoice marked as paid')
    } else {
      toast.error(result.error ?? 'Failed to update')
    }
    setLoading(false)
  }

  return (
    <button onClick={handleClick} disabled={loading}>
      {loading ? 'Updating...' : 'Mark as Paid'}
    </button>
  )
}
```

## Server Action in a Form

```typescript
// Direct HTML form submission — no JavaScript required
export default function ContactPage() {
  async function submitContact(formData: FormData) {
    'use server'
    const name = formData.get('name') as string
    // process...
    redirect('/contact/success')
  }

  return (
    <form action={submitContact}>
      <input name="name" />
      <button type="submit">Send</button>
    </form>
  )
}
```

Or with React Hook Form calling the action:
```typescript
'use client'
const form = useForm<FormData>()

async function onSubmit(data: FormData) {
  const result = await createInvoiceAction(data)
  if (!result.success) form.setError('root', { message: result.error })
}
```

## Admin Server Actions

Admin Server Actions use cookie auth, not Supabase JWT:
```typescript
'use server'
import { validateAdminSession } from '@/lib/adminAuth'
import { createAdminClient } from '@/lib/supabase/admin'
import { cookies } from 'next/headers'

export async function adminDeleteInvoice(invoiceId: string) {
  const cookieStore = cookies()
  const isAdmin = await validateAdminSession({ cookies: cookieStore })
  if (!isAdmin) return { success: false, error: 'Unauthorized' }
  
  const supabase = createAdminClient()
  await supabase.from('invoices').delete().eq('id', invoiceId)
  
  revalidatePath('/admin/invoices')
  return { success: true }
}
```

## Return Type Convention

Always return a typed result object — never throw:
```typescript
type ActionResult<T = void> = 
  | { success: true; data: T }
  | { success: false; error: string }

export async function createInvoice(data: FormValues): Promise<ActionResult<{ id: string }>> {
  // ...
  return { success: true, data: { id: invoice.id } }
  // or
  return { success: false, error: 'Customer not found' }
}
```

## revalidatePath and revalidateTag

After a mutation, revalidate affected pages:
```typescript
revalidatePath('/portal/invoices')           // specific path
revalidatePath('/portal/invoices/[id]', 'page')  // all invoice detail pages
revalidateTag('invoices')                    // anything cached with this tag
```

For `revalidateTag` to work, data must be cached with that tag:
```typescript
const getInvoices = unstable_cache(
  async () => supabase.from('invoices').select('*'),
  ['invoices'],
  { tags: ['invoices'] }  // ← tag it here
)
```

## What NOT to Use Server Actions For

- Webhooks (must be Route Handlers — webhook senders POST to a URL, not to a React component)
- External API consumers (use Route Handlers)
- File streaming responses (use Route Handlers with `ReadableStream`)
- CORS-dependent endpoints (use Route Handlers where you can set response headers)
