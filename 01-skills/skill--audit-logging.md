# Audit Logging

## Why Audit Logs Are Different From Application Logs

Application logs (stdout, error trackers) are operational — they help debug what went wrong. Audit logs are accountability records — they answer "who changed what, when, and what was the value before and after." They serve legal, compliance, and support functions. The requirements are different: audit logs must be append-only, queryable by entity/actor/time, and retained for months or years.

Never conflate the two. Writing audit events to stdout loses the before/after values, is not queryable, and rotates away.

## What to Log

Every audit event captures six dimensions:

```ts
interface AuditEvent {
  id:          string;       // uuid
  tenant_id:   string;       // for multi-tenant systems
  actor_id:    string | null; // user who made the change (null = system/cron)
  actor_ip:    string | null; // client IP at time of action
  actor_email: string | null; // denormalized — actor may be deleted later
  entity_type: string;       // 'invoice' | 'user' | 'plan'
  entity_id:   string;       // the record's PK
  action:      string;       // 'create' | 'update' | 'delete' | 'export'
  old_value:   jsonb | null; // full record before change (null for creates)
  new_value:   jsonb | null; // full record after change (null for deletes)
  metadata:    jsonb | null; // extra context: { reason, ip_country, user_agent }
  created_at:  timestamptz;  // server time, never client time
}
```

Denormalize `actor_email` — if the user is later deleted, the audit log must still be readable. Don't rely on joins to reconstruct actor identity.

## Append-Only Table

Audit logs must never be mutated or deleted during normal operation. Enforce this at the database level:

```sql
create table audit_log (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  actor_id    uuid,
  actor_ip    inet,
  actor_email text,
  entity_type text not null,
  entity_id   text not null,
  action      text not null,
  old_value   jsonb,
  new_value   jsonb,
  metadata    jsonb,
  created_at  timestamptz not null default now()
);

-- Revoke UPDATE and DELETE from the application role
revoke update, delete on audit_log from app_role;
```

Only a dedicated admin role (used only for legal/compliance exports) can delete records, and only under explicit authorization.

## Actor Context via AsyncLocalStorage

The challenge: deeply nested service functions that write to the DB don't know who the actor is. Passing `actorId` through every function call is error-prone and pollutes signatures.

Solution: store actor context in Node's `AsyncLocalStorage` at the request boundary, and read it in the audit-logging utility:

```ts
import { AsyncLocalStorage } from 'async_hooks';

interface ActorContext {
  userId: string;
  email: string;
  ip: string;
  tenantId: string;
}

export const actorStore = new AsyncLocalStorage<ActorContext>();

// In middleware (Express / Next.js route handler):
export function withActorContext(actor: ActorContext, fn: () => Promise<void>) {
  return actorStore.run(actor, fn);
}

// In audit utility:
export async function logAudit(event: Omit<AuditEvent, 'actor_id' | 'actor_email' | 'created_at'>) {
  const actor = actorStore.getStore();
  await db.insert(auditLog).values({
    ...event,
    actor_id:    actor?.userId ?? null,
    actor_email: actor?.email  ?? null,
    actor_ip:    actor?.ip     ?? null,
    created_at:  new Date(),
  });
}
```

This makes audit calls at any depth automatic — no threading of context through parameters.

## Structured Log Format

Capture `old_value` and `new_value` as complete record snapshots, not diffs. Diffs require reconstruction; snapshots are immediately readable. For large records, consider storing only the changed fields plus a pointer to the full record.

```ts
// On update:
const before = await db.select().from(invoices).where(eq(invoices.id, id));
await db.update(invoices).set(data).where(eq(invoices.id, id));
const after = await db.select().from(invoices).where(eq(invoices.id, id));

await logAudit({
  entity_type: 'invoice',
  entity_id: id,
  action: 'update',
  old_value: before[0],
  new_value: after[0],
});
```

## GDPR Data Redaction

Audit logs contain personal data. GDPR Article 17 (right to erasure) applies. When a user requests deletion:

1. **Do not delete audit log rows** — they are legal records of business transactions.
2. Instead, **redact PII fields** in-place:

```ts
await db.update(auditLog)
  .set({
    actor_email: '[redacted]',
    old_value: db.sql`jsonb_set(old_value, '{email}', '"[redacted]"')`,
    new_value: db.sql`jsonb_set(new_value, '{email}', '"[redacted]"')`,
    metadata: db.sql`metadata - 'user_agent'`,  // strip device fingerprint
  })
  .where(eq(auditLog.actor_id, userId));
```

Keep `actor_id` (a non-PII UUID) to maintain the structural integrity of the audit trail. The "who" becomes anonymous; the "what and when" is preserved.

## Indexing for Query Performance

```sql
create index on audit_log (entity_type, entity_id, created_at desc);
create index on audit_log (actor_id, created_at desc);
create index on audit_log (tenant_id, created_at desc);
```

Queries are almost always "show me the history of entity X" or "show me everything actor Y did" — these indexes cover both.

## Key Rules

- **Append-only** — revoke `UPDATE` and `DELETE` from the application DB role.
- Log **six dimensions**: who, what entity, what action, old value, new value, when.
- **Denormalize actor email** — don't rely on a join to a user who may be deleted.
- Use **AsyncLocalStorage** to inject actor context — don't thread it through function parameters.
- Store **full record snapshots**, not diffs — snapshots are self-contained and immediately readable.
- For GDPR erasure: **redact PII fields in-place**, do not delete rows.
- Index on `(entity_type, entity_id, created_at)` and `(actor_id, created_at)` for fast history queries.
