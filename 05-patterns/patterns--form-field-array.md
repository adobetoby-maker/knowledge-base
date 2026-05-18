# Pattern: Form Field Arrays

## Overview

Dynamic lists of form fields: add/remove skills, addresses, line items, team members. The key challenge: keeping field-level error messages aligned with the correct item after add/remove operations. Use `useFieldArray` from `react-hook-form` — it handles index tracking correctly when items are inserted/removed.

## React Hook Form useFieldArray

```tsx
import { useForm, useFieldArray } from 'react-hook-form'
import { z } from 'zod'
import { zodResolver } from '@hookform/resolvers/zod'

const lineItemSchema = z.object({
  description: z.string().min(1, 'Required'),
  quantity: z.coerce.number().int().positive('Must be positive'),
  unitPriceCents: z.coerce.number().int().positive('Must be positive'),
})

const invoiceSchema = z.object({
  clientName: z.string().min(1, 'Required'),
  lineItems: z.array(lineItemSchema).min(1, 'Add at least one item'),
})

type InvoiceForm = z.infer<typeof invoiceSchema>

export function InvoiceForm({ onSubmit }: { onSubmit: (data: InvoiceForm) => void }) {
  const {
    register,
    control,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<InvoiceForm>({
    resolver: zodResolver(invoiceSchema),
    defaultValues: {
      lineItems: [{ description: '', quantity: 1, unitPriceCents: 0 }],
    },
  })

  const { fields, append, remove, move } = useFieldArray({
    control,
    name: 'lineItems',
  })

  const lineItems = watch('lineItems')
  const total = lineItems.reduce((sum, item) =>
    sum + (Number(item.quantity) || 0) * (Number(item.unitPriceCents) || 0), 0)

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      <div>
        <label className="block text-sm font-medium mb-1">Client name</label>
        <input {...register('clientName')} className="input" />
        {errors.clientName && <p className="text-red-500 text-xs mt-1">{errors.clientName.message}</p>}
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="font-medium">Line items</h3>
          <button
            type="button"
            onClick={() => append({ description: '', quantity: 1, unitPriceCents: 0 })}
            className="text-sm text-blue-600 hover:underline"
          >
            + Add item
          </button>
        </div>

        {errors.lineItems?.message && (
          <p className="text-red-500 text-xs">{errors.lineItems.message}</p>
        )}

        {fields.map((field, index) => (
          <LineItemRow
            key={field.id}           // Must use field.id, not index!
            index={index}
            register={register}
            errors={errors.lineItems?.[index]}
            onRemove={() => remove(index)}
            canRemove={fields.length > 1}
          />
        ))}
      </div>

      <div className="text-right font-semibold">
        Total: ${(total / 100).toFixed(2)}
      </div>

      <button type="submit" className="btn-primary w-full">Create invoice</button>
    </form>
  )
}
```

## Line Item Row Component

```tsx
function LineItemRow({ index, register, errors, onRemove, canRemove }) {
  return (
    <div className="grid grid-cols-[1fr_80px_100px_40px] gap-2 items-start">
      <div>
        <input
          {...register(`lineItems.${index}.description`)}
          placeholder="Description"
          className="input w-full"
        />
        {errors?.description && (
          <p className="text-red-500 text-xs mt-0.5">{errors.description.message}</p>
        )}
      </div>

      <div>
        <input
          {...register(`lineItems.${index}.quantity`)}
          type="number"
          min="1"
          placeholder="Qty"
          className="input w-full"
        />
        {errors?.quantity && (
          <p className="text-red-500 text-xs mt-0.5">{errors.quantity.message}</p>
        )}
      </div>

      <div>
        <input
          {...register(`lineItems.${index}.unitPriceCents`)}
          type="number"
          min="0"
          placeholder="Price (¢)"
          className="input w-full"
        />
        {errors?.unitPriceCents && (
          <p className="text-red-500 text-xs mt-0.5">{errors.unitPriceCents.message}</p>
        )}
      </div>

      <button
        type="button"
        onClick={onRemove}
        disabled={!canRemove}
        className="text-gray-400 hover:text-red-500 disabled:opacity-30 pt-2"
        aria-label="Remove item"
      >
        ×
      </button>
    </div>
  )
}
```

## Drag-to-Reorder (with dnd-kit)

```tsx
import { DndContext, closestCenter } from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy, useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'

function SortableLineItem({ id, ...props }) {
  const { attributes, listeners, setNodeRef, transform, transition } = useSortable({ id })

  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      className="flex gap-2 items-start"
    >
      <button {...attributes} {...listeners} className="cursor-grab mt-2 text-gray-400">⠿</button>
      <LineItemRow {...props} />
    </div>
  )
}

// Wrap fields in DndContext
<DndContext collisionDetection={closestCenter} onDragEnd={({ active, over }) => {
  if (over && active.id !== over.id) {
    const from = fields.findIndex(f => f.id === active.id)
    const to = fields.findIndex(f => f.id === over.id)
    move(from, to)
  }
}}>
  <SortableContext items={fields.map(f => f.id)} strategy={verticalListSortingStrategy}>
    {fields.map((field, index) => (
      <SortableLineItem key={field.id} id={field.id} index={index} ... />
    ))}
  </SortableContext>
</DndContext>
```

## Key Rules

- Always use `field.id` as the React `key`, not `index` — using index causes error messages to misalign after remove operations.
- `useFieldArray` must be initialized with `defaultValues` that match the schema shape — missing fields cause validation errors on first render.
- Access field errors as `errors.lineItems?.[index]?.fieldName` — optional chaining is required since the index may not have an error.
- `append` adds to the end; `insert(index, value)` adds at a specific position.
- For large arrays (50+ items), use `shouldUnregister: false` to prevent field unregistration on remove.
