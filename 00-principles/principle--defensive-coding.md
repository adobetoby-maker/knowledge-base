# Defensive Coding

## The Principle

Trust your own code; be suspicious of everything outside it. The boundary between your system and external inputs (user data, API responses, database reads, URL params) is where defensive code belongs. Internal code that you wrote and tested doesn't need guards.

## At System Boundaries

```typescript
// External input: parse and validate
function handleWebhookPayload(body: unknown) {
  const result = WebhookPayloadSchema.safeParse(body)
  if (!result.success) {
    console.error('Invalid webhook payload:', result.error)
    return { error: 'Invalid payload' }
  }
  return processWebhook(result.data)  // safe to use inside
}

// User input via form: validate before using
const CreateInvoiceSchema = z.object({
  customerId: z.string().uuid(),
  totalCents: z.number().int().positive().max(99_999_999),  // max $999,999.99
})

export async function createInvoice(rawData: unknown) {
  const data = CreateInvoiceSchema.parse(rawData)  // throws on invalid
  // safe to use data inside now
}

// API response: don't assume shape
const response = await fetch('/api/rates')
const json = await response.json()
const rate = RateSchema.parse(json)  // validate external API response
```

## Don't Defend Against Yourself

Defensive code has cost: it's verbose and obscures intent. Don't add guards for things that can't happen:

```typescript
// BAD — excessive guards for internal code:
function processInvoice(invoice: Invoice) {
  if (!invoice) throw new Error('Invoice required')  // TypeScript already prevents null
  if (typeof invoice.id !== 'string') throw new Error('Invalid id')  // type is enforced
  if (!Array.isArray(invoice.lineItems)) throw new Error('Invalid line items')
  
  // ... actual logic
}

// GOOD — trust TypeScript types for internal code:
function processInvoice(invoice: Invoice) {
  const total = invoice.lineItems.reduce((sum, item) => sum + item.totalCents, 0)
  return { ...invoice, totalCents: total }
}
```

If TypeScript says it's an `Invoice`, it's an `Invoice`.

## Null Coalescing Strategy

Be explicit about null handling at the boundary, loose internally:

```typescript
// At boundary (Supabase response):
const { data: customer, error } = await supabase.from('customers').select('*').eq('id', id).single()
if (error || !customer) return notFound()

// Inside (customer is Customer, not null):
const name = customer.name  // no null check needed
const email = customer.email  // no null check needed
```

## Number Safety

Integer overflow and floating-point imprecision are silent bugs:

```typescript
// Store money as cents (integer):
const totalCents = 1299  // $12.99

// Don't do math on floats:
const tax = 1299 * 0.08  // 103.92 — looks fine
const rounded = Math.round(1299 * 0.08)  // 104 — safe

// Addition is safe with integers:
const total = lineCents + taxCents  // no float issues
```

## Array and Map Access

Accessing missing keys is a silent `undefined` in JS — easy source of "cannot read property of undefined":

```typescript
// BAD — silently undefined if key doesn't exist:
const status = STATUS_MAP[invoice.status].label

// GOOD — explicit check:
const statusConfig = STATUS_MAP[invoice.status]
if (!statusConfig) throw new Error(`Unknown status: ${invoice.status}`)
const label = statusConfig.label

// OR — with default:
const label = STATUS_MAP[invoice.status]?.label ?? 'Unknown'
```

## Async Error Propagation

Don't let async errors become unhandled promise rejections:

```typescript
// BAD — unhandled rejection crashes the process:
fetchData()  // returns Promise, no .catch()

// GOOD — explicit handling:
fetchData().catch(e => console.error('fetchData failed:', e))

// OR — in async context:
try {
  const data = await fetchData()
} catch (e) {
  console.error('fetchData failed:', e)
  return fallbackValue
}
```
