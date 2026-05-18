# Plugin: Zod

## What It Is

Zod is a TypeScript-first schema validation library. It validates data at runtime and infers TypeScript types from the schema — you define the shape once, get both validation and types.

## Core Usage Pattern

```typescript
import { z } from 'zod'

// Define schema
const InvoiceSchema = z.object({
  amount: z.number().positive().max(100000),
  description: z.string().min(1).max(500).trim(),
  customerId: z.string().uuid(),
  dueDate: z.string().datetime().optional(),
  status: z.enum(['pending', 'paid', 'cancelled']).default('pending')
})

// Infer TypeScript type (no duplication)
type Invoice = z.infer<typeof InvoiceSchema>

// Validate safely (doesn't throw)
const result = InvoiceSchema.safeParse(untrustedData)
if (!result.success) {
  console.log(result.error.flatten().fieldErrors)
  // { amount: ['Number must be positive'], description: [] }
}
// result.data is fully typed if success

// Validate and throw (use in scripts, not API handlers)
const invoice = InvoiceSchema.parse(data)  // throws ZodError if invalid
```

## Primitive Validators

```typescript
z.string()
z.string().email()
z.string().url()
z.string().uuid()
z.string().min(3).max(100)
z.string().regex(/^\d{10}$/)
z.string().trim()  // trims whitespace before validation

z.number()
z.number().int()
z.number().positive()
z.number().min(0).max(1000)
z.number().multipleOf(0.01)  // for currency

z.boolean()
z.date()
z.null()
z.undefined()
z.literal('active')  // exact value
z.enum(['a', 'b', 'c'])

z.array(z.string())
z.array(z.string()).min(1).max(10)
```

## Optional vs Nullable vs Default

```typescript
z.string().optional()    // value can be undefined (field may be absent)
z.string().nullable()    // value can be null
z.string().nullish()     // value can be null or undefined
z.string().default('')   // use '' if value is undefined
```

In database schemas, use `.nullable()` for columns that can be NULL. Use `.optional()` for fields that may not be present in request bodies.

## Nested Objects

```typescript
const AddressSchema = z.object({
  street: z.string(),
  city: z.string(),
  state: z.string().length(2),
  zip: z.string().regex(/^\d{5}$/),
})

const CustomerSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  address: AddressSchema,
  tags: z.array(z.string()).optional(),
})
```

## Union Types

```typescript
// Discriminated union (recommended for OR types)
const ResultSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('success'), data: z.string() }),
  z.object({ type: z.literal('error'), message: z.string() }),
])

// Simple union
const IdSchema = z.union([z.string(), z.number()])
```

## Transform — Parse Into Different Shape

```typescript
const FormDataSchema = z.object({
  amount: z.string().transform(val => parseFloat(val)),  // form string → number
  date: z.string().transform(val => new Date(val)),
  tags: z.string().transform(val => val.split(',').map(t => t.trim())),
})
```

## Partial and Required

```typescript
// All fields optional (for PATCH requests)
const UpdateInvoiceSchema = InvoiceSchema.partial()

// Make specific fields required
const RequiredEmailSchema = CustomerSchema.required({ email: true })
```

## Refine — Custom Validation Logic

```typescript
const PasswordSchema = z.string()
  .min(8)
  .refine(val => /[A-Z]/.test(val), { message: 'Must contain uppercase' })
  .refine(val => /[0-9]/.test(val), { message: 'Must contain number' })

const DateRangeSchema = z.object({
  startDate: z.date(),
  endDate: z.date(),
}).refine(data => data.endDate > data.startDate, {
  message: 'End date must be after start date',
  path: ['endDate'],
})
```

## Error Formatting

```typescript
const result = Schema.safeParse(data)
if (!result.success) {
  // Flat field errors (best for forms)
  const fieldErrors = result.error.flatten().fieldErrors
  // { email: ['Invalid email format'], amount: ['Must be positive'] }
  
  // Full error tree
  const formatted = result.error.format()
  
  // Simple message list
  const messages = result.error.errors.map(e => e.message)
}
```

Use `flatten().fieldErrors` in form validation responses — maps directly to per-field error display.
