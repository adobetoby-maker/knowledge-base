# Stack Bundle: Next.js Form Patterns

## Purpose

Compact reference for building forms in Next.js 15 with React Hook Form, Zod, and Server Actions. Load this for any form-building task.

## The Full Stack

```
React Hook Form — client-side state + validation UX
Zod — validation schema (shared between client and server)
Server Action — mutation handler (not a Route Handler)
shadcn/ui Form — styled components
```

## Complete Form Implementation

```typescript
// 1. Schema (shared):
// lib/schemas/invoice.ts
import { z } from 'zod'

export const CreateInvoiceSchema = z.object({
  customer_name: z.string().min(1, 'Customer name is required'),
  customer_email: z.string().email('Enter a valid email'),
  amount_cents: z.coerce.number().int().positive('Amount must be greater than $0'),
  due_date: z.string().min(1, 'Due date is required'),
  notes: z.string().optional(),
})

export type CreateInvoiceInput = z.infer<typeof CreateInvoiceSchema>
```

```typescript
// 2. Server Action:
// lib/actions/invoices.ts
'use server'
import { validateAdminSession } from '@/lib/adminAuth'
import { CreateInvoiceSchema } from '@/lib/schemas/invoice'
import { revalidatePath } from 'next/cache'

export async function createInvoice(
  input: CreateInvoiceInput
): Promise<{ success: boolean; error?: string; invoiceId?: string }> {
  await validateAdminSession()
  
  const result = CreateInvoiceSchema.safeParse(input)
  if (!result.success) {
    return { success: false, error: result.error.issues[0].message }
  }
  
  const { error: dbError, data } = await supabase
    .from('invoices')
    .insert(result.data)
    .select('id')
    .single()
  
  if (dbError) {
    console.error('Create invoice error:', dbError)
    return { success: false, error: 'Failed to create invoice' }
  }
  
  revalidatePath('/admin/invoices')
  return { success: true, invoiceId: data.id }
}
```

```typescript
// 3. Form Component:
// app/(admin)/invoices/new/page.tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { createInvoice } from '@/lib/actions/invoices'
import { CreateInvoiceSchema, CreateInvoiceInput } from '@/lib/schemas/invoice'

export default function NewInvoicePage() {
  const router = useRouter()
  const [isPending, startTransition] = useTransition()
  
  const form = useForm<CreateInvoiceInput>({
    resolver: zodResolver(CreateInvoiceSchema),
    defaultValues: {
      customer_name: '',
      customer_email: '',
      amount_cents: undefined,
      due_date: '',
      notes: '',
    },
  })
  
  function onSubmit(data: CreateInvoiceInput) {
    startTransition(async () => {
      const result = await createInvoice(data)
      if (result.success) {
        toast.success('Invoice created')
        router.push('/admin/invoices')
      } else {
        form.setError('root', { message: result.error ?? 'Unknown error' })
      }
    })
  }
  
  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4 max-w-lg">
        <FormField
          control={form.control}
          name="customer_name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Customer Name</FormLabel>
              <FormControl><Input {...field} /></FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="amount_cents"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Amount (dollars)</FormLabel>
              <FormControl>
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  {...field}
                  onChange={(e) => field.onChange(Math.round(Number(e.target.value) * 100))}
                  value={field.value ? field.value / 100 : ''}
                />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />
        
        {form.formState.errors.root && (
          <Alert variant="destructive">
            <AlertDescription>{form.formState.errors.root.message}</AlertDescription>
          </Alert>
        )}
        
        <div className="flex gap-2">
          <Button type="button" variant="outline" onClick={() => router.back()}>
            Cancel
          </Button>
          <Button type="submit" disabled={isPending}>
            {isPending ? 'Creating...' : 'Create Invoice'}
          </Button>
        </div>
      </form>
    </Form>
  )
}
```

## Key Rules

1. **`z.coerce.number()`** for numeric inputs — form values are always strings, coerce converts
2. **`form.setError('root', ...)`** for server errors — not field-level
3. **`useTransition`** for pending state — don't use `useState(loading)`
4. **Zod on both sides** — client validates before submit, server validates again (defense in depth)
5. **Never throw from Server Actions** — return `{ success: false, error: ... }`
