# Failure: Concurrent State Update Issues

## Problem: Lost Update Race Condition

**Symptom**: Two users update the same record simultaneously; one update is silently lost.

```
User A reads invoice (total: $100)
User B reads invoice (total: $100)
User A adds $50 line item → writes total: $150
User B adds $75 line item → writes total: $175  ← overwrites User A's change!
Final state: $175 (User A's $50 item is gone from total)
```

**Fix 1**: Optimistic locking with `updated_at` check:

```sql
-- Only update if the record hasn't changed since we read it
UPDATE invoices
SET total_cents = $1, updated_at = now()
WHERE id = $2
  AND updated_at = $3  -- the timestamp we read
RETURNING id;
-- If this returns 0 rows, someone else updated it — retry
```

```ts
const { data } = await supabaseAdmin
  .from('invoices')
  .update({ total_cents: newTotal, updated_at: new Date().toISOString() })
  .eq('id', invoiceId)
  .eq('updated_at', invoiceReadAt)  // concurrent update check
  .select()

if (!data || data.length === 0) {
  throw new Error('Invoice was modified by another user — please refresh and retry')
}
```

**Fix 2**: Row-level locking (for operations that need to read-then-write):

```sql
-- In a transaction, lock the row before reading
BEGIN;
SELECT * FROM invoices WHERE id = $1 FOR UPDATE;
-- Now no other transaction can modify this row until we commit
UPDATE invoices SET total_cents = total_cents + $2 WHERE id = $1;
COMMIT;
```

Use `FOR UPDATE` in Supabase via `supabaseAdmin.rpc('update_invoice_total', { invoice_id, amount })`.

## Problem: React State Update After Unmount

**Symptom**: Warning: "Can't perform a React state update on an unmounted component."

**Root cause**: An async operation (fetch, setTimeout) completes after the component unmounts. The callback tries to call `setState` on a component that no longer exists.

```ts
// BAD: fetch result may arrive after unmount
useEffect(() => {
  fetch('/api/data').then(r => r.json()).then(setData)  // leaks if unmounted
}, [])

// GOOD: use abort controller to cancel on cleanup
useEffect(() => {
  const controller = new AbortController()

  fetch('/api/data', { signal: controller.signal })
    .then(r => r.json())
    .then(setData)
    .catch(err => {
      if (err.name !== 'AbortError') throw err  // ignore expected abort
    })

  return () => controller.abort()
}, [])
```

TanStack Query handles this automatically — another reason to use it instead of raw fetch in components.

## Problem: Stale Closure in Event Handler

**Symptom**: Event handler uses a value from an old render; button click produces wrong result.

```tsx
// BAD: count is captured at render time, never updates
const [count, setCount] = useState(0)
useEffect(() => {
  const id = setInterval(() => {
    console.log(count)  // Always logs 0 — stale closure
  }, 1000)
  return () => clearInterval(id)
}, [])  // Missing dependency

// GOOD: use functional updater — no closure needed
useEffect(() => {
  const id = setInterval(() => {
    setCount(prev => prev + 1)  // Uses current value, not closure
  }, 1000)
  return () => clearInterval(id)
}, [])
```

For reading state in event handlers:
```tsx
// Use useRef to always have current value
const countRef = useRef(count)
useEffect(() => { countRef.current = count }, [count])
// In async callbacks: countRef.current instead of count
```

## Problem: Double Submission on Slow Networks

**Symptom**: User clicks "Save", waits, clicks again — creates two records.

```tsx
// BAD: no protection against double-click
async function handleSubmit() {
  await createInvoice(data)  // Called twice if user clicks twice
}

// GOOD: disable button while pending
const [pending, setPending] = useState(false)

async function handleSubmit() {
  if (pending) return  // Guard against double-call
  setPending(true)
  try {
    await createInvoice(data)
  } finally {
    setPending(false)
  }
}

<Button onClick={handleSubmit} disabled={pending}>
  {pending ? <Loader2 className="animate-spin" /> : 'Save'}
</Button>
```

For Server Actions, use `useFormStatus` from react-dom:
```tsx
const { pending } = useFormStatus()
<Button type="submit" disabled={pending}>Save</Button>
```

## Problem: Parallel Requests Creating Inconsistent State

**Symptom**: Multiple concurrent requests each partially succeed, leaving data in an inconsistent intermediate state.

**Fix**: Use database transactions for multi-table writes:

```ts
// BAD: separate operations — partial failure leaves inconsistent state
await supabaseAdmin.from('invoices').update({ status: 'paid' }).eq('id', invoiceId)
await supabaseAdmin.from('payments').insert({ invoice_id: invoiceId, amount: totalCents })
// If second insert fails, invoice shows "paid" with no payment record

// GOOD: wrap in a transaction via a DB function
await supabaseAdmin.rpc('record_payment', {
  p_invoice_id: invoiceId,
  p_amount_cents: totalCents,
})
```

```sql
CREATE OR REPLACE FUNCTION record_payment(p_invoice_id uuid, p_amount_cents integer)
RETURNS void AS $$
BEGIN
  UPDATE invoices SET status = 'paid' WHERE id = p_invoice_id;
  INSERT INTO payments (invoice_id, amount_cents) VALUES (p_invoice_id, p_amount_cents);
  -- If either fails, both roll back automatically
END;
$$ LANGUAGE plpgsql;
```
