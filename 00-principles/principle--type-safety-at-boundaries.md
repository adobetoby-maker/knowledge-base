# Type Safety at Boundaries

## The Core Principle

TypeScript's type system trusts you at internal function boundaries — if you say it's a `string`, TS believes you. But at system boundaries (API inputs, database outputs, user forms, external services), TypeScript can't know what you'll actually receive at runtime.

Type safety at boundaries means: validate every external input, trust nothing from outside your code.

## What Counts as a Boundary

- **HTTP request bodies** — user-supplied JSON
- **URL parameters** — string in URL, needs coercion
- **Form data** — always strings, need validation
- **Database query results** — could have nulls, missing fields
- **External API responses** — format may change without notice
- **localStorage/cookies** — user-controlled, can be anything
- **env vars** — could be missing

## Zod at Every Boundary

```typescript
import { z } from 'zod'

const createInvoiceSchema = z.object({
  customer_name: z.string().min(1, 'Customer name is required').max(100),
  amount: z.coerce.number().positive('Amount must be positive'),
  due_date: z.string().datetime().optional(),
  line_items: z.array(z.object({
    description: z.string().min(1),
    quantity: z.coerce.number().int().positive(),
    unit_price: z.coerce.number().positive(),
  })).min(1, 'At least one line item is required'),
})

type CreateInvoiceInput = z.infer<typeof createInvoiceSchema>  // derived from schema

// Route Handler — validate at HTTP boundary
export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null)
  const result = createInvoiceSchema.safeParse(body)
  
  if (!result.success) {
    return NextResponse.json(
      { error: 'Invalid input', fields: result.error.flatten().fieldErrors },
      { status: 422 }
    )
  }
  
  // result.data is now fully typed as CreateInvoiceInput
  await createInvoice(result.data)
}
```

## TypeScript is Not Enough

TypeScript types are erased at runtime. A type assertion `as Invoice` doesn't validate the data:

```typescript
// WRONG — just tells TypeScript to trust you, doesn't validate at runtime
const invoice = await res.json() as Invoice

// If the API changes and returns { total_amount: 150 } instead of { total: 150 }
// TypeScript says "fine", but invoice.total will be undefined at runtime

// CORRECT — validate the shape
const invoiceSchema = z.object({
  id: z.string(),
  total: z.number(),
  status: z.enum(['pending', 'paid', 'overdue']),
})

const result = invoiceSchema.safeParse(await res.json())
if (!result.success) throw new Error('Unexpected API response shape')
const invoice = result.data  // now actually typed AND validated
```

## Database Types

Supabase generates TypeScript types from your schema, but query results can still have unexpected shapes:

```typescript
// Supabase generated type (from supabase gen types)
export type Database = {
  public: {
    Tables: {
      invoices: { Row: Invoice; Insert: InvoiceInsert; Update: InvoiceUpdate }
    }
  }
}

// Query result is typed, but nullability is automatic
const { data: invoice } = await supabase.from('invoices').select('*').single()
// invoice is typed as Invoice | null — handle the null case!

if (!invoice) return notFound()
// Now invoice is Invoice (narrowed by if check)
```

## URL Search Params

URL params are always strings. Parse explicitly:

```typescript
// BAD — implicit undefined handling
const page = searchParams.page  // might be undefined or string

// GOOD — explicit parse
const pageParam = req.nextUrl.searchParams.get('page')
const page = pageParam ? Math.max(1, parseInt(pageParam, 10)) : 1
// page is guaranteed to be a valid positive integer
```

## Environment Variable Validation

```typescript
// lib/env.ts — validate all env vars at startup
import { z } from 'zod'

const envSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  ANTHROPIC_API_KEY: z.string().startsWith('sk-ant-'),
  ADMIN_SECRET: z.string().min(32),
})

// Throws at startup if any var is missing or wrong format
export const env = envSchema.parse(process.env)
```

## External API Responses

```typescript
const stripeCustomerSchema = z.object({
  id: z.string(),
  email: z.string().email().nullable(),
  metadata: z.record(z.string()),
})

async function getStripeCustomer(customerId: string) {
  const customer = await stripe.customers.retrieve(customerId)
  const result = stripeCustomerSchema.safeParse(customer)
  if (!result.success) {
    console.error('Stripe customer shape unexpected:', result.error)
    throw new Error('Unexpected Stripe response')
  }
  return result.data
}
```

This is especially important for external APIs that can change their response shape without breaking your TypeScript (TypeScript won't know — the types are from their SDK, not validated).
