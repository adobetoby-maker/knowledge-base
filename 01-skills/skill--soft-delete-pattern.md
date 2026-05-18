# Soft Delete Pattern

## What It Is

Soft delete marks records as deleted without removing them from the database. A `deleted_at` timestamp column signals deletion; NULL means active.

Use soft deletes for:
- Data that might need restoration (customer accidentally deleted)
- Audit trail requirements (when was this deleted, by whom?)
- Data that other records reference (deleting a customer would orphan invoices)

Use hard deletes for:
- User-requested data deletion (GDPR compliance — must be hard delete)
- Temp/draft records with no audit value
- High-volume tables where soft-deleted rows accumulate (performance cost)

## Database Setup

```sql
-- Add deleted_at to existing table:
ALTER TABLE customers ADD COLUMN deleted_at timestamptz;

CREATE INDEX customers_deleted_at_idx ON customers (deleted_at)
WHERE deleted_at IS NULL;  -- partial index covers only active records
```

## RLS Policy — Must Exclude Soft-Deleted

```sql
-- SELECT policy MUST filter out soft-deleted rows:
CREATE POLICY "Users can view active customers"
ON customers FOR SELECT
USING (
  auth.uid() = user_id
  AND deleted_at IS NULL  -- excludes soft-deleted
);

-- UPDATE policy allows updating non-deleted rows:
CREATE POLICY "Users can update own active customers"
ON customers FOR UPDATE
USING (auth.uid() = user_id AND deleted_at IS NULL)
WITH CHECK (auth.uid() = user_id);
```

Forgetting `AND deleted_at IS NULL` in the SELECT policy means soft-deleted records remain visible. This is the #1 mistake.

## Soft Delete Server Action

```typescript
// lib/actions/customers.ts
'use server'

export async function deleteCustomer(customerId: string): Promise<ActionResult> {
  const admin = await validateAdminSession()
  
  // Check if customer has active invoices before deleting:
  const { count } = await supabase
    .from('invoices')
    .select('*', { count: 'exact' })
    .eq('customer_id', customerId)
    .in('status', ['sent', 'pending'])  // active invoices
  
  if (count && count > 0) {
    return { success: false, error: 'Cannot delete customer with active invoices' }
  }
  
  // Soft delete:
  const { error } = await supabase
    .from('customers')
    .update({ deleted_at: new Date().toISOString() })
    .eq('id', customerId)
    .is('deleted_at', null)  // only delete if not already deleted
  
  if (error) return { success: false, error: 'Delete failed' }
  
  await logAudit({
    action: 'delete',
    resourceType: 'customer',
    resourceId: customerId,
    userId: admin.id,
  })
  
  revalidatePath('/admin/customers')
  return { success: true }
}
```

## Restore (Undo Delete)

```typescript
export async function restoreCustomer(customerId: string): Promise<ActionResult> {
  await validateAdminSession()
  
  const { error } = await supabase
    .from('customers')
    .update({ deleted_at: null })
    .eq('id', customerId)
    .not('deleted_at', 'is', null)  // only restore if actually deleted
  
  if (error) return { success: false, error: 'Restore failed' }
  
  revalidatePath('/admin/customers')
  return { success: true }
}
```

## Querying

```typescript
// Active records only (default — uses RLS):
const { data: customers } = await supabase.from('customers').select('*')

// Include deleted (admin only — service role bypasses RLS):
const { data: allCustomers } = await supabaseAdmin()
  .from('customers')
  .select('*')
  .order('deleted_at', { ascending: true, nullsFirst: false })  // deleted last

// Only deleted (recycle bin view):
const { data: deletedCustomers } = await supabaseAdmin()
  .from('customers')
  .select('*')
  .not('deleted_at', 'is', null)
  .order('deleted_at', { ascending: false })
```

## Cleanup Job

Permanently delete records soft-deleted more than 30 days ago:

```typescript
// In a weekly cron:
async function hardDeleteOldSoftDeletes() {
  const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
  
  const { error } = await supabaseAdmin()
    .from('customers')
    .delete()
    .lt('deleted_at', cutoff)
    .not('deleted_at', 'is', null)
  
  console.log('Cleaned up soft-deleted customers older than 30 days')
}
```
