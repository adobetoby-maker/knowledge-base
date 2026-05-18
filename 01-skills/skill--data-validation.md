# Data Validation

## Why Validate

TypeScript types are erased at runtime. A Route Handler that receives `{ total: "abc" }` won't have a TypeScript error during compilation — but parsing `"abc"` as a number will produce `NaN`. Validation at the boundary prevents corrupt data from reaching business logic or the database.

## Zod for Runtime Validation

```bash
# Already in most project packages.json — check before installing
npm install zod
```

## Validation at Route Handler Boundary

```typescript
// app/api/admin/invoices/route.ts
import { z } from 'zod'

const CreateInvoiceSchema = z.object({
  customer_id: z.string().uuid('Must be a valid customer ID'),
  number: z.string().min(1).max(50),
  line_items: z.array(z.object({
    description: z.string().min(1).max(500),
    quantity: z.number().int().positive().max(1000),
    unit_price: z.number().nonnegative().max(100000),
    amount: z.number().nonnegative(),
  })).min(1, 'At least one line item is required'),
  due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD format').optional(),
  notes: z.string().max(2000).optional(),
})

export async function POST(req: NextRequest) {
  const body = await req.json()
  const result = CreateInvoiceSchema.safeParse(body)
  
  if (!result.success) {
    return NextResponse.json(
      { error: result.error.issues },  // detailed error for debugging
      { status: 400 }
    )
  }
  
  const { customer_id, number, line_items, due_date, notes } = result.data
  // Use validated, typed data
}
```

## Coercion for Number and Boolean URL Params

URL search params are always strings. Coerce them:

```typescript
const SearchSchema = z.object({
  page: z.coerce.number().int().positive().default(1),  // '3' → 3
  limit: z.coerce.number().int().min(1).max(100).default(20),
  status: z.enum(['pending', 'paid', 'overdue', 'all']).default('all'),
  active: z.coerce.boolean().default(true),  // 'true' → true
})

const params = SearchSchema.parse({
  page: searchParams.get('page'),
  limit: searchParams.get('limit'),
  status: searchParams.get('status'),
  active: searchParams.get('active'),
})
```

`z.coerce.number()` converts `'3'` to `3`. Without coercion, `z.number()` would reject URL params.

## Validating External API Responses

Never trust external API responses — validate them:
```typescript
const StripeCustomerSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  metadata: z.record(z.string()).optional(),
})

const customer = await stripe.customers.retrieve(customerId)
const validated = StripeCustomerSchema.safeParse(customer)

if (!validated.success) {
  console.error('Unexpected Stripe customer shape:', validated.error)
  throw new Error('Invalid customer data')
}
```

## Partial Validation for Updates

For PATCH endpoints that accept partial updates:
```typescript
const InvoiceSchema = z.object({
  status: z.enum(['pending', 'paid', 'overdue']),
  notes: z.string().max(2000),
  due_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
})

// Partial version for PATCH:
const UpdateInvoiceSchema = InvoiceSchema.partial()  // all fields optional
type UpdateInvoice = z.infer<typeof UpdateInvoiceSchema>
// { status?: 'pending' | 'paid' | 'overdue'; notes?: string; due_date?: string }
```

## Form Validation with Zod + React Hook Form

```typescript
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  phone: z.string()
    .regex(/^\+?[\d\s-()]{10,}$/, 'Invalid phone number')
    .optional()
    .or(z.literal('')),
})

type FormValues = z.infer<typeof schema>

export function ContactForm() {
  const form = useForm<FormValues>({ resolver: zodResolver(schema) })
  // Validation runs on submit and shows errors from Zod
}
```

## Validation Rules

1. Validate at EVERY entry point (Route Handler, Server Action, webhook)
2. Use `safeParse` not `parse` — catch errors gracefully instead of throwing
3. Include error messages in Zod schema for user-facing validation
4. Validate on both client AND server — client validation is UX, server validation is security
5. Never validate on the client only — the client can be bypassed

## What NOT to Validate

Don't write defensive validation for impossible cases:
- TypeScript-guaranteed non-null values within a function
- Database query results that can only be valid types
- Framework-injected data (Next.js `params`, `searchParams`)

Validate at boundaries (incoming HTTP, external APIs, user input). Trust internal code.
