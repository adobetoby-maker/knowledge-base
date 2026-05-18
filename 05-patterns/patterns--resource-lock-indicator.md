# Pattern: Resource Lock Indicator

## Overview
When two users edit the same record simultaneously, the last save wins and the other person's changes are silently lost. A lock indicator prevents this either by blocking the second editor (pessimistic) or by warning and detecting conflicts on save (optimistic). The lock must auto-expire so a crashed browser doesn't permanently block editing.

## Implementation

### Data Model
```sql
CREATE TABLE resource_locks (
  resource_type TEXT NOT NULL,
  resource_id   TEXT NOT NULL,
  locked_by     UUID NOT NULL REFERENCES users(id),
  locked_by_name TEXT NOT NULL,  -- denormalized for display
  locked_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL,  -- 30 min from now, refreshed while editing
  PRIMARY KEY (resource_type, resource_id)
);
```

### Acquiring a Lock
```typescript
async function acquireLock(
  resourceType: string,
  resourceId: string,
  userId: string,
  userName: string
): Promise<{ acquired: boolean; lockedBy?: string }> {
  const expiresAt = new Date(Date.now() + 30 * 60 * 1000); // 30 minutes

  // Upsert: take lock if free or expired, or if same user re-acquiring
  const result = await db.$executeRaw`
    INSERT INTO resource_locks (resource_type, resource_id, locked_by, locked_by_name, expires_at)
    VALUES (${resourceType}, ${resourceId}, ${userId}, ${userName}, ${expiresAt})
    ON CONFLICT (resource_type, resource_id) DO UPDATE
      SET locked_by = ${userId},
          locked_by_name = ${userName},
          locked_at = now(),
          expires_at = ${expiresAt}
      WHERE resource_locks.expires_at < now()   -- only replace if expired
         OR resource_locks.locked_by = ${userId}  -- or same user
    RETURNING locked_by
  `;

  const lock = await db.resourceLocks.findUnique({ where: { resourceType_resourceId: { resourceType, resourceId } } });
  return {
    acquired: lock?.lockedBy === userId,
    lockedBy: lock?.lockedBy !== userId ? lock?.lockedByName : undefined,
  };
}
```

### Heartbeat (keep lock alive while editing)
```typescript
function useLockHeartbeat(resourceType: string, resourceId: string, acquired: boolean) {
  useEffect(() => {
    if (!acquired) return;

    // Refresh lock every 5 minutes
    const interval = setInterval(async () => {
      await fetch(`/api/locks/refresh`, {
        method: 'POST',
        body: JSON.stringify({ resourceType, resourceId }),
      });
    }, 5 * 60 * 1000);

    // Release lock when component unmounts (user navigates away)
    return () => {
      clearInterval(interval);
      navigator.sendBeacon('/api/locks/release', JSON.stringify({ resourceType, resourceId }));
    };
  }, [resourceType, resourceId, acquired]);
}
```

### Editor UI
```tsx
function InvoiceEditor({ invoiceId, currentUserId, currentUserName }) {
  const [lockState, setLockState] = useState<'checking' | 'acquired' | 'locked-by-other'>('checking');
  const [lockedBy, setLockedBy] = useState<string>('');

  useEffect(() => {
    acquireLock('invoice', invoiceId, currentUserId, currentUserName).then(result => {
      if (result.acquired) {
        setLockState('acquired');
      } else {
        setLockState('locked-by-other');
        setLockedBy(result.lockedBy!);
      }
    });
  }, [invoiceId]);

  useLockHeartbeat('invoice', invoiceId, lockState === 'acquired');

  if (lockState === 'locked-by-other') {
    return (
      <div>
        <LockBanner>
          <LockIcon />
          <span><strong>{lockedBy}</strong> is currently editing this invoice.</span>
          <RequestLockButton resourceType="invoice" resourceId={invoiceId} />
        </LockBanner>
        <InvoiceForm readonly />
      </div>
    );
  }

  return <InvoiceForm editable />;
}
```

### Admin Force-Unlock
```typescript
async function forceUnlock(resourceType: string, resourceId: string, adminUserId: string) {
  await auditLog({ event: 'lock.force_released', actorId: adminUserId, resourceType, resourceId });
  await db.resourceLocks.deleteMany({ where: { resourceType, resourceId } });
}
```

## Key Rules
- Locks auto-expire after 30 minutes — a crashed browser must not permanently block editing
- Refresh the lock on a heartbeat (every 5 min) while the editor is open
- Release the lock on unmount using `navigator.sendBeacon` — fires even during page close
- Show a clear, named banner: "Alice is editing this" — not a generic "read-only" message
- Read-only view is still shown when locked — users can see the current state, just not edit
- Force-unlock is admin-only and logged to audit log — with great power comes great auditability
- Lock acquisition uses a DB upsert with expiry check — prevents race conditions
- Request-lock button sends a notification to the current editor, not just silently waits
- Refresh expiry from the last activity time, not from a fixed time — idle editors shouldn't hold locks
- Use `navigator.sendBeacon` for release, not `fetch` — `fetch` can be cancelled during unload
