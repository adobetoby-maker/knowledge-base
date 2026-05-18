# Stack Bundle: JRS Invoice System Context

> Pre-merged context for local models or agents working on the invoice system in jrs-auto-repair.
> Load this file instead of reading 5+ separate files.

## Project Overview

jrs-auto-repair at `/Users/drive/jrs-auto-repair`. Next.js 16 + Supabase.
Invoice system serves Pablo (admin) and his customers (portal).

## Invoice Types

```typescript
// lib/types.ts (representative — always read actual file for exact types)
export interface Invoice {
  id: string
  number: string              // e.g., "INV-2026-001"
  status: 'pending' | 'paid' | 'overdue'
  total: number               // in dollars, 2 decimal places
  customer_id: string
  customer_name: string
  line_items: LineItem[]
  created_at: string          // ISO 8601
  due_date: string            // ISO 8601
  paid_at?: string            // ISO 8601, null if not paid
  notes?: string
}

export interface LineItem {
  description: string
  quantity: number
  unit_price: number
  amount: number              // quantity × unit_price
}
```

## Database Schema

```sql
-- invoices table
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
number TEXT NOT NULL UNIQUE
status TEXT NOT NULL DEFAULT 'pending'
  CONSTRAINT status_check CHECK (status IN ('pending', 'paid', 'overdue'))
total NUMERIC(10, 2) NOT NULL
customer_id UUID REFERENCES customers(id)
customer_name TEXT NOT NULL  -- denormalized for display
line_items JSONB NOT NULL DEFAULT '[]'
created_at TIMESTAMPTZ DEFAULT now()
due_date DATE
paid_at TIMESTAMPTZ
notes TEXT
```

## RLS Policies

```sql
-- Admin full access (uses service role — no policy needed)

-- Portal users: can only see their own invoices
CREATE POLICY "Customers see own invoices"
ON invoices FOR SELECT
TO authenticated
USING (customer_id = auth.uid());
```

## Route Structure

```
app/
  (portal)/
    invoices/
      page.tsx          → Customer invoice list (Supabase JWT auth)
      [id]/
        page.tsx        → Customer invoice detail + PDF download
  admin/
    invoices/
      page.tsx          → Admin invoice list (cookie auth)
      [id]/
        page.tsx        → Admin invoice detail + edit + mark paid
      new/
        page.tsx        → Create new invoice
api/
  admin/
    invoices/
      route.ts          → GET (list), POST (create) — cookie auth
    invoices/[id]/
      route.ts          → GET, PUT (update), PATCH (mark paid) — cookie auth
    export/
      invoices/
        route.ts        → GET CSV export — cookie auth
  portal/
    invoices/
      route.ts          → GET (customer's own invoices only) — Supabase JWT
```

## Auth Pattern

Admin routes (`/admin/invoices`, `/api/admin/invoices`):
```typescript
import { validateAdminSession } from '@/lib/adminAuth'
const isAdmin = await validateAdminSession(req)
if (!isAdmin) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
// Use createAdminClient() for data access
```

Portal routes (`/portal/invoices`, `/api/portal/invoices`):
```typescript
import { createClient } from '@/lib/supabase/server'
const supabase = createClient()
const { data: { user } } = await supabase.auth.getUser()  // NOT getSession()
if (!user) redirect('/login')
// RLS handles row filtering automatically
```

## Supabase Client Selection

| Route | Client | Why |
|---|---|---|
| Admin route handler | `createAdminClient()` | Bypasses RLS, sees all invoices |
| Portal server component | `createClient()` from server.ts | RLS limits to customer's invoices |
| Portal client component | `createClient()` from client.ts | Browser-side queries |

## Invoice Calculation

```typescript
// lib/invoices/calculate.ts
export function calculateLineItemAmount(quantity: number, unitPrice: number): number {
  return Math.round(quantity * unitPrice * 100) / 100  // round to 2 decimal places
}

export function calculateInvoiceTotal(lineItems: LineItem[]): number {
  return Math.round(
    lineItems.reduce((sum, item) => sum + item.amount, 0) * 100
  ) / 100
}
```

## Invoice Number Generation

```typescript
// lib/invoices/numbering.ts
export async function generateInvoiceNumber(supabase: SupabaseClient): Promise<string> {
  const year = new Date().getFullYear()
  const { count } = await supabase
    .from('invoices')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', `${year}-01-01`)
  const sequence = String((count ?? 0) + 1).padStart(3, '0')
  return `INV-${year}-${sequence}`
}
```

## PDF Generation

Invoice PDFs use `@react-pdf/renderer`. Must have `export const runtime = 'nodejs'` in the route handler (not compatible with Edge runtime).

## Critical Rules

1. Admin routes use cookie auth, NEVER Supabase JWT
2. Portal routes use Supabase `getUser()`, NEVER cookie auth
3. Admin client bypasses ALL RLS — only use in server-side admin routes
4. Invoice total = sum of line item amounts (don't trust a client-submitted total)
5. Mark invoices paid via PATCH, not DELETE+INSERT
