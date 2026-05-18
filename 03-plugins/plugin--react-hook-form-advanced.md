# Plugin: React Hook Form — Advanced Patterns

## Overview

Advanced patterns for React Hook Form beyond basic setup: dynamic fields, conditional validation, server error mapping, multi-step forms, and file inputs.

## Dynamic Fields (useFieldArray)

```tsx
import { useForm, useFieldArray } from 'react-hook-form'

interface InvoiceForm {
  customer: string
  lineItems: Array<{ description: string; quantity: number; priceCents: number }>
}

export function InvoiceForm() {
  const { register, control, handleSubmit, watch, formState: { errors } } = useForm<InvoiceForm>({
    defaultValues: {
      lineItems: [{ description: '', quantity: 1, priceCents: 0 }],
    },
  })

  const { fields, append, remove } = useFieldArray({ control, name: 'lineItems' })

  const lineItems = watch('lineItems')
  const total = lineItems.reduce((sum, item) => sum + item.quantity * item.priceCents, 0)

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {fields.map((field, index) => (
        <div key={field.id} className="flex gap-3 mb-3">
          <input
            {...register(`lineItems.${index}.description`, { required: 'Required' })}
            placeholder="Description"
            className="flex-1 px-3 py-2 border rounded"
          />
          <input
            {...register(`lineItems.${index}.quantity`, { valueAsNumber: true, min: 1 })}
            type="number"
            className="w-20 px-3 py-2 border rounded"
          />
          <input
            {...register(`lineItems.${index}.priceCents`, { valueAsNumber: true })}
            type="number"
            className="w-28 px-3 py-2 border rounded"
          />
          <button type="button" onClick={() => remove(index)}>Remove</button>
        </div>
      ))}

      <button type="button" onClick={() => append({ description: '', quantity: 1, priceCents: 0 })}>
        Add Line Item
      </button>

      <p>Total: ${total / 100}</p>
    </form>
  )
}
```

Always use `field.id` (from `useFieldArray`) as the `key`, not array index. RHF generates stable IDs that survive reordering.

## Conditional Validation

```tsx
const { register, watch, formState: { errors } } = useForm()
const shippingMethod = watch('shippingMethod')

// Conditional field — only required when shipping to address
<input
  {...register('address', {
    required: shippingMethod === 'delivery' ? 'Address required for delivery' : false,
  })}
/>
```

## Server Error Mapping

```tsx
import { useForm } from 'react-hook-form'

export function SignupForm() {
  const { register, handleSubmit, setError, formState: { errors } } = useForm()

  async function onSubmit(data: FormData) {
    const result = await signUp(data)

    if (result.errors) {
      // Map server validation errors back to field errors
      Object.entries(result.errors).forEach(([field, message]) => {
        setError(field as keyof FormData, {
          type: 'server',
          message: message as string,
        })
      })
    }
  }
}
```

Server actions returning `{ errors: { fieldName: 'message' } }` integrate cleanly with `setError`. This populates inline error messages without a flash-of-error-UI.

## Form with Server Action (Next.js)

```tsx
'use client'
import { useFormState, useFormStatus } from 'react-dom'
import { createInvoice } from '@/app/actions'

// Separate Submit button component to access useFormStatus
function SubmitButton() {
  const { pending } = useFormStatus()
  return (
    <button type="submit" disabled={pending} className="px-4 py-2 bg-blue-600 text-white rounded">
      {pending ? 'Creating...' : 'Create Invoice'}
    </button>
  )
}

export function InvoiceForm() {
  const [state, formAction] = useFormState(createInvoice, { errors: {} })

  return (
    <form action={formAction} className="space-y-4">
      <input name="customer" placeholder="Customer" className="w-full px-3 py-2 border rounded" />
      {state.errors.customer && <p className="text-red-600 text-sm">{state.errors.customer}</p>}

      <SubmitButton />
    </form>
  )
}
```

Use `useFormState` + `useFormStatus` (React DOM) for Server Actions — not RHF. The two approaches don't mix well. RHF is for client-side validation; Server Actions use native form serialization.

## File Input with Preview

```tsx
const { register, watch } = useForm()

// Watch the file input
const file = watch('avatar')?.[0]
const previewUrl = file ? URL.createObjectURL(file) : null

// Cleanup
useEffect(() => {
  return () => { if (previewUrl) URL.revokeObjectURL(previewUrl) }
}, [previewUrl])

<input
  {...register('avatar', { required: 'Please upload an avatar' })}
  type="file"
  accept="image/*"
/>
{previewUrl && <img src={previewUrl} alt="Preview" className="w-20 h-20 rounded-full object-cover" />}
```

## Watch vs. getValues

```ts
// watch() — re-renders component when value changes (reactive)
const email = watch('email')

// getValues() — reads value without subscribing (no re-render)
const currentValues = getValues()  // Use in event handlers, not render

// setValue() — programmatically set a field
setValue('country', 'US', { shouldValidate: true, shouldDirty: true })
```

Only call `watch()` when you need the component to re-render on changes (e.g., to show a live total). Use `getValues()` in `onSubmit` handlers and callbacks.

## Controlled Input with Controller

For third-party inputs (Select, DatePicker, custom inputs) that don't work with `register()`:

```tsx
import { Controller } from 'react-hook-form'
import Select from 'react-select'

<Controller
  name="category"
  control={control}
  rules={{ required: 'Category is required' }}
  render={({ field }) => (
    <Select
      options={categories}
      value={field.value}
      onChange={field.onChange}
      onBlur={field.onBlur}
    />
  )}
/>
```

`Controller` wraps a controlled component and bridges it to RHF's uncontrolled model.
