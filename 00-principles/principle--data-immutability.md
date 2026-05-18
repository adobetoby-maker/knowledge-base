# Principle: Treat Data as Immutable

## The Problem

Mutating data in place — updating state directly, modifying objects passed as arguments, overwriting records without history — creates bugs that are hard to trace, loses the ability to undo, and makes concurrent operations unsafe.

## In React State

```tsx
// BAD: mutating state directly
const [items, setItems] = useState([])
items.push(newItem)     // This won't trigger re-render
items[0].name = 'new'  // This is invisible to React

// GOOD: always create a new reference
setItems([...items, newItem])
setItems(prev => prev.map(item =>
  item.id === targetId ? { ...item, name: 'new' } : item
))
setItems(prev => prev.filter(item => item.id !== deletedId))
```

When state is an object:
```tsx
// BAD: direct mutation
state.user.name = 'new name'  // React doesn't see this

// GOOD: new object reference
setState(prev => ({ ...prev, user: { ...prev.user, name: 'new name' } }))
// Or with Immer for deeply nested state:
setState(produce(prev => { prev.user.name = 'new name' }))
```

## In Functions — No Side Effects on Parameters

```ts
// BAD: modifying the input argument
function addTax(invoice: Invoice): Invoice {
  invoice.total_cents = invoice.total_cents * 1.08  // Mutates the caller's object!
  return invoice
}

// GOOD: return a new object
function addTax(invoice: Invoice): Invoice {
  return { ...invoice, total_cents: Math.round(invoice.total_cents * 1.08) }
}
```

Pure functions are safer to test, easier to reason about, and can be called multiple times without side effects.

## In Database Design — Prefer Append-Only

```sql
-- BAD: overwrite invoice status, lose history
UPDATE invoices SET status = 'paid' WHERE id = $1;
-- → What was the previous status? When did it change? Who changed it?

-- BETTER: event log captures all state transitions
CREATE TABLE invoice_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES invoices(id),
  event_type text NOT NULL,   -- 'status_changed', 'payment_received', 'emailed'
  from_state jsonb,
  to_state jsonb,
  actor_id uuid,
  created_at timestamptz DEFAULT now()
);

-- The current state is derived from the event log, or cached in the invoices table
-- for query performance
```

For most business apps, a hybrid: mutable `status` column for current state + immutable event log for history.

## Soft Delete vs Hard Delete

Deleting records permanently is a form of mutation with no undo. Soft delete preserves the data:

```sql
-- Add to any table where accidental deletion would be a problem
ALTER TABLE clients ADD COLUMN deleted_at timestamptz;
ALTER TABLE clients ADD COLUMN deleted_by uuid REFERENCES auth.users;

-- "Delete" sets the timestamp instead of removing the row
UPDATE clients SET deleted_at = now(), deleted_by = $1 WHERE id = $2;

-- Queries exclude soft-deleted records
SELECT * FROM clients WHERE deleted_at IS NULL;
```

Hard delete only for: test data, GDPR erasure requests, temporary records that genuinely have no value after deletion.

## Immutable Config and Constants

```ts
// BAD: mutable object — can be accidentally modified
const STATUS_LABELS = {
  draft: 'Draft',
  sent: 'Sent',
  paid: 'Paid',
}
STATUS_LABELS.draft = 'Modified'  // Silently allowed

// GOOD: Object.freeze prevents mutation (throws in strict mode)
const STATUS_LABELS = Object.freeze({
  draft: 'Draft',
  sent: 'Sent',
  paid: 'Paid',
} as const)

// BEST: TypeScript const assertion + freeze
const STATUS_LABELS = {
  draft: 'Draft',
  sent: 'Sent',
  paid: 'Paid',
} as const satisfies Record<InvoiceStatus, string>
```

## Financial Audit Trail

Financial records must be immutable:
- Never update the `total_cents` of a posted invoice — create a credit note instead
- Never delete a payment record — void it with a compensating entry
- Never overwrite line items — version them or append new ones

This is both good architecture and a compliance requirement in many jurisdictions.

## When Mutation is Appropriate

Immutability has costs (new objects, GC pressure). Mutate when:
- Performance-critical inner loops where allocation cost matters
- Local variables that don't leave the function scope
- Accumulators in reduce operations before the result is returned

The rule is: never mutate data that other code holds a reference to.
