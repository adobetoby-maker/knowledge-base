# Failure: Zod Validation Gaps

## The Problem

Zod schemas that look correct but let invalid data through — either because validation is placed too late, schemas are too permissive, or runtime types aren't actually validated.

## Gap 1: Validating After Use

```ts
// WRONG — accessing body before validation
export async function POST(request: NextRequest) {
  const body = await request.json()
  const userId = body.userId  // Used before validation

  const result = schema.safeParse(body)  // Too late
  if (!result.success) return error()
}

// CORRECT — validate first, use parsed output
export async function POST(request: NextRequest) {
  const body = await request.json()
  const result = schema.safeParse(body)
  if (!result.success) {
    return NextResponse.json({ error: result.error.flatten() }, { status: 400 })
  }

  const { userId } = result.data  // Type-safe, validated
}
```

## Gap 2: `z.any()` / `z.unknown()` Holes

```ts
// WRONG — the metadata field is unvalidated
const invoiceSchema = z.object({
  amount: z.number(),
  metadata: z.any(),  // Hole — anything passes
})

// CORRECT — define the expected shape
const invoiceSchema = z.object({
  amount: z.number(),
  metadata: z.object({
    source: z.string().optional(),
    reference: z.string().optional(),
  }).optional(),
})
```

`z.any()` effectively disables validation for that field. Use it only when the field genuinely is unstructured.

## Gap 3: Missing `.min()` / `.max()` Bounds

```ts
// WRONG — accepts empty string, 10MB string, -1, Infinity
const schema = z.object({
  name: z.string(),
  amount: z.number(),
  items: z.array(z.string()),
})

// CORRECT — bound everything
const schema = z.object({
  name: z.string().min(1).max(100),
  amount: z.number().positive().max(999_999_99),  // Max $999,999.99 in cents
  items: z.array(z.string().max(200)).min(1).max(50),
})
```

Without bounds, valid Zod schemas accept: empty strings, negative amounts, arrays with 10,000 items. Always set min/max for user-facing inputs.

## Gap 4: `JSON.parse` Without Validation

```ts
// WRONG — JSON.parse returns `any`
const data = JSON.parse(body)
doSomethingWith(data.invoiceId)  // Could be undefined, null, or injected

// CORRECT — parse + validate
const parsed = z.object({
  invoiceId: z.string().uuid(),
}).safeParse(JSON.parse(body))
```

TypeScript's type system doesn't help after `JSON.parse`. Validate everything from external sources.

## Gap 5: Partial Schemas for Partial Updates

```ts
// WRONG — partial() makes every field optional including ones that shouldn't be
const updateSchema = invoiceSchema.partial()  // type, status, amount all become optional
await supabase.from('invoices').update(result.data).eq('id', id)

// CORRECT — pick only the fields that are actually updatable
const updateInvoiceSchema = z.object({
  description: z.string().min(1).max(500).optional(),
  due_date: z.string().datetime().optional(),
  // NOT: status, user_id, total_cents — controlled by server
})
```

`partial()` on a full schema creates a schema where every field is optional — fine for type coverage, wrong as a security boundary. Users shouldn't be able to update `user_id` or `status` directly.

## Gap 6: Transform Hiding Validation Errors

```ts
// WRONG — transform runs before you can check errors; throw is swallowed
const schema = z.string().transform((s) => {
  const n = parseInt(s)
  if (isNaN(n)) throw new Error('Not a number')
  return n
})

// CORRECT — validate then transform
const schema = z.string()
  .regex(/^\d+$/, 'Must be a number')  // Validate first
  .transform((s) => parseInt(s, 10))   // Then transform
```

## Gap 7: Missing `.strict()` on Object Schemas

```ts
// WRONG — accepts extra fields silently (they're stripped, but no error)
const schema = z.object({ name: z.string() })
schema.parse({ name: 'Alice', role: 'admin' })  // Succeeds — role is stripped

// CORRECT (for strict APIs — rejects extra fields)
const schema = z.object({ name: z.string() }).strict()
schema.parse({ name: 'Alice', role: 'admin' })  // ZodError: unrecognized key 'role'
```

`.strict()` prevents parameter pollution. Use for admin endpoints and internal API contracts. Default `.passthrough()` behavior strips extras silently — fine for public APIs where clients may send extra fields.

## Gap 8: Not Propagating Validation Errors to Client

```ts
// WRONG — client doesn't know what's wrong
if (!result.success) {
  return NextResponse.json({ error: 'Invalid input' }, { status: 400 })
}

// CORRECT — expose field-level errors
if (!result.success) {
  return NextResponse.json(
    { errors: result.error.flatten().fieldErrors },
    { status: 400 }
  )
}
// Response: { errors: { email: ['Invalid email address'], name: ['Required'] } }
```

`result.error.flatten()` returns `{ formErrors, fieldErrors }` — field errors are keyed by field name and easy to display inline.

## Validation Schema Placement

- One schema file per domain entity: `lib/schemas/invoice.ts`
- Export `createInvoiceSchema`, `updateInvoiceSchema`, `invoiceIdSchema` separately
- Import schema in Route Handler, Server Action, and Edge Function
- Reuse the same schema for client-side validation (React Hook Form `zodResolver`)
