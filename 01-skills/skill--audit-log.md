# Audit Logging

## What Audit Logs Track

An audit log records who did what, when, and to what. Required for:
- Financial systems (who created/modified/deleted invoices)
- Admin actions (who changed a customer's status)
- Compliance requirements
- Debugging ("why did this record change?")

## Database Schema

```sql
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Who:
  user_id uuid REFERENCES auth.users(id),
  user_email text,          -- denormalized — in case user is deleted
  
  -- What:
  action text NOT NULL,     -- 'create' | 'update' | 'delete' | 'view'
  resource_type text NOT NULL,  -- 'invoice' | 'customer' | 'payment'
  resource_id text NOT NULL,    -- UUID of the affected record
  
  -- Details:
  old_values jsonb,         -- previous state (for updates/deletes)
  new_values jsonb,         -- new state (for creates/updates)
  metadata jsonb,           -- extra context: IP address, user agent
  
  -- When:
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Append-only: no updates, no deletes
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can read audit logs:
CREATE POLICY "Admins can read audit logs"
ON audit_logs FOR SELECT
USING (false);  -- blocked for all — admin client bypasses RLS
-- Queries use service role client
```

## Logging Function

```typescript
// lib/audit.ts
import { createAdminClient } from './supabase/admin'

interface AuditEntry {
  action: 'create' | 'update' | 'delete' | 'view'
  resourceType: string
  resourceId: string
  userId?: string
  userEmail?: string
  oldValues?: Record<string, unknown>
  newValues?: Record<string, unknown>
  metadata?: Record<string, unknown>
}

export async function logAudit(entry: AuditEntry): Promise<void> {
  const supabase = createAdminClient()
  
  try {
    await supabase.from('audit_logs').insert({
      user_id: entry.userId,
      user_email: entry.userEmail,
      action: entry.action,
      resource_type: entry.resourceType,
      resource_id: entry.resourceId,
      old_values: entry.oldValues,
      new_values: entry.newValues,
      metadata: entry.metadata,
    })
  } catch (error) {
    // Audit log failure is non-critical — log but don't fail the main operation:
    console.error('Audit log failed:', error)
  }
}
```

Never throw from audit logging — a failed audit write should not prevent the actual operation from succeeding.

## Usage in Server Actions

```typescript
// lib/actions/invoices.ts
'use server'
export async function deleteInvoice(invoiceId: string) {
  const admin = await validateAdminSession()
  
  // Fetch before delete (to capture old values):
  const { data: invoice } = await supabase.from('invoices').select('*').eq('id', invoiceId).single()
  
  const { error } = await supabase.from('invoices').delete().eq('id', invoiceId)
  if (error) return { success: false, error: 'Delete failed' }
  
  // Log after successful operation:
  await logAudit({
    action: 'delete',
    resourceType: 'invoice',
    resourceId: invoiceId,
    userId: admin.id,
    userEmail: admin.email,
    oldValues: invoice ?? undefined,  // what was deleted
  })
  
  revalidatePath('/admin/invoices')
  return { success: true }
}
```

## Postgres Trigger Approach (Alternative)

For automatic logging without application code:

```sql
-- Trigger function:
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs (action, resource_type, resource_id, old_values, new_values)
  VALUES (
    LOWER(TG_OP),
    TG_TABLE_NAME,
    COALESCE(NEW.id::text, OLD.id::text),
    CASE WHEN TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN row_to_json(OLD) ELSE NULL END,
    CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN row_to_json(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Attach to invoices table:
CREATE TRIGGER audit_invoices
AFTER INSERT OR UPDATE OR DELETE ON invoices
FOR EACH ROW EXECUTE FUNCTION log_changes();
```

Downsides: no user context (who did it), no metadata. App-level logging is more informative.

## Querying the Audit Log

```typescript
// Admin route to view audit history for a record:
async function getAuditHistory(resourceType: string, resourceId: string) {
  const { data } = await supabaseAdmin
    .from('audit_logs')
    .select('*')
    .eq('resource_type', resourceType)
    .eq('resource_id', resourceId)
    .order('created_at', { ascending: false })
    .limit(50)
  
  return data
}
```
