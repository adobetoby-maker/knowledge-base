# Separation of Concerns

## What It Means

Each file, function, and module should have ONE clear responsibility. When something changes, ideally only one thing needs to update.

Signs of mixed concerns: a component that fetches data AND renders AND handles business logic. A function that validates AND persists AND sends notifications.

## The Layers in a Next.js App

**Layer 1 — Data Access** (`lib/supabase/`, `lib/db/`)
Database queries and external API calls. No business logic. No UI.

**Layer 2 — Business Logic** (`lib/`, `app/actions/`)
Calculations, validations, transformations. No UI. No raw SQL.

**Layer 3 — Routing/API** (`app/api/`, `app/actions/`)
Request parsing, auth, calling business logic, returning responses. No business logic inline.

**Layer 4 — Presentation** (`app/`, `components/`)
Rendering. Calls business logic via actions or APIs. No SQL.

## Practical Example: Invoice Creation

**Violation — everything in one route handler:**
```typescript
// app/api/invoices/route.ts — MIXED CONCERNS
export async function POST(req: NextRequest) {
  const body = await req.json()
  
  // Business logic in route handler
  const subtotal = body.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const tax = subtotal * 0.0875
  const total = subtotal + tax
  
  // Direct SQL in route handler
  const { data } = await supabase.from('invoices').insert({
    ...body,
    subtotal,
    tax,
    total,
    status: 'pending',
  })
  
  // Email notification in route handler
  await sendEmail({ to: body.customer_email, subject: 'Invoice created', ... })
  
  return NextResponse.json(data)
}
```

**Correct — separated:**
```typescript
// lib/invoice-calculations.ts — business logic only
export function calculateInvoiceTotals(items: LineItem[]): InvoiceTotals {
  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const tax = subtotal * TAX_RATE
  return { subtotal, tax, total: subtotal + tax }
}

// lib/invoice-db.ts — data access only
export async function insertInvoice(invoice: NewInvoice) {
  return supabase.from('invoices').insert(invoice).select().single()
}

// app/actions/invoices.ts — orchestration
'use server'
export async function createInvoice(data: CreateInvoiceInput) {
  const totals = calculateInvoiceTotals(data.items)
  const { data: invoice } = await insertInvoice({ ...data, ...totals, status: 'pending' })
  await sendInvoiceEmail(invoice)
  revalidatePath('/portal/invoices')
  return invoice
}
```

Now if the tax rate changes → only `invoice-calculations.ts` changes.
If the email template changes → only the email function changes.

## Component Separation

```typescript
// MIXED — one component fetches, calculates, AND renders
export default async function InvoiceSummary({ userId }: { userId: string }) {
  const { data: invoices } = await supabase.from('invoices').select('*').eq('user_id', userId)
  const total = invoices?.reduce((sum, inv) => sum + inv.total, 0) ?? 0
  const overdue = invoices?.filter(inv => inv.status === 'overdue').length ?? 0
  
  return <div>{total} | {overdue} overdue</div>
}

// SEPARATED
// lib/invoice-stats.ts — calculation
export function calculateInvoiceStats(invoices: Invoice[]) {
  return {
    total: invoices.reduce((sum, inv) => sum + inv.total, 0),
    overdueCount: invoices.filter(inv => inv.status === 'overdue').length,
  }
}

// app/portal/components/invoice-stats.tsx — rendering
export function InvoiceStats({ stats }: { stats: ReturnType<typeof calculateInvoiceStats> }) {
  return <div>{stats.total} | {stats.overdueCount} overdue</div>
}

// page.tsx — data fetching
export default async function Page({ params }) {
  const invoices = await fetchUserInvoices(userId)
  const stats = calculateInvoiceStats(invoices)
  return <InvoiceStats stats={stats} />
}
```

## Content Files

In this workspace, content (articles, how-tos, services, shop info) lives in TypeScript arrays in `lib/`, NOT in database tables or markdown files. This is a deliberate content-from-code pattern:
- `lib/articles.ts` — blog articles
- `lib/howtos.ts` — how-to guides  
- `lib/shopInfo.ts` — business info (single source of truth)

The concern of "what is the content" is separated from "how it's rendered" (React components) and "how it's routed" (Next.js pages).

## The Test for Good Separation

"If I need to change X, which files do I touch?" 

If the answer is more than 2-3 files, the concern is probably spread too thin. If the answer is 1 focused file, separation is working.
