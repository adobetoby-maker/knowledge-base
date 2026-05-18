# Type-First Development

## The Approach

Define TypeScript types before writing implementation code. Types are a design tool, not an afterthought.

## Why Types First

When you write the type first:
- You think through the data shape before committing to it in code
- Mismatches between what data you have and what the function needs surface immediately
- Other functions that use the same data get consistent shapes
- Refactoring is safer — TypeScript catches all callers when types change

When you write implementation first and add types later:
- You end up with `any` in places where you weren't sure
- Related functions end up with slightly different shapes for the same data
- The types describe what the code happened to do, not what it should do

## Pattern: Type → Function → Tests

```typescript
// Step 1: Define the type (this is design work):
interface Invoice {
  id: string
  invoice_number: string
  customer_id: string
  customer_name: string  // denormalized for display
  status: 'draft' | 'pending' | 'paid' | 'overdue' | 'cancelled'
  line_items: LineItem[]
  subtotal_cents: number
  tax_cents: number
  total_cents: number
  due_date: string
  created_at: string
  paid_at: string | null
}

interface LineItem {
  id: string
  description: string
  quantity: number
  unit_price_cents: number
  total_cents: number
}

// Step 2: Write functions using the types:
function calculateTotal(lineItems: LineItem[]): number {
  return lineItems.reduce((sum, item) => sum + item.total_cents, 0)
}

// Step 3: Write tests:
test('calculateTotal sums line items', () => {
  const items: LineItem[] = [
    { id: '1', description: 'Oil change', quantity: 1, unit_price_cents: 4999, total_cents: 4999 },
    { id: '2', description: 'Filter', quantity: 1, unit_price_cents: 1500, total_cents: 1500 },
  ]
  expect(calculateTotal(items)).toBe(6499)
})
```

## Use Exact Types — Not Loose Ones

```typescript
// LOOSE — allows strings that aren't valid statuses:
type InvoiceStatus = string

// EXACT — TypeScript catches typos and invalid values:
type InvoiceStatus = 'draft' | 'pending' | 'paid' | 'overdue' | 'cancelled'

// LOOSE — allows any object shape:
function processInvoice(invoice: any): void

// EXACT — contract is clear:
function processInvoice(invoice: Invoice): void
```

## Types at System Boundaries

The most important types are at the edges — where data enters or leaves your control:

1. **Database → App**: Generated types from `lib/database.types.ts`. Never write these manually.
2. **API → App**: Validated with Zod, type derived from schema: `type Invoice = z.infer<typeof InvoiceSchema>`
3. **Form → Server Action**: Zod schema validates, TypeScript type flows through
4. **App → Client**: Server Component props are typed; client components receive typed props

```typescript
// Border crossing: API response → app type:
const InvoiceSchema = z.object({
  id: z.string().uuid(),
  status: z.enum(['draft', 'pending', 'paid', 'overdue', 'cancelled']),
  total_cents: z.number().int().nonnegative(),
})
type Invoice = z.infer<typeof InvoiceSchema>

// This ensures: what Zod validates IS the TypeScript type.
// They can't drift apart.
```

## Avoid `any` and `as` Casts

```typescript
// WRONG — silences errors instead of fixing types:
const invoice = data as Invoice
const amount = (event.target as any).value

// CORRECT — fix the type to match reality:
const result = InvoiceSchema.safeParse(data)
if (result.success) {
  const invoice: Invoice = result.data  // no cast needed
}

// CORRECT — use specific event type:
function handleInput(event: React.ChangeEvent<HTMLInputElement>) {
  const value = event.target.value  // typed by React
}
```

## Supabase Generated Types

Run type generation after every schema change — never write DB types manually:

```bash
npx supabase gen types typescript --project-id $SUPABASE_PROJECT_ID > lib/database.types.ts
```

Then use type aliases in `lib/types.ts`:
```typescript
import type { Database } from './database.types'

export type Invoice = Database['public']['Tables']['invoices']['Row']
export type InsertInvoice = Database['public']['Tables']['invoices']['Insert']
export type UpdateInvoice = Database['public']['Tables']['invoices']['Update']
```

These aliases make usage cleaner and isolate components from the raw Supabase type structure.
