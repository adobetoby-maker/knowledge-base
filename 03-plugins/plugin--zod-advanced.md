# Zod Advanced Patterns

## Beyond Basic Schemas

### Discriminated Unions

```typescript
const LineItemSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('service'),
    serviceCode: z.string(),
    hours: z.number().positive(),
    rate: z.number().positive(),
  }),
  z.object({
    type: z.literal('part'),
    partNumber: z.string(),
    quantity: z.number().int().positive(),
    unitCost: z.number().positive(),
  }),
])
// TypeScript narrows the type based on 'type' field
```

### Refinements (Custom Validation)

```typescript
const InvoiceSchema = z.object({
  subtotal: z.number().nonnegative(),
  discount: z.number().nonnegative(),
  total: z.number().nonnegative(),
}).refine(
  (data) => data.total === data.subtotal - data.discount,
  {
    message: 'Total must equal subtotal minus discount',
    path: ['total'],  // which field to attach the error to
  }
)
```

### Transforms

Transform data during parsing:
```typescript
const SlugSchema = z.string()
  .min(1)
  .max(200)
  .transform(s => s.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, ''))

// Input: "Hello World!"
// Output: "hello-world"
```

### Preprocessing

Handle type coercion before validation:
```typescript
const NumberFromString = z.preprocess(
  (val) => typeof val === 'string' ? parseFloat(val) : val,
  z.number()
)

// Handles both '42.5' (string) and 42.5 (number) → 42.5
```

### Optional vs Nullable vs Nullish

```typescript
z.string().optional()    // string | undefined
z.string().nullable()    // string | null
z.string().nullish()     // string | null | undefined

// For form fields that might be empty string:
z.string().optional().or(z.literal(''))  // string | undefined | ''
```

## Schema Composition

### Extending Schemas

```typescript
const BaseEntitySchema = z.object({
  id: z.string().uuid(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
})

const InvoiceSchema = BaseEntitySchema.extend({
  number: z.string(),
  total: z.number(),
  status: z.enum(['pending', 'paid', 'overdue']),
})
```

### Merging Schemas

```typescript
const CreateInvoiceSchema = z.object({
  number: z.string(),
  total: z.number(),
})

const UpdateInvoiceSchema = CreateInvoiceSchema.partial()
// { number?: string; total?: number }
```

### Omitting Fields

```typescript
const PublicInvoiceSchema = InvoiceSchema.omit({
  customer_id: true,  // don't expose internal ID in public endpoint
  internal_notes: true,
})
```

### Picking Fields

```typescript
const InvoiceSummarySchema = InvoiceSchema.pick({
  id: true,
  number: true,
  status: true,
  total: true,
})
```

## Parsing URL Search Params

Always use `z.coerce` for URL params (they're always strings):
```typescript
const FilterSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  status: z.enum(['pending', 'paid', 'overdue', 'all']).default('all'),
  q: z.string().optional(),
})

function parseFilters(searchParams: URLSearchParams) {
  return FilterSchema.parse({
    page: searchParams.get('page'),
    limit: searchParams.get('limit'),
    status: searchParams.get('status'),
    q: searchParams.get('q'),
  })
}
```

## Error Formatting

For user-facing validation errors, format them clearly:
```typescript
function formatZodError(error: ZodError): Record<string, string> {
  return error.issues.reduce((acc, issue) => {
    const path = issue.path.join('.')
    acc[path] = issue.message
    return acc
  }, {} as Record<string, string>)
}

// Usage in Route Handler:
if (!result.success) {
  return NextResponse.json(
    { errors: formatZodError(result.error) },
    { status: 400 }
  )
}
// Response: { errors: { 'total': 'Required', 'line_items': 'At least 1 required' } }
```

## generateObject with Zod

When using the Vercel AI SDK to get structured AI output:
```typescript
import { generateObject } from 'ai'
import { z } from 'zod'

const { object } = await generateObject({
  model: openai('gpt-4o'),
  schema: z.object({
    articles: z.array(z.object({
      title: z.string().describe('SEO-optimized article title'),
      slug: z.string().describe('URL-safe slug'),
      excerpt: z.string().max(160).describe('Meta description'),
    })).length(5),
  }),
  prompt: 'Generate 5 article ideas about Twin Falls auto repair',
})
// object is typed: { articles: Array<{ title, slug, excerpt }> }
```

The schema serves as both runtime validation AND TypeScript type for the output.
