# Form with Server Action Pattern

## Overview

Server Actions called from React Hook Form — the most common mutation pattern in this stack. The form validates client-side, the server action validates server-side, and the result updates the UI.

## Complete Implementation

```typescript
// 1. Server Action (app/actions/invoices.ts)
'use server'
import { z } from 'zod'
import { createClient } from '@/lib/supabase/server'
import { createAdminClient } from '@/lib/supabase/admin'
import { validateAdminSession } from '@/lib/adminAuth'
import { revalidatePath } from 'next/cache'
import { cookies } from 'next/headers'

const CreateInvoiceSchema = z.object({
  customer_name: z.string().min(2),
  total: z.number().positive(),
  due_date: z.string().optional(),
  notes: z.string().optional(),
})

type CreateInvoiceResult =
  | { success: true; id: string }
  | { success: false; error: string }

export async function createInvoice(
  data: z.infer<typeof CreateInvoiceSchema>
): Promise<CreateInvoiceResult> {
  // Auth check
  const cookieStore = cookies()
  const isAdmin = await validateAdminSession({ cookies: cookieStore })
  if (!isAdmin) return { success: false, error: 'Unauthorized' }

  // Server-side validation (even though client already validated)
  const result = CreateInvoiceSchema.safeParse(data)
  if (!result.success) return { success: false, error: 'Invalid data' }

  const supabase = createAdminClient()
  const { data: invoice, error } = await supabase
    .from('invoices')
    .insert({
      customer_name: result.data.customer_name,
      total: result.data.total,
      due_date: result.data.due_date,
      notes: result.data.notes,
      status: 'pending',
    })
    .select('id')
    .single()

  if (error) {
    console.error('Invoice creation failed:', error)
    return { success: false, error: 'Failed to create invoice' }
  }

  revalidatePath('/admin/invoices')
  return { success: true, id: invoice.id }
}
```

```typescript
// 2. Form Component (components/admin/CreateInvoiceForm.tsx)
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { createInvoice } from '@/app/actions/invoices'
import {
  Form, FormControl, FormField, FormItem, FormLabel, FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

// Reuse the same schema shape (import or duplicate for client bundle)
const schema = z.object({
  customer_name: z.string().min(2, 'Name is required'),
  total: z.number({ required_error: 'Total is required' }).positive('Must be positive'),
  due_date: z.string().optional(),
  notes: z.string().optional(),
})

type FormValues = z.infer<typeof schema>

export function CreateInvoiceForm() {
  const router = useRouter()
  const form = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      customer_name: '',
      total: 0,
      due_date: '',
      notes: '',
    },
  })

  async function onSubmit(data: FormValues) {
    const result = await createInvoice(data)
    
    if (!result.success) {
      // Show error — either top-level or on a specific field
      form.setError('root', { message: result.error })
      return
    }
    
    toast.success('Invoice created')
    router.push(`/admin/invoices/${result.id}`)
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 max-w-lg">
        
        {/* Root error (server-returned errors) */}
        {form.formState.errors.root && (
          <div className="p-3 text-sm text-destructive bg-destructive/10 rounded-md">
            {form.formState.errors.root.message}
          </div>
        )}
        
        <FormField
          control={form.control}
          name="customer_name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Customer Name</FormLabel>
              <FormControl>
                <Input {...field} placeholder="John Smith" />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="total"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Total Amount</FormLabel>
              <FormControl>
                <Input
                  {...field}
                  type="number"
                  step="0.01"
                  onChange={e => field.onChange(parseFloat(e.target.value) || 0)}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="due_date"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Due Date (optional)</FormLabel>
              <FormControl>
                <Input {...field} type="date" />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button
          type="submit"
          disabled={form.formState.isSubmitting}
          className="w-full"
        >
          {form.formState.isSubmitting ? 'Creating...' : 'Create Invoice'}
        </Button>
      </form>
    </Form>
  )
}
```

## Number Input Gotcha

React Hook Form returns string values from input[type=number]. Convert explicitly:
```typescript
onChange={e => field.onChange(parseFloat(e.target.value) || 0)}
// Without this: form data has "42.5" (string) instead of 42.5 (number)
```

Or use `z.coerce.number()` in the schema to handle string → number conversion:
```typescript
total: z.coerce.number().positive('Must be positive'),
// Then the string from the input is coerced to number by Zod
```

## Edit Form Pattern

For edit forms, set `defaultValues` from the existing record:
```typescript
const form = useForm<FormValues>({
  resolver: zodResolver(schema),
  defaultValues: {
    customer_name: invoice.customer_name,
    total: invoice.total,
    due_date: invoice.due_date ?? '',
  },
})

// If data loads async (after mount):
useEffect(() => {
  if (invoice) form.reset(invoice)
}, [invoice?.id])  // use ID as dep, not full object (prevents infinite loop)
```
