# Stack Bundle: Invoice System Context (jrs-auto-repair)

Load this before working on invoice creation, editing, viewing, or payment-related features in jrs-auto-repair.

## Database Schema

```sql
CREATE TABLE customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text,
  phone text,
  address text,
  notes text,
  created_at timestamptz DEFAULT now(),
  deleted_at timestamptz  -- soft delete
);

CREATE TABLE invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number text UNIQUE NOT NULL,                    -- e.g., "INV-0042"
  customer_id uuid REFERENCES customers(id),
  status text NOT NULL DEFAULT 'draft',           -- draft | sent | paid | overdue
  total_cents integer NOT NULL DEFAULT 0,
  notes text,
  due_date date,
  public_token text UNIQUE DEFAULT gen_random_uuid()::text,  -- for unauthenticated viewing
  sent_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE invoice_line_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  description text NOT NULL,
  quantity numeric(10,2) NOT NULL DEFAULT 1,
  unit_price_cents integer NOT NULL,
  sort_order integer DEFAULT 0
);
```

## Status Flow

```
draft → sent → paid
            ↓
          overdue (auto when due_date passes and status = 'sent')
```

- `draft` → user is still building the invoice
- `sent` → email sent to customer, awaiting payment
- `paid` → payment received, `paid_at` set
- `overdue` → `due_date` has passed with status = `sent`

Never manually set overdue — it's computed. Either set it via cron or compute it on read:
```typescript
function resolveStatus(invoice: Invoice): InvoiceStatus {
  if (invoice.status === 'sent' && invoice.due_date && new Date(invoice.due_date) < new Date()) {
    return 'overdue'
  }
  return invoice.status as InvoiceStatus
}
```

## Invoice Numbering

Sequential padded numbers: `INV-0001`, `INV-0042`, etc.

```typescript
async function getNextInvoiceNumber(): Promise<string> {
  const { data } = await supabase
    .from('invoices')
    .select('number')
    .order('created_at', { ascending: false })
    .limit(1)
    .single()
  
  const lastNum = data?.number ? parseInt(data.number.replace('INV-', '')) : 0
  return `INV-${String(lastNum + 1).padStart(4, '0')}`
}
```

## Total Calculation

```typescript
// lib/invoices/calculate.ts
export function calculateInvoiceTotal(lineItems: LineItem[]): number {
  return lineItems.reduce((sum, item) => {
    return sum + Math.round(item.unitPriceCents * item.quantity)
  }, 0)
}
```

Total is always recomputed from line items — never stored as a derived field without syncing.

## Public Invoice View

Customers can view invoices without logging in via `public_token`:

```
/invoice/[publicToken]
```

This route uses NO auth. It only shows data for that specific invoice — no customer list, no other invoices.

## Server Action Pattern

```typescript
// lib/actions/invoices.ts
'use server'
import { validateAdminSession } from '@/lib/adminAuth'
import { supabaseServer } from '@/lib/supabase/server'
import { revalidatePath } from 'next/cache'

export async function createInvoice(formData: FormData): Promise<ActionResult<Invoice>> {
  await validateAdminSession()  // admin-only action
  
  const parsed = CreateInvoiceSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { success: false, error: 'Validation failed', details: parsed.error.flatten() }
  
  const supabase = supabaseServer()
  const number = await getNextInvoiceNumber()
  
  const { data, error } = await supabase
    .from('invoices')
    .insert({ ...parsed.data, number, total_cents: calculateInvoiceTotal(parsed.data.lineItems) })
    .select()
    .single()
  
  if (error) return { success: false, error: 'Failed to create invoice' }
  
  revalidatePath('/admin/invoices')
  return { success: true, data }
}
```

## Money Display

```typescript
function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(cents / 100)
}

// $12.99, $1,234.00, etc.
```
