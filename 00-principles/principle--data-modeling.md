# Data Modeling

## Core Rules

1. Money is stored in cents (integer), never floats
2. Timestamps are UTC (`timestamptz` in Postgres, ISO 8601 in JS)
3. Enum-like columns use `text` with a CHECK constraint (not Postgres ENUM type)
4. Foreign keys have explicit indexes (not automatic in Postgres)
5. Soft deletes with `deleted_at timestamptz` instead of actual DELETE

## Money as Cents

```sql
-- CORRECT: integer cents
total_cents integer NOT NULL CHECK (total_cents >= 0)

-- WRONG: floating point
total_amount decimal(10,2)  -- floating point math introduces errors
total_amount float           -- even worse
```

In TypeScript, always suffix with `_cents` to make the unit explicit:
```typescript
interface Invoice {
  total_cents: number    // 4999 = $49.99
  tax_cents: number
  subtotal_cents: number
}

// Display:
const displayPrice = (cents: number) => `$${(cents / 100).toFixed(2)}`
```

Never `price * 1.08` for tax — multiply integers: `Math.round(price_cents * 0.08)`.

## Timestamps

```sql
-- All timestamps are UTC (timestamptz in Postgres):
created_at timestamptz NOT NULL DEFAULT now()
updated_at timestamptz NOT NULL DEFAULT now()
paid_at timestamptz  -- nullable: null means not paid
deleted_at timestamptz  -- nullable: null means not deleted
```

In TypeScript, timestamps arrive as ISO 8601 strings from Supabase:
```typescript
// Parse only when displaying:
const date = new Date(invoice.created_at)
const display = date.toLocaleDateString('en-US', { timeZone: 'America/Boise' })

// Never store Date objects — always serialize to ISO string for DB
const now = new Date().toISOString()  // "2026-05-18T14:30:00.000Z"
```

## Status Fields (Text + CHECK, Not ENUM)

```sql
-- CORRECT: text with CHECK constraint
status text NOT NULL DEFAULT 'draft'
  CHECK (status IN ('draft', 'pending', 'paid', 'overdue', 'cancelled'))

-- WRONG: Postgres ENUM type
CREATE TYPE invoice_status AS ENUM ('draft', 'pending', 'paid', 'overdue', 'cancelled');
-- Reason: Adding values to Postgres ENUM requires DDL, harder to migrate
```

Text + CHECK constraints can be updated with a simple migration:
```sql
-- Add a new status value:
ALTER TABLE invoices DROP CONSTRAINT invoices_status_check;
ALTER TABLE invoices ADD CONSTRAINT invoices_status_check
  CHECK (status IN ('draft', 'pending', 'paid', 'overdue', 'cancelled', 'refunded'));
```

## Foreign Key Indexes

Postgres does NOT automatically create indexes on foreign key columns. Always add them:

```sql
CREATE TABLE line_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  ...
);

-- REQUIRED — Postgres doesn't add this automatically:
CREATE INDEX line_items_invoice_id_idx ON line_items(invoice_id);
```

Without this index, `SELECT * FROM line_items WHERE invoice_id = $1` is a full table scan.

## Soft Deletes

Never physically delete records that might be referenced. Use `deleted_at`:

```sql
ALTER TABLE customers ADD COLUMN deleted_at timestamptz;

-- "Delete" a customer:
UPDATE customers SET deleted_at = now() WHERE id = $1;

-- Query non-deleted customers:
SELECT * FROM customers WHERE deleted_at IS NULL;

-- RLS policy to hide deleted:
CREATE POLICY "Hide deleted customers"
ON customers FOR SELECT
USING (deleted_at IS NULL);
```

The downside: queries must always include `WHERE deleted_at IS NULL`. Add this to all relevant RLS policies and query functions.

## Denormalization for Performance

Sometimes it's correct to store derived data to avoid expensive joins:

```sql
-- On invoices: store customer_name even though it's in customers table
-- Reason: invoice history should show the name at time of invoice, not current name
-- Also avoids join on every invoice list query

customer_name text NOT NULL  -- denormalized
```

When to denormalize:
- Data needs to reflect historical state (invoice at time of creation)
- The join is always needed and occurs on a hot path
- The source value rarely changes

When NOT to denormalize:
- The source value changes frequently (you'd need to update all copies)
- The query is not performance-critical
- It's simply to avoid typing a join

## Normalization Checklist

Before finalizing a schema:
- [ ] No money stored as floats
- [ ] All timestamps are `timestamptz` with UTC storage
- [ ] Status fields use `text` + CHECK, not ENUM
- [ ] Foreign keys have explicit indexes
- [ ] Soft delete column is `deleted_at timestamptz` (not a boolean `is_deleted`)
- [ ] UUID primary keys (not serial integers) for tables that might be referenced externally
- [ ] `updated_at` trigger for mutation tracking
