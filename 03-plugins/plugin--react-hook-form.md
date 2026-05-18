# React Hook Form

## Why React Hook Form

React Hook Form reduces re-renders by using uncontrolled inputs internally. Unlike controlled forms where every keystroke causes a re-render, RHF only updates state on submission and validation. This matters for large forms.

## Basic Setup with Zod

```typescript
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const invoiceSchema = z.object({
  customer_name: z.string().min(1, 'Customer name is required'),
  email: z.string().email('Valid email required').optional().or(z.literal('')),
  amount: z.coerce.number().positive('Amount must be positive'),
  notes: z.string().optional(),
})

type InvoiceFormValues = z.infer<typeof invoiceSchema>

export function InvoiceForm({ onSubmit }: { onSubmit: (data: InvoiceFormValues) => Promise<void> }) {
  const form = useForm<InvoiceFormValues>({
    resolver: zodResolver(invoiceSchema),
    defaultValues: {
      customer_name: '',
      email: '',
      amount: 0,
      notes: '',
    },
  })

  const handleSubmit = form.handleSubmit(async (data) => {
    await onSubmit(data)
    form.reset()
  })

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="customer_name">Customer Name</label>
        <input
          id="customer_name"
          {...form.register('customer_name')}
          className={form.formState.errors.customer_name ? 'border-red-500' : ''}
        />
        {form.formState.errors.customer_name && (
          <p className="text-sm text-red-500">{form.formState.errors.customer_name.message}</p>
        )}
      </div>
      
      <button type="submit" disabled={form.formState.isSubmitting}>
        {form.formState.isSubmitting ? 'Creating...' : 'Create Invoice'}
      </button>
    </form>
  )
}
```

## With shadcn/ui Form Components

shadcn/ui provides Form components that integrate with React Hook Form:

```typescript
import {
  Form,
  FormField,
  FormItem,
  FormLabel,
  FormControl,
  FormDescription,
  FormMessage,
} from '@/components/ui/form'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'

export function InvoiceForm() {
  const form = useForm<InvoiceFormValues>({
    resolver: zodResolver(invoiceSchema),
    defaultValues: { customer_name: '', amount: 0 },
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="customer_name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Customer Name</FormLabel>
              <FormControl>
                <Input placeholder="John Doe" {...field} />
              </FormControl>
              <FormMessage />  {/* automatically shows Zod error */}
            </FormItem>
          )}
        />
        
        <FormField
          control={form.control}
          name="amount"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Amount</FormLabel>
              <FormControl>
                <Input type="number" step="0.01" {...field} />
              </FormControl>
              <FormDescription>Enter the invoice amount in USD</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />
        
        <Button type="submit" disabled={form.formState.isSubmitting}>
          Create Invoice
        </Button>
      </form>
    </Form>
  )
}
```

## Editing Existing Data

Pass `defaultValues` from the existing record:

```typescript
export function EditInvoiceForm({ invoice }: { invoice: Invoice }) {
  const form = useForm<InvoiceFormValues>({
    resolver: zodResolver(invoiceSchema),
    defaultValues: {
      customer_name: invoice.customer_name,
      amount: invoice.amount,
      notes: invoice.notes ?? '',
    },
  })
  
  // form.reset(newValues) when the invoice prop changes
  useEffect(() => {
    form.reset({
      customer_name: invoice.customer_name,
      amount: invoice.amount,
    })
  }, [invoice.id])
  
  // ...
}
```

## Dynamic Fields (FieldArray)

```typescript
import { useFieldArray } from 'react-hook-form'

const schema = z.object({
  line_items: z.array(z.object({
    description: z.string().min(1),
    quantity: z.coerce.number().int().positive(),
    unit_price: z.coerce.number().positive(),
  })).min(1),
})

export function InvoiceWithLineItems() {
  const form = useForm({ resolver: zodResolver(schema) })
  const { fields, append, remove } = useFieldArray({
    control: form.control,
    name: 'line_items',
  })

  return (
    <form>
      {fields.map((field, index) => (
        <div key={field.id}>  {/* use field.id, not index, as key */}
          <input {...form.register(`line_items.${index}.description`)} />
          <input {...form.register(`line_items.${index}.quantity`)} />
          <button type="button" onClick={() => remove(index)}>Remove</button>
        </div>
      ))}
      <button type="button" onClick={() => append({ description: '', quantity: 1, unit_price: 0 })}>
        Add Line Item
      </button>
    </form>
  )
}
```

## Common Mistakes

- **Missing `defaultValues`** — fields without defaults are undefined, can cause type errors and uncontrolled → controlled warning
- **Using `index` as `key` in FieldArray** — causes state bugs when items are removed; use `field.id`
- **Calling `form.reset()` inside the render** — resets on every render; call in `onSubmit` or `useEffect` only
