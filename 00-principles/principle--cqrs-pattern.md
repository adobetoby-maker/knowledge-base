# Principle: CQRS Pattern

## What It Is

Command Query Responsibility Segregation: separate the code paths for writing data (commands) from reading data (queries). Commands change state, return no data. Queries read state, change nothing.

Not an architecture — a design discipline applied at the function/route level. You don't need Kafka or event sourcing to benefit from it.

## Why It Matters

Reads and writes have fundamentally different requirements:
- **Reads** are frequent, must be fast, often need denormalized/joined data, tolerate slight staleness
- **Writes** are less frequent, must be correct, validate business rules, trigger side effects

Mixing them leads to: read performance constrained by write-safe locking, write logic polluted by projection logic, tests that can't verify reads and writes independently.

## Applied to Route Handlers

```ts
// WRONG — command that also returns data
export async function POST(req: Request) {
  const data = await req.json()
  const { data: created } = await supabase
    .from('orders')
    .insert(data)
    .select('*, items(*), customer(*)')  // loading related data in the write path
    .single()

  return Response.json(created)
}

// CORRECT — command returns minimal data; caller re-fetches
export async function POST(req: Request) {
  const data = await req.json()
  const { data: order, error } = await supabase
    .from('orders')
    .insert(data)
    .select('id')
    .single()

  if (error) return Response.json({ error: error.message }, { status: 400 })
  return Response.json({ id: order.id }, { status: 201 })
}

// Separate query endpoint
export async function GET(req: Request, { params }: { params: { id: string } }) {
  const { data } = await supabase
    .from('orders')
    .select('*, items(*), customer(*)')
    .eq('id', params.id)
    .single()

  return Response.json(data)
}
```

## Commands Are Void

Commands should return only success/failure and the ID of the created/affected resource. Returning full data from a command:
- Forces the write path to do read work (joins, formatting)
- Couples the response shape to the write model
- Makes it impossible to add caching to the read path independently

```ts
// Command
async function createInvoice(data: NewInvoice): Promise<{ id: string }> {
  const { data: row } = await supabase.from('invoices').insert(data).select('id').single()
  return { id: row.id }
}

// Query (separate, can be cached with React cache() or unstable_cache)
async function getInvoice(id: string): Promise<Invoice> {
  const { data } = await supabase.from('invoices').select('*, line_items(*)').eq('id', id).single()
  return data
}
```

## Server Actions Follow the Same Rule

```ts
'use server'

// Command — revalidate and return minimal result
export async function publishPost(postId: string) {
  await supabase.from('posts').update({ published: true }).eq('id', postId)
  revalidatePath(`/posts/${postId}`)
  // Return void or { success: true } — not the full post
}

// Query — separate function, can use React cache()
import { cache } from 'react'
export const getPost = cache(async (id: string) => {
  const { data } = await supabase.from('posts').select('*').eq('id', id).single()
  return data
})
```

## When to Break the Rule

Returning the created resource from a POST is acceptable when:
- The resource has server-generated fields the client needs immediately (tokens, presigned URLs)
- A round-trip would be a noticeable UX problem
- The data shape is simple (no joins required)

Example: creating a Stripe payment intent — return `{ clientSecret }` directly because there's no other way to get it.

## Read Models vs Write Models

In more complex systems, the read model (what you return to clients) diverges from the write model (database row). The read model is denormalized, formatted, and shaped for the UI. Build this separation explicitly:

```ts
type InvoiceRow = Database['public']['Tables']['invoices']['Row']

// Read model — shaped for display
type InvoiceView = {
  id: string
  number: string
  totalFormatted: string  // "$1,234.56"
  statusLabel: string     // "Past Due"
  customer: { name: string; email: string }
  lineItems: LineItemView[]
}

function toInvoiceView(row: InvoiceRow & { customer: CustomerRow; line_items: LineItemRow[] }): InvoiceView {
  return {
    id: row.id,
    number: `INV-${row.number.toString().padStart(5, '0')}`,
    totalFormatted: formatCents(row.total_cents),
    statusLabel: STATUS_LABELS[row.status],
    customer: { name: row.customer.name, email: row.customer.email },
    lineItems: row.line_items.map(toLineItemView),
  }
}
```

This mapping function is pure — easy to test, easy to change without touching the database schema.
