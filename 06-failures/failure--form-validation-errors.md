# Failure Patterns: Form Validation Errors

## Zod and React Hook Form Misalignment

When the Zod schema shape doesn't match what the form expects:

```typescript
// Schema:
const schema = z.object({
  amount: z.number().positive()  // expects number
})

// Input returns string by default:
<Input type="number" {...register('amount')} />
// RHF passes "25" (string) to Zod → validation fails with "Expected number, received string"

// Fix — coerce the string input to number:
const schema = z.object({
  amount: z.coerce.number().positive()  // coerces "25" → 25
})

// OR use valueAsNumber:
<Input type="number" {...register('amount', { valueAsNumber: true })} />
```

## Errors Not Showing for Nested Fields

```typescript
// Schema with nested object:
const schema = z.object({
  address: z.object({
    street: z.string().min(1),
    city: z.string().min(1),
  })
})

// WRONG — accessing error at wrong path:
const { formState: { errors } } = useForm()
errors.street  // undefined — nested under address

// CORRECT:
errors.address?.street?.message  // correct path
errors.address?.city?.message

// With FormField:
<FormField
  control={form.control}
  name="address.street"  // dot notation for nested fields
  render={({ field }) => (
    <FormItem>
      <FormControl><Input {...field} /></FormControl>
      <FormMessage />  {/* automatically shows errors.address.street.message */}
    </FormItem>
  )}
/>
```

## Server Action Errors Not Displayed

```typescript
// WRONG — throwing from Server Action (error becomes "An error occurred"):
export async function createInvoice(data: CreateInvoiceData) {
  const invoice = await db.invoices.create(data)  // throws on DB error
  revalidatePath('/invoices')
}

// CORRECT — return structured errors:
export async function createInvoice(data: CreateInvoiceData): Promise<ActionResult> {
  try {
    const invoice = await db.invoices.create(data)
    revalidatePath('/invoices')
    return { success: true, data: invoice }
  } catch (error) {
    return { success: false, error: 'Failed to create invoice. Please try again.' }
  }
}

// In the form:
const [result, setResult] = useState<ActionResult | null>(null)

async function onSubmit(values: FormValues) {
  const result = await createInvoice(values)
  setResult(result)
  if (result.success) router.push('/invoices')
}

{result && !result.success && (
  <Alert variant="destructive">{result.error}</Alert>
)}
```

## Date Fields Failing Validation

```typescript
// WRONG — date input returns string, Zod expects Date:
const schema = z.object({
  dueDate: z.date()
})
// <Input type="date" /> returns "2025-01-15" (string) → Zod fails

// CORRECT — coerce or preprocess:
const schema = z.object({
  dueDate: z.coerce.date()  // coerces "2025-01-15" → Date object
})

// OR handle in RHF:
const { register } = useForm<{ dueDate: Date }>({
  resolver: zodResolver(schema),
})

// Native date input needs coercion:
<input type="date" {...register('dueDate', { valueAsDate: true })} />
```

## Array Field Errors Not Rendering

```typescript
// Schema:
const schema = z.object({
  lineItems: z.array(z.object({
    description: z.string().min(1),
    amount: z.coerce.number().positive(),
  })).min(1, 'At least one line item required')
})

// useFieldArray errors:
const { fields, append, remove } = useFieldArray({ control, name: 'lineItems' })
const { errors } = formState

// Access array-level error:
errors.lineItems?.root?.message     // "At least one line item required"
errors.lineItems?.message           // also works for some versions

// Access per-item errors:
errors.lineItems?.[0]?.description?.message
errors.lineItems?.[0]?.amount?.message
```

## Checkbox Not Registering True/False

```typescript
// WRONG — checkbox value is "on" string, not boolean:
<input type="checkbox" {...register('agreed')} />

// Schema expects boolean:
const schema = z.object({ agreed: z.boolean() })
// Zod sees "on" → validation fails

// CORRECT — use shadcn Checkbox with Controller:
<FormField
  control={form.control}
  name="agreed"
  render={({ field }) => (
    <FormItem className="flex items-center gap-2">
      <FormControl>
        <Checkbox checked={field.value} onCheckedChange={field.onChange} />
      </FormControl>
      <FormLabel>I agree to the terms</FormLabel>
    </FormItem>
  )}
/>
```

## Re-Render Loop from watch()

```typescript
// WRONG — watching the entire form causes infinite renders:
const values = watch()  // re-renders on every keystroke across all fields
useEffect(() => {
  calculateTotal(values)  // runs on every render
}, [values])  // values changes every render

// CORRECT — watch specific fields:
const [quantity, unitPrice] = watch(['quantity', 'unitPrice'])
const total = quantity * unitPrice  // just compute directly — no useEffect needed
```
