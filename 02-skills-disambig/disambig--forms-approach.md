# Disambiguation: Which Forms Approach to Use

## Three Approaches

1. **HTML form with Server Action** — simple forms, no complex validation UI
2. **React Hook Form + Server Action** — complex forms, real-time validation, field arrays
3. **Controlled component with fetch** — legacy pattern, more boilerplate

## Decision Matrix

| Scenario | Approach |
|---|---|
| Simple contact form (3-4 fields) | HTML form + Server Action |
| Invoice creation with line items | React Hook Form + Server Action |
| Search/filter inputs | Controlled component with `useSearchParams` |
| Multi-step wizard | React Hook Form, one form per step |
| File upload | HTML form + Server Action or React Hook Form with Controller |
| Fields that depend on each other | React Hook Form (formState, watch) |
| Form that resets after submit | React Hook Form (form.reset()) |

## Pattern 1: HTML Form with Server Action

```typescript
// app/(portal)/contact/page.tsx
export default function ContactPage() {
  return (
    <form action={submitContact}>
      <input name="name" required />
      <input name="email" type="email" required />
      <textarea name="message" required />
      <button type="submit">Send</button>
    </form>
  )
}

// app/actions/contact.ts
'use server'
export async function submitContact(formData: FormData) {
  const name = formData.get('name') as string
  const email = formData.get('email') as string
  const message = formData.get('message') as string
  
  // Validate
  if (!name || !email || !message) return { error: 'All fields required' }
  
  // Send email...
  redirect('/contact/success')
}
```

Use when: the form is simple, inline errors aren't needed, progressive enhancement matters.

## Pattern 2: React Hook Form + Zod + shadcn/ui Form

```typescript
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  customerName: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email'),
  total: z.number().positive('Total must be positive'),
})

type FormData = z.infer<typeof schema>

export function InvoiceForm() {
  const form = useForm<FormData>({ resolver: zodResolver(schema) })

  async function onSubmit(data: FormData) {
    const result = await createInvoice(data)
    if (result.error) form.setError('root', { message: result.error })
    else router.push('/admin/invoices')
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="customerName"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Customer Name</FormLabel>
              <FormControl><Input {...field} /></FormControl>
              <FormMessage />  {/* Shows validation error */}
            </FormItem>
          )}
        />
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting ? 'Saving...' : 'Save Invoice'}
        </Button>
      </form>
    </Form>
  )
}
```

Use when: real-time validation is needed, form has complex logic, or there are field arrays.

## Editing Existing Data

A common mistake is forgetting to populate the form with existing data:
```typescript
// WRONG: form starts empty even when editing
const form = useForm<FormData>()

// CORRECT: populate with existing data
const form = useForm<FormData>({
  defaultValues: {
    customerName: existingInvoice.customer_name,
    email: existingInvoice.email,
    total: existingInvoice.total,
  },
})

// When the data is async (fetched after mount):
useEffect(() => {
  if (invoice) {
    form.reset({
      customerName: invoice.customer_name,
      email: invoice.email,
    })
  }
}, [invoice?.id])  // use invoice.id as dependency, not the full object
```

## Field Arrays (Line Items)

```typescript
import { useFieldArray } from 'react-hook-form'

function LineItemsField({ control }) {
  const { fields, append, remove } = useFieldArray({
    control,
    name: 'lineItems',
  })

  return (
    <div>
      {fields.map((field, index) => (
        <div key={field.id}>  {/* MUST use field.id, not index */}
          <input {...register(`lineItems.${index}.description`)} />
          <input {...register(`lineItems.${index}.amount`, { valueAsNumber: true })} />
          <button type="button" onClick={() => remove(index)}>Remove</button>
        </div>
      ))}
      <button type="button" onClick={() => append({ description: '', amount: 0 })}>
        Add line item
      </button>
    </div>
  )
}
```

Using `index` as key in field arrays causes React reconciliation issues when items are removed. Always use `field.id` from `useFieldArray`.

## Server Action Return Values

```typescript
// Server Action returns structured result, not throws
'use server'
export async function createInvoice(data: FormData) {
  try {
    const invoice = await db.create(data)
    return { success: true, id: invoice.id }
  } catch (error) {
    return { success: false, error: 'Failed to create invoice' }
  }
}

// Client handles it
const result = await createInvoice(data)
if (!result.success) {
  form.setError('root', { message: result.error })
}
```
